class_name ColonyCamera
extends Camera2D
## 只改变画布视野。输入由正式关卡显式分发，不注册独立的 _input。

signal view_changed

@export var move_speed: float = 600.0
@export_range(0.01, 0.5) var zoom_step: float = 0.1
@export var minimum_zoom: float = 0.75
@export var maximum_zoom: float = 2.0
@export var initial_zoom: float = 1.0
@export var gesture_pan_speed: float = 1.0
## 关卡使用世界坐标取景，窗口尺寸或宽高比不会改变开局关注的位置。
@export var opening_position: Vector2 = Vector2(600, 460)

var camera_bounds: Rect2
var controls_allowed: Callable
var pointer_over_ui: Callable
var dragging: bool = false
var initialized: bool = false
var _home_position: Vector2
var _keys: Dictionary[int, bool] = {}
var _focused: bool = true
var _stopped: bool = false
var _last_transform: Transform2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = false
	position_smoothing_enabled = false
	get_viewport().size_changed.connect(_on_viewport_resized)


## 在正式关卡完成窗口配置后调用；取景位置独立于窗口大小。
func initialize(bounds: Rect2, permission: Callable, ui_test: Callable) -> void:
	camera_bounds = bounds.abs()
	controls_allowed = permission
	pointer_over_ui = ui_test
	_home_position = opening_position
	global_position = _home_position
	zoom = Vector2.ONE * clampf(initial_zoom, minimum_zoom, maximum_zoom)
	initialized = true
	_stopped = false
	enabled = true
	make_current()
	_apply_view()


func _process(delta: float) -> void:
	if not can_control():
		clear_input_state()
		return
	if get_viewport().gui_get_focus_owner() != null:
		_keys.clear()
	var direction := Vector2(float(_keys.has(KEY_D)) - float(_keys.has(KEY_A)),
		float(_keys.has(KEY_S)) - float(_keys.has(KEY_W)))
	if not direction.is_zero_approx():
		pan_by(direction.normalized() * move_speed * delta / zoom.x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		clear_input_state()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	stop()
	initialized = false


func can_control() -> bool:
	return initialized and not _stopped and _focused and controls_allowed.is_valid() and bool(controls_allowed.call())


func clear_input_state() -> void:
	dragging = false
	_keys.clear()


func stop() -> void:
	clear_input_state()
	_stopped = true


func handle_input(event: InputEvent) -> bool:
	# 松开不受 HUD 命中测试影响，也不需要鼠标仍留在世界区域。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		var was_dragging: bool = dragging
		dragging = false
		return was_dragging
	if event is InputEventKey and not event.pressed:
		_keys.erase(_keycode(event))
	if not can_control():
		clear_input_state()
		return false
	if event is InputEventKey:
		return _handle_key(event)
	if dragging and event is InputEventMouseMotion:
		pan_by(-event.relative / zoom)
		return true
	# 拖动期间不让左键、右键或其他鼠标操作落入建造/选择控制器。
	if dragging and event is InputEventMouseButton:
		return true
	if (event is InputEventMouse or event is InputEventGesture) and pointer_over_ui.is_valid() \
			and bool(pointer_over_ui.call(event.position)):
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			return true
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				var steps: float = event.factor if event.factor > 0.0 else 1.0
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					steps = -steps
				zoom_at(event.position, pow(1.0 + zoom_step, steps))
			return true
	# macOS 原生滚动有手势 phase 时只发 PanGesture，否则才发滚轮。
	# 不再把 PanGesture 合成为滚轮，捏合也只处理它自己的 factor。
	if event is InputEventPanGesture:
		pan_by(event.delta * gesture_pan_speed / zoom)
		return true
	if event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
		return true
	return false


func _handle_key(event: InputEventKey) -> bool:
	var code: int = _keycode(event)
	if get_viewport().gui_get_focus_owner() != null:
		_keys.clear()
		return false
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		_keys.clear()
		return false
	if code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		if event.pressed and not event.echo:
			_keys[code] = true
		return true
	if code == KEY_HOME:
		if event.pressed and not event.echo:
			reset_view()
		return true
	return false


func _keycode(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode


func pan_by(world_delta: Vector2) -> void:
	if not can_control() or not world_delta.is_finite():
		return
	global_position += world_delta
	_apply_view()


func zoom_at(screen_point: Vector2, factor: float) -> void:
	if not can_control() or not is_finite(factor) or factor <= 0.0:
		return
	var before: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_point
	zoom = Vector2.ONE * clampf(zoom.x * factor, minimum_zoom, maximum_zoom)
	force_update_scroll()
	var after: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_point
	global_position += before - after
	_apply_view()


func reset_view() -> void:
	if not can_control():
		return
	clear_input_state()
	global_position = _home_position
	zoom = Vector2.ONE * clampf(initial_zoom, minimum_zoom, maximum_zoom)
	_apply_view()


func _on_viewport_resized() -> void:
	if initialized:
		_apply_view()


func _apply_view() -> void:
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var center: Vector2 = global_position
	for axis: int in range(2):
		# 超宽窗口或缩小到整张地图时，固定在地图中心；地面继续覆盖视口。
		# 这样无需扩大可平移范围来迁就屏幕，也不会把玩家带到大片空纸上。
		if camera_bounds.size[axis] <= half[axis] * 2.0:
			center[axis] = camera_bounds.get_center()[axis]
		else:
			center[axis] = clampf(center[axis], camera_bounds.position[axis] + half[axis], camera_bounds.end[axis] - half[axis])
	global_position = center
	force_update_scroll()
	var actual: Transform2D = get_viewport().get_canvas_transform()
	if actual != _last_transform:
		_last_transform = actual
		view_changed.emit()
