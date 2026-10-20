extends SceneTree
## 用真实渲染器生成三关验收截图；--headless 不可作为画面验收。
## godot --path . --script res://tests/colony_camera_visual_test.gd

var level: ColonyRuntime
var camera: ColonyCamera
var output_dir: String = "/tmp/fungi-camera-visual"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual acceptance requires an actual rendering window.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for chapter: String in ["first_level", "second_level", "third_level"]:
		level = load("res://scenes/levels/" + chapter + ".tscn").instantiate()
		root.add_child(level)
		current_scene = level
		camera = level.colony_camera
		await _frames(8)
		camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		level.get("pause_controller").set_paused(true)
		await _capture(chapter + "_1_opening")
		camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		camera.zoom_at(Vector2(600, 460), 0.75)
		camera.pan_by(Vector2(10000, -10000))
		await _capture(chapter + "_2_min_edge")
		camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		camera.reset_view()
		camera.zoom_at(Vector2(600, 460), 2.0)
		var host: HyphaNode = level.attack_organ.get_parent()
		camera.pan_by(host.global_position - camera.position + Vector2(20, 80))
		_key(KEY_G)
		_motion(Vector2(400, 520))
		await _capture(chapter + "_3_max_preview")
		_key(KEY_ESCAPE)
		camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		camera.reset_view()
		camera.zoom_at(Vector2(600, 460), 1.35)
		level.get("compact_hud").open_page(&"help")
		await _frames(4)
		level.get("compact_hud")._scroll.scroll_vertical = 650
		await _capture(chapter + "_4_help")
		level.get("compact_hud").close_drawer()
		camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		camera.reset_view()
		var target: Vector2 = {"first_level": Vector2(1000, 300), "second_level": Vector2(1050, 450), "third_level": Vector2(950, 360)}[chapter]
		_key(KEY_G)
		_motion(level.get_canvas_transform() * target)
		camera.pan_by(Vector2(100, 0))
		level.growth_input_controller.preview_at(target)
		print("EXPOSURE ", chapter, " ", level.get("frontier_status").get_exposure_text())
		await _capture(chapter + "_6_exposure")
		_key(KEY_ESCAPE)
		level.get("compact_hud").level_menu.open_menu()
		await _capture(chapter + "_5_menu")
		level.get("compact_hud").level_menu.close_menu()
		level.mother_core.take_damage(10000)
		await _capture(chapter + "_7_result")
		level.free()
		await _frames(3)
	print("CAMERA_VISUAL_CAPTURE_RESULT ", output_dir)
	quit()

func _capture(filename: String) -> void:
	var expected_zoom: float = 0.75 if filename.ends_with("_2_min_edge") else (2.0 if filename.ends_with("_3_max_preview") else (1.35 if filename.ends_with("_4_help") else 1.0))
	assert(is_equal_approx(camera.zoom.x, expected_zoom), "Visual fixture did not reach its requested zoom: " + filename)
	# 快速切关后，先让动态 UI 的容器布局和重绘完成，再读取帧缓冲。
	for item: Node in level.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).queue_redraw()
	await _frames(8)
	await create_timer(0.25, true).timeout
	await RenderingServer.frame_post_draw
	if filename.ends_with("_5_menu"):
		var menu: LevelMenuLayer = level.get("compact_hud").level_menu
		print("CAMERA_MENU_RECT ", filename, " ", menu.resume_button.get_global_rect())
	RenderingServer.force_sync()
	var error: Error = root.get_texture().get_image().save_png(output_dir.path_join(filename + ".png"))
	assert(error == OK)

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)

func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame
