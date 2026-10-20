class_name DisplaySettingsControl
extends HBoxContainer
## 标题页和暂停菜单共用同一显示设置入口。

@onready var mode_button: Button = $ModeButton
var _display: GameDisplayManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_display = GameDisplayManager.ensure(get_tree())
	mode_button.pressed.connect(_display.toggle_fullscreen)
	_display.display_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	mode_button.text = "切换为窗口" if _display.is_fullscreen() else "无边框全屏"
	mode_button.tooltip_text = "F11 或 Alt + Enter 随时切换，退出后保留设置。"
