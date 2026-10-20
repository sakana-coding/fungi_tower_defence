class_name GameDisplayManager
extends Node
## 全程只有一个物理窗口；场景只声明画布尺寸，不改动玩家的窗口选择。

signal display_changed

const GAMEPLAY_CANVAS := Vector2i(1200, 920)
const TITLE_CANVAS := Vector2i(1200, 800)
const DEFAULT_WINDOW := Vector2i(1100, 740)
const MINIMUM_WINDOW := Vector2i(760, 480)
const SAVE_DELAY: float = 0.45

var preferences_path: String = "user://display_preferences.cfg"
var _window: Window
var _windowed_size := DEFAULT_WINDOW
var _windowed_position := Vector2i.ZERO
var _windowed_maximized: bool = false
var _fullscreen: bool = false
var _screen_index: int = -1
var _usable_rect := Rect2i()
var _save_remaining: float = -1.0
var _monitor_remaining: float = 0.0
var _transition_frames: int = 0
var _headless: bool = false


static func ensure(tree: SceneTree) -> GameDisplayManager:
	var existing := tree.root.get_node_or_null("GameDisplay") as GameDisplayManager
	if is_instance_valid(existing):
		return existing
	var manager := GameDisplayManager.new()
	manager.name = "GameDisplay"
	tree.root.add_child(manager)
	return manager


static func is_display_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_F11 or (event.alt_pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = get_tree().root
	_headless = DisplayServer.get_name() == "headless"
	var override_path: String = OS.get_environment("FUNGI_DISPLAY_PREFERENCES")
	if not override_path.is_empty():
		preferences_path = override_path
	if not _headless:
		_restore_window()
	_window.size_changed.connect(_on_window_changed)
	_window.close_requested.connect(save_preferences)


func configure_canvas(dimensions: Vector2i = GAMEPLAY_CANVAS) -> void:
	# canvas_items + expand 为不同比例补足可见画布；不会裁切底部界面。
	_window.content_scale_size = dimensions
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func is_fullscreen() -> bool:
	return _fullscreen


func toggle_fullscreen() -> void:
	set_fullscreen(not _fullscreen)


func set_fullscreen(enabled: bool) -> void:
	if enabled == _fullscreen:
		return
	if not _headless and enabled:
		_capture_windowed_geometry()
	_fullscreen = enabled
	_transition_frames = 4
	if not _headless:
		if enabled:
			# MODE_FULLSCREEN 在 Windows 上是无边框全屏，不使用独占显示模式。
			_window.mode = Window.MODE_FULLSCREEN
		else:
			_window.mode = Window.MODE_WINDOWED
			_restore_windowed_geometry()
	_save_remaining = SAVE_DELAY
	display_changed.emit()


func _input(event: InputEvent) -> void:
	if is_display_shortcut(event):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# 游戏内“退出”直接结束 SceneTree，也要保留最近一次移动和显示模式。
	if is_instance_valid(_window):
		save_preferences()


func _process(delta: float) -> void:
	if _transition_frames > 0:
		_transition_frames -= 1
	_monitor_remaining -= delta
	if not _headless and _monitor_remaining <= 0.0:
		_monitor_remaining = 0.75
		_check_monitor()
	if _save_remaining >= 0.0:
		_save_remaining -= delta
		if _save_remaining <= 0.0:
			save_preferences()


func _restore_window() -> void:
	var config := ConfigFile.new()
	var loaded: bool = config.load(preferences_path) == OK
	var screen: int = clampi(int(config.get_value("window", "screen", _window.current_screen)), 0, maxi(0, DisplayServer.get_screen_count() - 1))
	_window.current_screen = screen
	_screen_index = screen
	_usable_rect = DisplayServer.screen_get_usable_rect(screen)
	_window.min_size = Vector2i(mini(MINIMUM_WINDOW.x, _usable_rect.size.x), mini(MINIMUM_WINDOW.y, _usable_rect.size.y))
	var remembered_size: Variant = config.get_value("window", "size", DEFAULT_WINDOW)
	_windowed_size = remembered_size if remembered_size is Vector2i else DEFAULT_WINDOW
	_windowed_size = fit_window_size(_windowed_size, _usable_rect.size, not loaded)
	var remembered_position: Variant = config.get_value("window", "position", _usable_rect.position + (_usable_rect.size - _windowed_size) / 2)
	_windowed_position = remembered_position if remembered_position is Vector2i else _usable_rect.position
	_windowed_maximized = bool(config.get_value("window", "maximized", false))
	_fullscreen = bool(config.get_value("window", "fullscreen", false))
	_transition_frames = 4
	_window.mode = Window.MODE_WINDOWED
	_restore_windowed_geometry()
	if _fullscreen:
		_window.mode = Window.MODE_FULLSCREEN


static func fit_window_size(requested: Vector2i, usable: Vector2i, first_launch: bool = false) -> Vector2i:
	# 为系统标题栏和任务栏留出空间；较小屏幕按比例缩小初始窗口。
	var available := Vector2i(maxi(320, usable.x - 32), maxi(240, usable.y - 56))
	var minimum := Vector2i(mini(MINIMUM_WINDOW.x, available.x), mini(MINIMUM_WINDOW.y, available.y))
	if first_launch:
		var ratio: float = minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
		requested = Vector2i(Vector2(requested) * ratio)
	return Vector2i(clampi(requested.x, minimum.x, available.x), clampi(requested.y, minimum.y, available.y))


func _restore_windowed_geometry() -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(_window.current_screen)
	_windowed_size = fit_window_size(_windowed_size, usable.size)
	_windowed_position.x = clampi(_windowed_position.x, usable.position.x + 8, usable.end.x - _windowed_size.x - 8)
	_windowed_position.y = clampi(_windowed_position.y, usable.position.y + 32, usable.end.y - _windowed_size.y - 8)
	_window.size = _windowed_size
	_window.position = _windowed_position
	if _windowed_maximized:
		_window.mode = Window.MODE_MAXIMIZED


func _capture_windowed_geometry() -> void:
	if _window.mode == Window.MODE_MAXIMIZED:
		_windowed_maximized = true
	elif _window.mode == Window.MODE_WINDOWED:
		_windowed_maximized = false
		_windowed_size = _window.size
		_windowed_position = _window.position


func _on_window_changed() -> void:
	if not _headless and _transition_frames == 0:
		_capture_windowed_geometry()
	_save_remaining = SAVE_DELAY
	display_changed.emit()


func _check_monitor() -> void:
	var screen: int = _window.current_screen
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if screen == _screen_index and usable == _usable_rect:
		return
	_screen_index = screen
	_usable_rect = usable
	_window.min_size = Vector2i(mini(MINIMUM_WINDOW.x, usable.size.x), mini(MINIMUM_WINDOW.y, usable.size.y))
	# 正常拖动、最大化不会被重置；只在显示器变小或窗口完全离屏时修正。
	if _window.mode == Window.MODE_WINDOWED:
		_capture_windowed_geometry()
		var window_rect := Rect2i(_window.position, _window.size)
		if _window.size.x > usable.size.x or _window.size.y > usable.size.y or not window_rect.intersects(usable):
			_restore_windowed_geometry()
	_save_remaining = SAVE_DELAY


func save_preferences() -> void:
	_save_remaining = -1.0
	if _headless:
		return
	if _transition_frames == 0 and not _fullscreen:
		_capture_windowed_geometry()
	var config := ConfigFile.new()
	config.set_value("window", "size", _windowed_size)
	config.set_value("window", "position", _windowed_position)
	config.set_value("window", "screen", _window.current_screen)
	config.set_value("window", "maximized", _windowed_maximized)
	config.set_value("window", "fullscreen", _fullscreen)
	var error: Error = config.save(preferences_path)
	if error != OK:
		push_warning("显示设置暂时无法保存：%s" % error_string(error))
