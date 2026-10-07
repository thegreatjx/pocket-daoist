extends CanvasLayer
class_name PauseMenu
# 暂停菜单：继续 / 设置 / 重开本局 / 回标题。
# process_mode = ALWAYS，树暂停时仍能响应输入与点击。

@onready var root_panel: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBox/ResumeButton
@onready var settings_btn: Button = $Root/Panel/VBox/SettingsButton
@onready var restart_btn: Button = $Root/Panel/VBox/RestartButton
@onready var title_btn: Button = $Root/Panel/VBox/TitleButton
@onready var settings_layer: Control = $SettingsLayer
@onready var status_label: Label = $Root/Panel/VBox/StatusLabel

var settings_panel: SettingsPanel = null

func _ready() -> void:
	visible = false
	root_panel.visible = false
	GameFlow.state_changed.connect(_on_state_changed)
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	title_btn.pressed.connect(_on_title_pressed)
	_on_state_changed(-1, GameFlow.state)

# 设置面板打开时优先拦截 ESC：先关设置，而不是直接恢复游戏。
# 用 _input 而非 _unhandled_input，并标记为已处理，
# 这样 GameFlow 的 _unhandled_input 就不会收到同一次按键。
func _input(event: InputEvent) -> void:
	if not _is_settings_open():
		return
	if not (event is InputEventKey):
		return
	if event.keycode != KEY_ESCAPE or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	_close_settings()

func _is_settings_open() -> bool:
	return settings_panel != null and is_instance_valid(settings_panel)

func _on_state_changed(_from: int, to: int) -> void:
	var show_menu = (to == GameFlow.State.PAUSED)
	visible = show_menu
	root_panel.visible = show_menu
	if show_menu:
		status_label.text = Stats.summary_text()
		status_label.visible = status_label.text != ""
	else:
		# 离开暂停态（恢复/重开/回标题）时收起设置面板，防止残留
		_close_settings()

func _on_resume_pressed() -> void:
	GameFlow.resume()

func _on_settings_pressed() -> void:
	if _is_settings_open():
		_close_settings()
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(_close_settings)
	# 面板自带全屏遮罩与居中，挂上即可铺满父容器
	settings_layer.add_child(settings_panel)

func _close_settings() -> void:
	if _is_settings_open():
		settings_panel.queue_free()
	settings_panel = null

func _on_restart_pressed() -> void:
	_close_settings()
	# 重开算一局结束，先记录战绩再重载
	GameFlow.restart_run()

func _on_title_pressed() -> void:
	_close_settings()
	GameFlow.to_title()
