extends VBoxContainer
class_name SettingsPanel
# 设置面板：标题界面与暂停菜单共用。控件由代码构建，
# 这样组件自包含，不依赖场景文件的节点路径，便于测试与复用。

signal closed

const SLIDER_KEYS := [
	{ "key": "audio/master_volume_db", "label": "主音量" },
	{ "key": "audio/music_volume_db", "label": "音乐" },
	{ "key": "audio/sfx_volume_db", "label": "音效" },
]
const TOGGLE_KEYS := [
	{ "key": "video/screen_shake", "label": "屏幕震动（光敏者可关闭）" },
	{ "key": "video/hit_flash", "label": "受击闪白（光敏者可关闭）" },
	{ "key": "ui/hint_enabled", "label": "显示操作提示" },
]

var _sliders: Dictionary = {}
var _toggles: Dictionary = {}
var _value_labels: Dictionary = {}
var _syncing: bool = false

func _ready() -> void:
	_build()
	_sync_from_settings()

func _build() -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size = Vector2(420, 0)

	var heading = Label.new()
	heading.text = "设置"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	add_child(heading)
	add_child(HSeparator.new())

	# 音量滑条：拖动实时预览，松手才落盘
	for item in SLIDER_KEYS:
		add_child(_build_slider_row(item["key"], item["label"]))

	add_child(HSeparator.new())

	# 无障碍与显示开关
	for item in TOGGLE_KEYS:
		add_child(_build_toggle_row(item["key"], item["label"]))

	add_child(HSeparator.new())

	var reset_btn = Button.new()
	reset_btn.text = "恢复默认设置"
	reset_btn.custom_minimum_size = Vector2(0, 40)
	reset_btn.pressed.connect(_on_reset_pressed)
	add_child(reset_btn)

	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(0, 46)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

func _build_slider_row(key: String, label_text: String) -> Node:
	var row = VBoxContainer.new()
	var head = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val = Label.new()
	val.custom_minimum_size = Vector2(56, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(lbl)
	head.add_child(val)
	row.add_child(head)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 拖动中：仅生效不落盘，避免每帧写磁盘
	slider.value_changed.connect(func(v: float): _on_slider_dragged(key, v))
	slider.drag_ended.connect(func(_changed: bool): _on_slider_released(key))
	row.add_child(slider)

	_sliders[key] = slider
	_value_labels[key] = val
	return row

func _build_toggle_row(key: String, label_text: String) -> Node:
	var btn = CheckButton.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.toggled.connect(func(on: bool): _on_toggle_changed(key, on))
	_toggles[key] = btn
	return btn

func _on_slider_dragged(key: String, linear: float) -> void:
	if _syncing:
		return
	Settings.stage_value(key, Settings.linear_to_db(linear))
	_value_labels[key].text = "%d%%" % int(roundf(linear * 100.0))

func _on_slider_released(key: String) -> void:
	if _syncing:
		return
	var linear = _sliders[key].value
	Settings.set_value(key, Settings.linear_to_db(linear))
	# 松手时播一个音效，让玩家确认音量已保存
	if key == "audio/sfx_volume_db" or key == "audio/master_volume_db":
		Sfx.play("sword_hit", -6.0)

func _on_toggle_changed(key: String, on: bool) -> void:
	if _syncing:
		return
	Settings.set_value(key, on)

func _on_reset_pressed() -> void:
	Settings.reset_to_defaults()
	_sync_from_settings()

func _on_back_pressed() -> void:
	emit_signal("closed")

func _sync_from_settings() -> void:
	_syncing = true
	for key in _sliders.keys():
		var linear = Settings.db_to_linear(Settings.get_float(key))
		_sliders[key].value = linear
		_value_labels[key].text = "%d%%" % int(roundf(linear * 100.0))
	for key in _toggles.keys():
		_toggles[key].button_pressed = Settings.get_bool(key)
	_syncing = false
