class_name ColonyOperationsDemo
extends "res://scripts/terrain_threat_demo.gd"
## 第十阶段兼容入口；共用运营操作由 gameplay 层实现。

func _ready() -> void:
	growth_planner = growth_planner.duplicate(true) as GrowthPlanner
	growth_planner.bounded_branches_enabled = true
	growth_planner.auto_join_enabled = true
	GameDisplayManager.ensure(get_tree()).configure_canvas()
	_prepare_colony_operations()
	super._ready()
	_connect_colony_operations()
	(hud.get_node("HelpLabel") as Label).text = "G 延伸 · B 远处建造 · C 原位建造 · O 切换设施 · T 改向 · M 搬迁 · L 接合 · P 暂停 · X 取消 · R 重开 · F5–F10 各阶段"
	(hud.get_node("HelpLabel") as Label).add_theme_font_size_override("font_size", 14)
	hud.show_notice("第十阶段：G延伸→T改向；下方选回收碎纸机后C/B建造；选已建成的文具炮台M搬迁，真实付款6。")
	_refresh_operations_status()

func _exit_tree() -> void:
	_close_operations(&"scene_exit")
	super._exit_tree()

func _process(delta: float) -> void:
	super._process(delta)
	_process_colony_operations()

func _add_operations_extras() -> void:
	_operation_button("F10 第十阶段", 820, _reload_operations)

func _reload_operations() -> void:
	_announce_level_stopping(&"restart")
	get_tree().reload_current_scene()
