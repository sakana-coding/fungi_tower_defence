extends SceneTree
## 真实三关与 Viewport 输入回归；测试伤害/新增空花朵仅用于验证修复和搬迁命中。

const LEVELS: Array[String] = ["first_level", "second_level", "third_level"]
var level: ColonyRuntime
var camera: ColonyCamera
var checks: int = 0
var failures: Array[String] = []
var view_notifications: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for chapter: String in LEVELS:
		await _fresh(chapter)
		_test_view_math(chapter)
		await _test_resize_and_labels(chapter)
		await _test_input_isolation(chapter)
		await _test_pause_previews(chapter)
		await _test_world_actions(chapter)
		await _test_terminal(chapter)
	await _test_reload_and_switch()
	await _test_legacy_demo()
	print("COLONY_CAMERA_TEST_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _fresh(chapter: String) -> void:
	if is_instance_valid(level):
		level.free()
	paused = false
	level = load("res://scenes/levels/" + chapter + ".tscn").instantiate() as ColonyRuntime
	root.add_child(level)
	current_scene = level
	camera = level.colony_camera
	await _frames(4)
	# Synthetic input tests do not depend on which desktop application owns focus.
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	camera.view_changed.connect(func() -> void: view_notifications += 1)


func _test_view_math(chapter: String) -> void:
	_check(camera.enabled and camera.initialized and camera.process_mode == Node.PROCESS_MODE_ALWAYS,
		chapter + ": formal camera enabled and always processing")
	_check(root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), chapter + ": initial composition unchanged")
	_check(root.get_visible_rect().size.is_equal_approx(Vector2(1200, 920)), chapter + ": uses final runtime viewport")
	_check(level.get_node("World").transform == Transform2D.IDENTITY, chapter + ": World transform unchanged")
	var home: Vector2 = camera.position
	_key(KEY_D, true)
	camera._process(0.1)
	_key(KEY_D, false)
	_check(camera.position.is_equal_approx(home + Vector2(60, 0)), chapter + ": WASD speed is 600 pixels per second")
	camera.reset_view()
	_key(KEY_D, true)
	_key(KEY_S, true)
	camera._process(0.1)
	_key(KEY_D, false)
	_key(KEY_S, false)
	_check(is_equal_approx(camera.position.distance_to(home), 60.0), chapter + ": diagonals normalized")
	camera.reset_view()
	var anchor := Vector2(460, 370)
	var before: Vector2 = root.get_canvas_transform().affine_inverse() * anchor
	_wheel(anchor, true)
	_check(is_equal_approx(camera.zoom.x, 1.1), chapter + ": one wheel notch gives 10 percent zoom")
	_check((root.get_canvas_transform().affine_inverse() * anchor).distance_to(before) < 0.01,
		chapter + ": actual canvas keeps world point under cursor")
	_wheel(anchor, false)
	_check(is_equal_approx(camera.zoom.x, 1.0), chapter + ": opposite wheel step reverses zoom")
	camera.zoom_at(anchor, 100)
	_check(camera.zoom.x == 2.0, chapter + ": upper zoom limit")
	var start: Vector2 = camera.position
	_key(KEY_A, true)
	camera._process(0.1)
	_key(KEY_A, false)
	_check(camera.position.distance_to(start + Vector2(-30, 0)) < 0.01, chapter + ": speed compensated by zoom")
	camera.zoom_at(anchor, 0.001)
	_check(camera.zoom.x == 0.75, chapter + ": lower zoom limit")
	camera.pan_by(Vector2(1e6, -1e6))
	var visible: Rect2 = root.get_canvas_transform().affine_inverse() * root.get_visible_rect()
	_check(camera.camera_bounds.grow(0.1).encloses(visible), chapter + ": visible extent obeys bounds")
	var ground: Control = level.get_node("World/Ground")
	_check(ground.get_rect().encloses(visible), chapter + ": ground covers zoomed out edge")
	var bounds: Rect2 = camera.camera_bounds
	camera.camera_bounds = Rect2(100, 200, 80, 60)
	camera.pan_by(Vector2(100, -100))
	_check(camera.position.is_equal_approx(Vector2(140, 230)), chapter + ": undersized map centers without reverse clamp")
	camera.camera_bounds = bounds
	_tap(KEY_HOME)
	_check(camera.position.is_equal_approx(home) and camera.zoom == Vector2.ONE, chapter + ": Home resets position and zoom")
	var notifications: int = view_notifications
	camera.pan_by(Vector2.ZERO)
	_check(view_notifications == notifications, chapter + ": unchanged view emits no refresh")


func _test_resize_and_labels(chapter: String) -> void:
	var marker := preload("res://scenes/colony/growth_target.tscn").instantiate() as GrowthTarget
	level.get_node("World/GrowthTargets").add_child(marker)
	var corner: Vector2 = root.get_canvas_transform().affine_inverse() * Vector2(1170, 720)
	marker.show_status({"target_position": corner, "state": &"waiting", "task_id": 99})
	camera.zoom_at(Vector2(600, 460), 2.0)
	camera.pan_by(corner - camera.position - Vector2(280, 80))
	await _frames(2)
	var rect: Rect2 = marker.status_label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, marker.status_label.size)
	_check(root.get_visible_rect().grow(-7).encloses(rect), chapter + ": active target label stays within viewport edge")
	_check(absf(rect.size.x - marker.status_label.size.x) < 0.01, chapter + ": target label keeps screen size at 2x zoom")
	camera.zoom_at(Vector2(600, 460), 0.375)
	await _frames(2)
	rect = marker.status_label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, marker.status_label.size)
	_check(absf(rect.size.x - marker.status_label.size.x) < 0.01, chapter + ": target label keeps screen size at 0.75x zoom")
	var screen_rect: Rect2 = root.get_visible_rect()
	var home: Vector2 = camera._home_position
	root.size = Vector2i(1600, 920)
	await _frames(3)
	_check(root.get_visible_rect().size.x > screen_rect.size.x, chapter + ": actual window resize changes viewport")
	var view: Rect2 = root.get_canvas_transform().affine_inverse() * root.get_visible_rect()
	_check(camera.camera_bounds.grow(0.1).encloses(view), chapter + ": resize recalculates camera limits")
	_check((level.get_node("World/Ground") as Control).get_rect().encloses(view), chapter + ": resized view remains covered by ground")
	root.size = Vector2i(1200, 920)
	await _frames(3)
	camera.reset_view()
	_check(camera.position.is_equal_approx(home), chapter + ": resize preserves initial reset center")
	marker.free()


func _test_input_isolation(chapter: String) -> void:
	var ui: CompactColonyHUD = level.get("compact_hud")
	var original_dock: Rect2 = ui.dock.get_global_rect()
	var original_resources: Rect2 = ui.top_left.get_global_rect()
	ui.open_page(&"help")
	await _frames(3)
	var point: Vector2 = ui._scroll.get_global_rect().get_center()
	var transform: Transform2D = root.get_canvas_transform()
	_button(point, MOUSE_BUTTON_MIDDLE, true)
	_check(not camera.dragging, chapter + ": HUD cannot start a drag")
	_button(point, MOUSE_BUTTON_MIDDLE, false)
	_wheel(point, false)
	var pan := InputEventPanGesture.new()
	pan.position = point
	pan.delta = Vector2(40, 30)
	root.push_input(pan, true)
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = point
	pinch.factor = 1.3
	root.push_input(pinch, true)
	_check(root.get_canvas_transform() == transform, chapter + ": HUD isolates wheel, pan and pinch")
	_check(ui._scroll.scroll_vertical > 0, chapter + ": scrolling the detail drawer scrolls its contents")
	ui.close_drawer()
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	_motion(Vector2(540, 430), Vector2(40, 30), MOUSE_BUTTON_MASK_MIDDLE)
	_check(camera.dragging and root.get_canvas_transform() != transform, chapter + ": middle drag moves map")
	var selection: HyphaNode = level.selected_node
	var count: int = level.construction_coordinator.get_snapshot().entries.size()
	_click(Vector2(600, 500))
	_check(level.selected_node == selection and level.construction_coordinator.get_snapshot().entries.size() == count,
		chapter + ": left click while dragging does not select or build")
	_button(ui.dock.get_global_rect().get_center(), MOUSE_BUTTON_MIDDLE, false)
	var position: Vector2 = camera.position
	_motion(Vector2(700, 300), Vector2(160, -130))
	_check(not camera.dragging and camera.position == position, chapter + ": release over HUD ends drag immediately")
	pan.position = Vector2(500, 400)
	pan.delta = Vector2(24, 18)
	root.push_input(pan, true)
	_check(camera.position.is_equal_approx(position + pan.delta / camera.zoom), chapter + ": pan gesture only translates")
	var previous_zoom: Vector2 = camera.zoom
	pinch.position = pan.position
	pinch.factor = 1.2
	var world_point: Vector2 = root.get_canvas_transform().affine_inverse() * pinch.position
	root.push_input(pinch, true)
	_check(is_equal_approx(camera.zoom.x, previous_zoom.x * 1.2) and
		(root.get_canvas_transform().affine_inverse() * pinch.position).distance_to(world_point) < 0.01,
		chapter + ": pinch applies once and anchors cursor")
	_check(ui.dock.get_global_rect() == original_dock and ui.top_left.get_global_rect() == original_resources,
		chapter + ": screen UI rectangles stable under pan and zoom")
	_key(KEY_D, true)
	ui.level_menu.open_menu()
	position = camera.position
	camera._process(0.2)
	_wheel(Vector2(500, 400), true)
	_check(camera.position == position and camera._keys.is_empty() and not camera.dragging,
		chapter + ": menu clears held movement and rejects camera input")
	ui.level_menu.close_menu()
	camera._process(0.1)
	_check(camera.position == position, chapter + ": menu close cannot resume stale movement")
	_key(KEY_D, false)
	var edit := LineEdit.new()
	ui._root.add_child(edit)
	edit.grab_focus()
	_key(KEY_A, true)
	camera._process(0.1)
	_check(camera.position == position and camera._keys.is_empty(), chapter + ": keyboard focus prevents camera movement")
	_key(KEY_A, false)
	edit.free()
	_key(KEY_W, true)
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	camera._process(0.1)
	_check(not camera.dragging and camera._keys.is_empty() and camera.position == position,
		chapter + ": focus loss clears drag and movement")
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	camera._process(0.1)
	_check(camera.position == position, chapter + ": focus return has no stale movement")
	_key(KEY_W, false)
	_click(ui.camera_reset_button.get_global_rect().get_center())
	_check(root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), chapter + ": real HUD reset click")


func _test_pause_previews(chapter: String) -> void:
	var pause_controller: GlobalPauseController = level.get("pause_controller")
	_tap(KEY_SPACE)
	await _frames(2)
	_check(paused, chapter + ": Space planning pause")
	var before: Dictionary = _simulation_snapshot()
	for mode: Key in [KEY_G, KEY_B, KEY_L]:
		_tap(mode)
		_motion(Vector2(420, 400))
		var old_point: Vector2 = level.get_global_mouse_position()
		_key(KEY_D, true)
		await _frames(3)
		_key(KEY_D, false)
		var point: Vector2 = level.get_global_mouse_position()
		_check(not point.is_equal_approx(old_point), chapter + ": paused WASD changes world point with stationary cursor")
		var marker: Node2D
		if mode == KEY_G:
			marker = level.growth_input_controller._preview_marker
		elif mode == KEY_B:
			marker = level.cultivation_input_controller._remote_preview_marker
		else:
			marker = level.connection_input_controller._preview_marker
		var preview: Dictionary = marker.get("_preview")
		_check((preview.get("target_position", Vector2.INF) as Vector2).distance_to(point) < 0.01,
			chapter + ": paused preview refreshed for " + OS.get_keycode_string(mode))
		_wheel(Vector2(420, 400), true)
		_tap(KEY_ESCAPE)
	_check(before == _simulation_snapshot(), chapter + ": previews freeze timers, packets, budget, flow and construction")
	pause_controller.set_paused(false)
	camera.reset_view()


func _test_world_actions(chapter: String) -> void:
	camera.zoom_at(Vector2(600, 460), 1.35)
	camera.pan_by(Vector2(-35, 25))
	await _frames(2)
	var host: HyphaNode = level.attack_organ.get_parent() as HyphaNode
	_click(_screen(host.global_position))
	await _frames(2)
	_check(level.selected_node == host, chapter + ": transformed selection hits original world node")
	var target: Vector2 = Vector2(330, 395) if chapter == "first_level" else host.global_position + Vector2(-100, -65)
	_tap(KEY_G)
	# 连续缩放后立即确认，没有等下一帧。
	for index: int in range(3):
		_wheel(_screen(target), true)
	_click(_screen(target))
	var id: String = String(level.construction_coordinator.get_snapshot().selected_id)
	var request: Dictionary = level.construction_coordinator.get_request(id)
	_check(not id.is_empty() and (request.get("parameters", {}).get("target_position", Vector2.INF) as Vector2).distance_to(target) < 0.1,
		chapter + ": zoom followed by immediate click builds at world target")
	_tap(KEY_ESCAPE)
	_tap(KEY_T)
	_check(level.get("_operation_mode") == &"retarget", chapter + ": retarget starts")
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	_motion(Vector2(520, 410), Vector2(20, 10), MOUSE_BUTTON_MASK_MIDDLE)
	_button(Vector2(520, 410), MOUSE_BUTTON_MIDDLE, false)
	var next_target: Vector2 = target + Vector2(12, 10)
	_motion(_screen(next_target))
	var preview: Dictionary = level.get("_operation_preview")
	_check((preview.get("target_position", Vector2.INF) as Vector2).distance_to(next_target) < 0.1,
		chapter + ": camera drag works inside retarget mode")
	var planner_pause: GlobalPauseController = level.get("pause_controller")
	planner_pause.set_paused(true)
	var paused_snapshot: Dictionary = _simulation_snapshot()
	camera.pan_by(Vector2(2, 0))
	preview = level.get("_operation_preview")
	_check((preview.get("target_position", Vector2.INF) as Vector2).distance_to(level.get_global_mouse_position()) < 0.1
		and paused_snapshot == _simulation_snapshot(), chapter + ": paused retarget preview follows camera without simulation")
	planner_pause.set_paused(false)
	_click(_screen(next_target))
	request = level.construction_coordinator.get_request(id)
	_check((request.get("parameters", {}).get("target_position", Vector2.INF) as Vector2).distance_to(next_target) < 0.1,
		chapter + ": transformed retarget confirmation")
	_tap(KEY_ESCAPE)
	level.construction_coordinator.cancel_request(id)
	camera.reset_view()
	camera.zoom_at(Vector2(600, 460), 1.2)
	camera.pan_by(Vector2(20, 130))
	_tap(KEY_B)
	_click(_screen(target + Vector2(35, 0)))
	id = String(level.construction_coordinator.get_snapshot().selected_id)
	request = level.construction_coordinator.get_request(id)
	_check(request.get("kind") == &"remote_cultivation", chapter + ": transformed remote placement")
	_tap(KEY_ESCAPE)
	level.construction_coordinator.cancel_request(id)
	# 空花朵夹具沿真实母核接通，用于排除占用槽位对搬迁验证的干扰。
	var empty := preload("res://scenes/colony/hypha_node.tscn").instantiate() as HyphaNode
	level.hypha_nodes.add_child(empty)
	empty.global_position = host.global_position + Vector2(75, -20)
	level.network_system.register_node(empty)
	var edge := preload("res://scenes/colony/hypha_edge.tscn").instantiate() as HyphaEdge
	edge.start_node = level.mother_core
	edge.end_node = empty
	level.hypha_edges.add_child(edge)
	level.network_system.register_edge(edge)
	await _frames(2)
	_tap(KEY_L)
	_click(_screen(host.global_position))
	await _frames(2)
	_click(_screen(empty.global_position))
	id = String(level.construction_coordinator.get_snapshot().selected_id)
	request = level.construction_coordinator.get_request(id)
	_check(request.get("kind") == &"connection", chapter + ": transformed two-endpoint connection")
	_tap(KEY_ESCAPE)
	level.construction_coordinator.cancel_request(id)
	edge.take_damage(5.0)
	_tap(KEY_F)
	_click(_screen(edge.get_point_at(0.5)))
	_check(level.repair_input_controller.get_selected_target() == edge, chapter + ": transformed repair selection")
	_tap(KEY_J)
	_check(level.repair_system.has_active_task(), chapter + ": transformed repair request")
	_tap(KEY_ESCAPE)
	_click(_screen(host.global_position))
	await _frames(2)
	_tap(KEY_M)
	_check(level.get("_operation_mode") == &"transplant", chapter + ": transplant starts")
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	_motion(Vector2(510, 405), Vector2(10, 5), MOUSE_BUTTON_MASK_MIDDLE)
	_button(Vector2(510, 405), MOUSE_BUTTON_MIDDLE, false)
	var pause_controller: GlobalPauseController = level.get("pause_controller")
	pause_controller.set_paused(true)
	_motion(_screen(empty.global_position))
	camera.pan_by(Vector2(1, 0))
	var frozen: Dictionary = _simulation_snapshot()
	_click(_screen(empty.global_position))
	_check(not level.get("transplant_system").has_active_task() and frozen == _simulation_snapshot(),
		chapter + ": paused transplant only previews, cannot commit")
	pause_controller.set_paused(false)
	_click(_screen(empty.global_position))
	_check(level.get("transplant_system").get_task_snapshot().get("destination") == empty,
		chapter + ": transformed transplant confirmation")
	camera.reset_view()


func _test_terminal(chapter: String) -> void:
	_key(KEY_D, true)
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	level.mother_core.take_damage(10000)
	await _frames(3)
	var position: Vector2 = camera.position
	_wheel(Vector2(500, 400), true)
	camera._process(0.2)
	_check(not camera.can_control() and not camera.dragging and camera._keys.is_empty()
		and camera.position == position and camera.zoom == Vector2.ONE, chapter + ": settlement disables and clears camera")
	_key(KEY_D, false)


func _test_reload_and_switch() -> void:
	await _fresh("first_level")
	camera.pan_by(Vector2(50, 30))
	_key(KEY_D, true)
	level.call("restart_level")
	await _frames(6)
	level = current_scene as ColonyRuntime
	camera = level.colony_camera
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_check(camera.initialized and camera._keys.is_empty() and not camera.dragging
		and root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), "real scene reload resets camera state")
	_key(KEY_D, false)
	_key(KEY_D, true)
	_button(Vector2(500, 400), MOUSE_BUTTON_MIDDLE, true)
	change_scene_to_file("res://scenes/levels/second_level.tscn")
	await _frames(6)
	level = current_scene as ColonyRuntime
	camera = level.colony_camera
	_check(camera.initialized and camera._keys.is_empty() and not camera.dragging
		and camera.zoom == Vector2.ONE, "real scene switch resets camera state")
	_key(KEY_D, false)
	level.free()
	level = null
	await _frames(2)
	_check(not paused, "scene exit clears global pause")


func _test_legacy_demo() -> void:
	var demo: Node = load("res://scenes/levels/colony_operations_demo.tscn").instantiate()
	root.add_child(demo)
	await _frames(3)
	_check(not demo.get_node("ColonyCamera").enabled, "legacy development demo keeps camera disabled")
	demo.free()
	await _frames(2)


func _simulation_snapshot() -> Dictionary:
	return {"clock": level.get("elapsed_seconds"), "capital": level.mother_core.get_budget_snapshot(),
		"queue": level.construction_coordinator.get_snapshot().duplicate(true),
		"flow": level.get("wave_flow").get_snapshot().duplicate(true),
		"packets": level.get_node("World/Packets").get_child_count()}


func _screen(point: Vector2) -> Vector2:
	return level.get_canvas_transform() * point


func _key(code: Key, pressed_value: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed_value
	root.push_input(event, true)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _button(point: Vector2, index: MouseButton, pressed_value: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = pressed_value
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE if pressed_value and index == MOUSE_BUTTON_MIDDLE else 0
	root.push_input(event, true)


func _click(point: Vector2) -> void:
	_button(point, MOUSE_BUTTON_LEFT, true)
	_button(point, MOUSE_BUTTON_LEFT, false)


func _wheel(point: Vector2, inward: bool) -> void:
	var button: MouseButton = MOUSE_BUTTON_WHEEL_UP if inward else MOUSE_BUTTON_WHEEL_DOWN
	_button(point, button, true)
	_button(point, button, false)


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO, mask: MouseButtonMask = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)


func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
