extends SceneTree
## 真实界面在不同比例下的定向验收；不注入关卡胜利，也不写玩家设置。

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 1024),
	Vector2i(1920, 1200), Vector2i(2560, 1080)]
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio:
			node.preferences_path = "res://.artifact_work/ui-display-audio.cfg"
			node.effects_volume = 0.0
			node.music_volume = 0.0)
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _frames(count: int = 4) -> void:
	for _index: int in range(count):
		await process_frame


func _contained(control: Control, bounds: Rect2) -> bool:
	return bounds.grow(1.0).encloses(control.get_global_rect())


func _run() -> void:
	var display := GameDisplayManager.ensure(self)
	display.preferences_path = "res://.artifact_work/ui-display-preferences.cfg"
	var navigator := CampaignNavigator.ensure(self)
	navigator.progress_store = CampaignProgressStore.new("res://.artifact_work/ui-display-progress.cfg")
	for chapter: int in range(3):
		change_scene_to_file(CampaignNavigator.LEVEL_SCENES[chapter])
		await _frames(8)
		var level = current_scene
		var hud: CompactColonyHUD = level.compact_hud
		for physical: Vector2i in SIZES:
			root.size = physical
			await _frames()
			var canvas := Rect2(Vector2.ZERO, root.get_visible_rect().size)
			var context: String = "chapter %d at %s" % [chapter + 1, physical]
			for control: Control in [hud.top_left, hud.top_right, hud.dock, hud.camera_reset_button]:
				_check(_contained(control, canvas), context + " keeps " + control.name + " on canvas")
			_check(not hud.top_left.get_global_rect().intersects(hud.top_right.get_global_rect()),
				context + " keeps resource and wave controls separate")
			_check(not hud.selection_button.get_global_rect().intersects(hud.dock.get_global_rect()),
				context + " keeps selected-object details clear of command dock")
			level.growth_input_controller.enter_placement_mode()
			await _frames()
			_check(_contained(hud._mode_panel, canvas), context + " keeps placement instructions on canvas")
			var core_screen: Vector2 = level.mother_core.get_global_transform_with_canvas().origin
			_check(not hud._mode_panel.get_global_rect().has_point(core_screen),
				context + " keeps initial core visible during placement")
			level.growth_input_controller.exit_placement_mode()
			await _frames()
			hud.open_page(&"help")
			hud._on_notice("窗口适配验收：消息保留在面板旁边，点击可以查看完整内容。")
			await _frames()
			_check(_contained(hud.drawer, canvas), context + " keeps scrollable manual within canvas")
			_check(not hud.drawer.get_global_rect().intersects(hud.dock.get_global_rect()),
				context + " keeps manual above command dock")
			_check(not hud._toast.get_global_rect().intersects(hud.drawer.get_global_rect()),
				context + " keeps notice clear of open manual")
			hud.close_drawer()
			var menu: LevelMenuLayer = hud.level_menu
			menu.open_menu()
			await _frames()
			_check(_contained(menu.menu_panel, canvas), context + " keeps pause menu within canvas")
			# 如果未来加入菜单内容，滚动仍能访问末尾的显示设置。
			menu.menu_scroll.scroll_vertical = 10000
			await _frames()
			var settings: Control = menu.menu_buttons.get_node("DisplaySettings")
			_check(_contained(settings, menu.menu_scroll.get_global_rect()),
				context + " keeps display settings reachable")
			menu.close_menu()
		# 显示快捷键不能触发建设，也不能关掉暂停菜单。
		var menu: LevelMenuLayer = hud.level_menu
		menu.open_menu()
		var fullscreen_before: bool = display.is_fullscreen()
		_key(KEY_F11)
		await _frames()
		_check(display.is_fullscreen() != fullscreen_before and menu.is_open() and paused,
			"F11 reaches display manager while pause menu remains modal")
		_key(KEY_ENTER, true)
		await _frames()
		_check(display.is_fullscreen() == fullscreen_before and menu.is_open(),
			"Alt+Enter also reaches display manager without selecting a menu action")
		menu.close_menu()
		var story := StoryPlayer.open(level, 2)
		story.playing = false
		for physical: Vector2i in SIZES:
			root.size = physical
			await _frames()
			var canvas := Rect2(Vector2.ZERO, root.get_visible_rect().size)
			for control: Control in [story._caption_scroll, story._previous, story._play, story._next]:
				_check(_contained(control, canvas), "story controls remain accessible at " + str(physical))
			_check(story._caption_scroll.size.y >= 70, "story retains a readable scrollable dialogue area")
		var index_before: int = story.frame_index
		_key(KEY_F11)
		await _frames()
		_check(display.is_fullscreen() != fullscreen_before and story.frame_index == index_before,
			"F11 changes display during CG without advancing story")
		display.set_fullscreen(fullscreen_before)
		story.finish()
		await _frames()
	print("UI_DISPLAY_ADAPTATION ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _key(code: Key, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.alt_pressed = alt
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
