class_name LevelMenuLayer
extends CanvasLayer
## 独立的暂停菜单；Space规划暂停仍由原控制器处理，打开菜单不提交任何建设指令。

@onready var overlay: Control = $Overlay
@onready var resume_button: Button = $Overlay/Center/Panel/Scroll/Buttons/ResumeButton
@onready var restart_button: Button = $Overlay/Center/Panel/Scroll/Buttons/RestartButton
@onready var title_button: Button = $Overlay/Center/Panel/Scroll/Buttons/TitleButton
@onready var quit_button: Button = $Overlay/Center/Panel/Scroll/Buttons/QuitButton
@onready var menu_panel: PanelContainer = $Overlay/Center/Panel
@onready var menu_scroll: ScrollContainer = $Overlay/Center/Panel/Scroll
@onready var menu_buttons: VBoxContainer = $Overlay/Center/Panel/Scroll/Buttons

var result_title_button: Button
var result_quit_button: Button
var _level: Node2D
var _navigator: CampaignNavigator
var _was_paused: bool = false
var _configured: bool = false


func configure(level: Node2D) -> void:
	if _configured:
		return
	_level = level
	ArtUI.skin_tree(overlay)
	ArtUI.menu_button(resume_button, "继续游戏", false, Vector2(270, 76))
	ArtUI.menu_button(restart_button, "重新开始", false, Vector2(270, 76))
	ArtUI.menu_button(title_button, "返回主菜单", false, Vector2(270, 76))
	ArtUI.menu_button(quit_button, "退出游戏", false, Vector2(270, 76))
	ArtUI.typography(menu_buttons.get_node("Title"), 38, true)
	var hint_label: Label = menu_buttons.get_node("Hint")
	ArtUI.typography(hint_label, 20)
	hint_label.text = "已解锁的关卡进度会保留。\n当前布局与战斗进度不会保留。"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ArtUI.typography(menu_buttons.get_node("KeyboardHint"), 20)
	_navigator = get_node_or_null("/root/CampaignFlow") as CampaignNavigator
	resume_button.pressed.connect(close_menu)
	restart_button.pressed.connect(_restart)
	title_button.pressed.connect(_return_to_title)
	quit_button.pressed.connect(_quit)
	_level.level_finished.connect(_on_level_finished)
	var row := HBoxContainer.new()
	row.name = "NavigationButtons"
	row.position = Vector2(56, 510)
	row.size = Vector2(600, 72)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.theme = preload("res://resources/ui/menu_theme.tres")
	_level.flow_hud.result_panel.size = Vector2(712, 680)
	get_viewport().size_changed.connect(_layout_result_panel)
	get_viewport().size_changed.connect(_layout_menu)
	menu_buttons.minimum_size_changed.connect(_layout_menu)
	_layout_menu.call_deferred()
	_layout_result_panel.call_deferred()
	for button: Button in [_level.flow_hud.result_restart_button, _level.flow_hud.result_continue_button]:
		button.theme = row.theme
		button.custom_minimum_size = Vector2(230, 72)
		button.size = Vector2(230, 72)
		button.position.y = 414
	_level.flow_hud.result_panel.add_child(row)
	result_title_button = _result_button(row, "返回主菜单", _return_to_title)
	result_quit_button = _result_button(row, "退出游戏", _quit)
	ArtUI.skin_tree(_level.flow_hud.result_panel)
	ArtUI.menu_button(result_title_button, "返回主菜单", false, Vector2(230, 72))
	ArtUI.menu_button(_level.flow_hud.result_continue_button, "进入下一关", false, Vector2(230, 72))
	var hud: FirstLevelHUD = _level.flow_hud
	ArtUI.typography(hud.result_title, 34, true)
	hud.result_title.position = Vector2(56, 80)
	hud.result_title.size = Vector2(600, 50)
	ArtUI.typography(hud.result_subtitle, 22)
	hud.result_subtitle.position = Vector2(56, 142)
	hud.result_subtitle.size = Vector2(600, 38)
	for index: int in range(2):
		var label: Label = hud.result_left_label if index == 0 else hud.result_right_label
		ArtUI.typography(label, 22)
		label.position = Vector2(56 + index * 320, 208)
		label.size = Vector2(280, 140)
		label.add_theme_constant_override("line_spacing", 6)
	var hint: Label = hud.result_panel.get_node("RestartHint")
	ArtUI.typography(hint, 20)
	hint.position = Vector2(56, 370)
	hint.size = Vector2(600, 32)
	_level.level_finished.connect(_skin_result)
	if is_instance_valid(_navigator):
		_navigator.bind_level(_level)
	_configured = true


func _layout_result_panel() -> void:
	if is_inside_tree() and is_instance_valid(_level) and is_instance_valid(get_viewport()):
		var panel: Control = _level.flow_hud.result_panel
		panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5


func _layout_menu() -> void:
	if not is_inside_tree():
		return
	# 菜单不撑破矮窗口；仅在内容超出时滚动，焦点仍能带到每个按钮。
	var available_height: float = get_viewport().get_visible_rect().size.y - 48.0
	var paper: StyleBox = menu_panel.get_theme_stylebox("panel")
	var content_height: float = menu_buttons.get_combined_minimum_size().y + paper.get_minimum_size().y
	menu_panel.custom_minimum_size.y = minf(content_height, maxf(240.0, available_height))


func _result_button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open_menu() -> void:
	if not _configured or is_open() or not _level.get_result_snapshot().is_empty() or _level._restart_pending:
		return
	_was_paused = _level.pause_controller.is_paused()
	_level.colony_camera.clear_input_state()
	_level.compact_hud.close_drawer()
	_level.pause_controller.set_menu_active(true)
	_level.pause_controller.set_paused(true)
	resume_button.text = "返回暂停规划" if _was_paused else "继续游戏"
	resume_button.tooltip_text = resume_button.text
	overlay.show()
	menu_scroll.scroll_vertical = 0
	_layout_menu()
	resume_button.grab_focus()


func close_menu() -> void:
	if not is_open():
		return
	overlay.hide()
	_level.pause_controller.set_menu_active(false)
	_level.pause_controller.set_paused(_was_paused)
	resume_button.release_focus()


func is_open() -> bool:
	return is_instance_valid(overlay) and overlay.visible


func _input(event: InputEvent) -> void:
	if GameDisplayManager.is_display_shortcut(event):
		return
	if not is_open():
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()
		elif not (event.is_action("ui_accept") or event.is_action("ui_focus_next") \
				or event.is_action("ui_focus_prev") or event.is_action("ui_up") or event.is_action("ui_down")):
			get_viewport().set_input_as_handled()


func _restart() -> void:
	overlay.hide()
	_level.pause_controller.set_menu_active(false)
	_level.restart_level()


func _return_to_title() -> void:
	if not is_instance_valid(_navigator):
		_navigator = CampaignNavigator.ensure(get_tree())
	_navigator.return_to_menu(_level)


func _quit() -> void:
	if not is_instance_valid(_navigator):
		_navigator = CampaignNavigator.ensure(get_tree())
	_navigator.request_quit()


func _on_level_finished(_snapshot: Dictionary) -> void:
	overlay.hide()
	_level.pause_controller.set_menu_active(false)


func _skin_result(snapshot: Dictionary) -> void:
	var failed: bool = not bool(snapshot.get("victory", false))
	ArtUI.menu_button(_level.flow_hud.result_restart_button, "重新开始", failed, Vector2(230, 72))
	ArtUI.menu_button(result_quit_button, "退出游戏", failed, Vector2(230, 72))
	# 图上共用“进入下一关”，提示仍保留进入第二／三关的实际目标。
	_level.flow_hud.result_continue_button.tooltip_text = _level.flow_hud.result_continue_button.text
	_level.flow_hud._layout_result_actions()
