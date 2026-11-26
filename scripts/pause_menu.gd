extends CanvasLayer
class_name PauseMenu
# 暂停菜单：继续 / 设置 / 重开本局 / 回标题。
# process_mode = ALWAYS，树暂停时仍能响应输入与点击。

@onready var root_panel: Control = $Root
@onready var dim_rect: ColorRect = $Root/Dim
@onready var panel_box: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/VBox/TitleLabel
@onready var resume_btn: Button = $Root/Panel/VBox/ResumeButton
@onready var settings_btn: Button = $Root/Panel/VBox/SettingsButton
@onready var restart_btn: Button = $Root/Panel/VBox/RestartButton
@onready var title_btn: Button = $Root/Panel/VBox/TitleButton
@onready var settings_layer: Control = $SettingsLayer
@onready var status_label: Label = $Root/Panel/VBox/StatusLabel

@export var enable_debug_sandbox: bool = false

var settings_panel: SettingsPanel = null
var codex_btn: Button = null
var codex_panel: V2CodexPanel = null
var sandbox_btn: Button = null

func _ready() -> void:
	visible = false
	root_panel.visible = false
	var vbox := get_node_or_null("Root/Panel/VBox") as VBoxContainer
	if vbox != null:
		codex_btn = Button.new()
		codex_btn.name = "CodexButton"
		codex_btn.text = "五行法典"
		codex_btn.custom_minimum_size = Vector2(300, 46)
		codex_btn.add_theme_font_size_override("font_size", 24)
		vbox.add_child(codex_btn)
		if resume_btn != null:
			vbox.move_child(codex_btn, resume_btn.get_index() + 1)
		codex_btn.pressed.connect(_on_codex_pressed)

		if enable_debug_sandbox:
			sandbox_btn = Button.new()
			sandbox_btn.name = "DebugSandboxButton"
			sandbox_btn.text = "调试沙盒 (F9)"
			sandbox_btn.custom_minimum_size = Vector2(300, 42)
			sandbox_btn.add_theme_font_size_override("font_size", 22)
			vbox.add_child(sandbox_btn)
			if codex_btn != null:
				vbox.move_child(sandbox_btn, codex_btn.get_index() + 1)
			sandbox_btn.pressed.connect(_on_sandbox_pressed)
	_apply_qinglv_theme()
	GameFlow.state_changed.connect(_on_state_changed)
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	title_btn.pressed.connect(_on_title_pressed)
	_on_state_changed(-1, GameFlow.state)

func _apply_qinglv_theme() -> void:
	if dim_rect != null:
		dim_rect.color = Color(0.05, 0.14, 0.12, 0.52)
	if panel_box != null:
		panel_box.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 28))
		XianxiaUITheme.attach_ornaments(panel_box, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	if title_label != null:
		var title_font = load("res://assets/title_font.tres")
		if title_font != null:
			title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	if status_label != null:
		status_label.modulate = Color.WHITE
		status_label.add_theme_color_override("font_color", Color(0.24, 0.36, 0.32))
	var btns: Array[Button] = [resume_btn, settings_btn, restart_btn, title_btn]
	if codex_btn != null:
		btns.append(codex_btn)
	for i in range(btns.size()):
		var btn: Button = btns[i]
		if btn == null:
			continue
		XianxiaUITheme.style_button(btn, "cinnabar" if i == 0 else "secondary")
	if sandbox_btn != null:
		XianxiaUITheme.style_button(sandbox_btn, "dark_gold")

# 设置面板打开时优先拦截 ESC：先关设置，而不是直接恢复游戏。
# 用 _input 而非 _unhandled_input，并标记为已处理，
# 这样 GameFlow 的 _unhandled_input 就不会收到同一次按键。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.keycode != KEY_ESCAPE or not event.pressed or event.echo:
		return
	if _is_codex_open():
		get_viewport().set_input_as_handled()
		_close_codex()
		return
	if _is_settings_open():
		get_viewport().set_input_as_handled()
		_close_settings()

func _is_settings_open() -> bool:
	return settings_panel != null and is_instance_valid(settings_panel)

func _is_codex_open() -> bool:
	return codex_panel != null and is_instance_valid(codex_panel)

func _on_state_changed(_from: int, to: int) -> void:
	var show_menu = (to == GameFlow.State.PAUSED)
	visible = show_menu
	root_panel.visible = show_menu
	if show_menu:
		status_label.text = Stats.summary_text()
		status_label.visible = status_label.text != ""
	else:
		# 离开暂停态（恢复/重开/回标题）时收起面板，防止残留
		_close_settings()
		_close_codex()

func _on_resume_pressed() -> void:
	GameFlow.resume()

func _on_sandbox_pressed() -> void:
	_close_settings()
	_close_codex()
	GameFlow.resume()
	var tree := get_tree()
	if tree != null:
		var gm := tree.get_first_node_in_group("game_manager")
		if gm != null and gm.has_method("open_debug_sandbox"):
			gm.call_deferred("open_debug_sandbox")

func _on_codex_pressed() -> void:
	if _is_codex_open():
		_close_codex()
		return
	_close_settings()
	codex_panel = V2CodexPanel.new()
	codex_panel.closed.connect(_close_codex)
	settings_layer.add_child(codex_panel)
	var v2: V2CombatController = null
	var tree := get_tree()
	if tree != null:
		var p := tree.get_first_node_in_group("player")
		if p != null and "v2_combat" in p:
			v2 = p.v2_combat as V2CombatController
	codex_panel.setup(v2)

func _close_codex() -> void:
	if _is_codex_open():
		codex_panel.queue_free()
	codex_panel = null

func _on_settings_pressed() -> void:
	if _is_settings_open():
		_close_settings()
		return
	_close_codex()
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
	_close_codex()
	ObjectPools.clear()
	GameFlow.restart_run()

func _on_title_pressed() -> void:
	_close_settings()
	_close_codex()
	ObjectPools.clear()
	GameFlow.to_title()
