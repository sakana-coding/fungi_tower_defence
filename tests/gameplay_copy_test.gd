extends SceneTree
## 在三关实际显示入口检查章节文案，并验证断路事件仍保留原有内部类型。

const LEVELS: Array[String] = [
	"res://scenes/levels/first_level.tscn",
	"res://scenes/levels/second_level.tscn",
	"res://scenes/levels/third_level.tscn",
]
const OLD_WORDS: PackedStringArray = [
	"母核", "菌落", "群落", "菌结", "菌丝", "菌域", "菌脉", "菌路", "菌网",
	"胃囊", "胃室", "器官", "营养", "养分", "尸体", "尸骸", "孢子", "啃食者",
	"培育", "分化", "移植", "供养", "单腔", "二腔",
]
var checks: int = 0
var failures: Array[String] = []
var capture_directory: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	for index: int in LEVELS.size():
		await _check_chapter(index)
	print("GAMEPLAY_COPY_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check_chapter(index: int) -> void:
	var level = load(LEVELS[index]).instantiate()
	root.add_child(level)
	current_scene = level
	await _frames(4)
	level.pause_controller.set_paused(true)
	var ui: CompactColonyHUD = level.compact_hud
	var initial_nutrition: int = level.mother_core.nutrition
	var initial_health: float = level.mother_core.health
	_check(initial_nutrition == [72, 90, 100][index] and initial_health == 240,
		"chapter %d preserves starting resources and health" % (index + 1))
	_check(ui.nutrition_button.text.begins_with("创作能量 "), "resource header names the real shared currency")
	_check(ui.goal_label.text.contains("小画家"), "objective names the visible protagonist")
	_check(level.colony_progress.get_stage_name() == "起笔", "initial stage uses the approved display name")
	for resource: Node in level.get_node("World/Remains").get_children():
		if resource is LargeCarcass:
			_check(resource.get_node("TitleLabel").text == ["破旧画架", "破损数位板", "公文包"][index],
				"chapter %d resource label matches its actual art" % (index + 1))
	await _capture("chapter_%d_overview" % (index + 1))
	for page: StringName in ui.pages:
		ui.open_page(page)
		await _frames(2)
		_scan_text(ui.pages[page])
	_check(ui.top_left.get_global_rect().end.x + 12 <= ui.top_right.get_global_rect().position.x,
		"chapter %d resource and wave panels do not overlap" % (index + 1))
	ui.open_page(&"help")
	_open_disclosures(ui.pages[&"help"])
	await _frames(3)
	await _capture("chapter_%d_help" % (index + 1))
	ui.open_page(&"build")
	_open_disclosures(ui.pages[&"build"])
	await _frames(3)
	await _capture("chapter_%d_build" % (index + 1))
	ui.close_drawer()
	_check(level.mother_core.nutrition == initial_nutrition and level.mother_core.health == initial_health,
		"reading the new descriptions does not spend resources or change health")
	for event: StringName in [&"target_placed", &"remains_returned", &"nutrition_returned", &"stage_unlocked",
			&"differentiated", &"network_broken", &"facility_destroyed", &"silk_gnawer", &"junction_gnawer", &"swarm", &"armored"]:
		level.first_guide.record_event(event, {"stage_name": "成形"})
		for _pending: int in range(16):
			var guide: Dictionary = level.first_guide.get_snapshot()
			if not bool(guide.get("visible", false)):
				break
			_check_text(String(guide.get("text", "")), "chapter guide")
			level.first_guide.dismiss_current()
	var edge: HyphaEdge = level.get_node("World/Colony/Connections").get_child(0) as HyphaEdge
	var original_kind: Array[StringName] = []
	level.tissue_lifecycle.tissue_lost.connect(func(_id: int, kind: StringName, _point: Vector2) -> void:
		original_kind.append(kind))
	edge.take_damage(edge.max_health)
	_check(original_kind.has(&"菌丝"), "display renaming preserves the original broken-edge event tag")
	_check(level.network_break_count > 0, "the original network-loss handler still observes the broken edge")
	ui.refresh()
	_scan_text(level)
	for victory: bool in [true, false]:
		level.flow_hud.show_result({"victory": victory, "reached_wave": 6, "completed_waves": 6,
			"total_recovered": 173, "stage_name": "成形", "mature_organs": 5,
			"core_health": 63.5 if victory else 0.0, "elapsed_seconds": 245.0, "objective": {"completed": 3}})
		_scan_text(level.flow_hud)
		_check(level.flow_hud.result_left_label.text.contains("173 创作能量"), "settlement retains actual recovered amount")
		_check(level.flow_hud.result_right_label.text.contains("小画家生命"), "settlement uses protagonist label")
		ui.hide()
		await _capture("chapter_%d_%s" % [index + 1, "victory" if victory else "defeat"])
	level.queue_free()
	await _frames(4)
	_check(not paused, "chapter disposal clears pause")


func _open_disclosures(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button and child.toggle_mode and child.text.ends_with("▸"):
			child.set_pressed(true)
		_open_disclosures(child)


func _scan_text(node: Node) -> void:
	if node is Label or node is Button:
		_check_text(node.text, str(node.get_path()))
	if node is Control:
		_check_text(node.tooltip_text, str(node.get_path()) + " tooltip")
	if node is OptionButton:
		for index: int in node.item_count:
			_check_text(node.get_item_text(index), str(node.get_path()) + " item")
	for child: Node in node.get_children():
		_scan_text(child)


func _check_text(value: String, source: String) -> void:
	if value.is_empty():
		return
	for word: String in OLD_WORDS:
		_check(not value.contains(word), "%s still displays %s: %s" % [source, word, value])


func _capture(filename: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(capture_directory.path_join(filename + ".png"))
	_check(result == OK, "saved review image " + filename)


func _frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
