extends SceneTree
## 正常费用的首关防守路线：扩张、原位培育、破甲/散射分工及修复，不注入伤害或资源。
## 自动操作用于核对路线可行性，不能代替人工难度体验。

const LEVEL: PackedScene = preload("res://scenes/levels/first_level.tscn")

class QuietFirstLevel:
	extends FirstLevel
	func _refresh_formal_hud() -> void:
		pass

var level: FirstLevel
var next_maintenance: float = 0.0
var events: Array[Dictionary] = []
var failures: Array[String] = []
var tissue_hits: int = 0
var lost_tissues: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	level = LEVEL.instantiate() as FirstLevel
	# 仅省略显示刷新；保留场景中配置的全部脚本导出参数。
	var exported: Dictionary = {}
	for property: Dictionary in level.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_STORAGE:
			exported[property.name] = level.get(property.name)
	level.set_script(QuietFirstLevel)
	for property_name: String in exported:
		level.set(property_name, exported[property_name])
	root.add_child(level)
	current_scene = level
	await _frames(3)
	level.enemy_spawner.enemy_spawned.connect(func(enemy: BasicEnemy, _spawn_id: String, _batch_id: String) -> void:
		enemy.attacked_tissue.connect(func(_target: Node2D, _amount: float) -> void: tissue_hits += 1))
	level.tissue_lifecycle.tissue_lost.connect(func(_id: int, _kind: StringName, _point: Vector2) -> void: lost_tissues += 1)
	level.choose_organ(&"attack")
	level.cultivation_input_controller.enter_remote_placement_mode()
	_record_build("left_build", Vector2(330, 395),
		level.cultivation_input_controller.place_remote_target(Vector2(330, 395)))
	while level.elapsed_seconds < 30.0 and level.get_result_snapshot().is_empty():
		await _frames(1)
	if not level.start_next_wave():
		failures.append("first wave could not start")
	level.cultivation_input_controller.enter_remote_placement_mode()
	_record_build("right_build", Vector2(925, 390),
		level.cultivation_input_controller.place_remote_target(Vector2(925, 390)))
	var last_wave: int = 0
	for _frame: int in range(54000):
		await _frames(1)
		var flow: Dictionary = level.wave_flow.get_snapshot()
		if flow.wave_index != last_wave:
			last_wave = flow.wave_index
			_record("wave", {"wave": last_wave, "nutrition": level.mother_core.nutrition,
				"recovered": level.colony_progress.get_total_recovered(), "core": level.mother_core.health,
				"weapons": level.get_weapons().size()})
			if last_wave in [2, 3]:
				var point: Vector2 = Vector2(800, 390) if last_wave == 2 else Vector2(420, 360)
				level.choose_organ(&"attack")
				_record_build("reinforce", point, _build_at(point))
		if not level.get_result_snapshot().is_empty() or level.elapsed_seconds >= 900.0:
			break
	var result: Dictionary = level.get_result_snapshot()
	var balanced: bool = level.get_combat_resource_snapshot().balanced
	if not bool(result.get("victory", false)):
		failures.append("paid defense route did not win within 900 seconds")
	if not balanced:
		failures.append("resource ledger diverged")
	print("FIRST_LEVEL_PLAYTHROUGH_RESULT ", JSON.stringify({"failures": failures, "result": result,
		"time": level.elapsed_seconds, "flow": level.wave_flow.get_snapshot(), "core": level.mother_core.health,
		"hits": tissue_hits, "lost_tissues": lost_tissues, "events": events, "balanced": balanced}))
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame
		await process_frame
		if is_instance_valid(level) and level.elapsed_seconds >= next_maintenance \
				and level.get_result_snapshot().is_empty():
			next_maintenance = level.elapsed_seconds + 1.0
			_maintain()


func _maintain() -> void:
	if not level.differentiation_system.has_active_task() \
			and level.colony_capabilities.can_differentiate_attack_organs():
		for weapon: SporeWeapon in level.get_weapons():
			if weapon.get_weapon_profile().damage_type != WeaponProfile.DamageType.NORMAL:
				continue
			var point: Vector2 = weapon.get_parent().global_position
			var direction: int = -1
			if point.distance_to(Vector2(730, 480)) < 2.0:
				direction = WeaponProfile.DamageType.SCATTER
			elif point.distance_to(Vector2(470, 480)) < 2.0 or point.distance_to(Vector2(800, 390)) < 30.0 \
					or point.distance_to(Vector2(925, 390)) < 2.0:
				direction = WeaponProfile.DamageType.ARMOR_PIERCING
			if direction >= 0:
				level.differentiation_input_controller.select_node(weapon.get_parent() as HyphaNode)
				if level.differentiation_input_controller.request_start(direction):
					_record("specialize", {"point": str(point), "direction": direction})
				break
	if level.repair_system.has_active_task():
		if level.repair_system.get_task_snapshot().get("wait_reason") == &"disconnected":
			level.repair_system.cancel_task()
		else:
			return
	var selected: Node2D
	var lowest: float = 0.85
	for tissue: Node in get_nodes_in_group("colony_tissues"):
		if not level.is_ancestor_of(tissue) or tissue is MotherCore or tissue.is_queued_for_deletion():
			continue
		var preview: Dictionary = level.repair_system.preview_repair(tissue as Node2D)
		if not preview.get("valid", false) or not preview.get("supply_reachable", false):
			continue
		var ratio: float = float(preview.health) / maxf(1.0, float(preview.max_health))
		if ratio < lowest:
			lowest = ratio
			selected = tissue as Node2D
	if selected != null:
		level.repair_system.request_repair(selected)


func _build_at(point: Vector2) -> bool:
	for node: Node2D in level.network_system.get_registered_nodes():
		if node is HyphaNode and node.global_position.distance_to(point) < 24.0:
			level._select_node(node)
			return level.cultivation_input_controller.request_cultivation()
	level.cultivation_input_controller.enter_remote_placement_mode()
	return level.cultivation_input_controller.place_remote_target(point)


func _record_build(kind: String, point: Vector2, accepted: bool) -> void:
	_record(kind, {"point": str(point), "accepted": accepted})
	if not accepted:
		failures.append("%s at %s was rejected" % [kind, point])


func _record(kind: String, details: Dictionary) -> void:
	details["kind"] = kind
	details["time"] = level.elapsed_seconds
	events.append(details)
	print("FIRST_LEVEL_PLAYTHROUGH_EVENT ", JSON.stringify(details))
