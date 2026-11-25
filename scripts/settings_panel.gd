extends Control
class_name SettingsPanel
# 设置面板：标题界面与暂停菜单共用。控件由代码构建，组件自包含。
#
# 必须自带遮罩与不透明底板：本面板会叠加在标题文字或战斗画面之上，
# 若只用裸容器，下层内容会透上来与面板文字混在一起，读不清。
# 同时自身要拦截鼠标，否则点击会穿透到下层的按钮。
#
# 布局层级：Dim（全屏压暗）→ Margin（边距上限）→ Center → Panel（不透明底板）
#            → Scroll（超出时可滚动）→ Content（实际控件）
# 字号放大后面板已接近 720p 视口高度，窗口更小时靠滚动容纳，不裁切内容。

signal closed

const PANEL_MARGIN := 24.0
# 底板 StyleBox 的单侧内边距，计算可用空间时需要扣除
const STYLE_CONTENT_MARGIN := 32.0

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

var _content: VBoxContainer = null
var _margin: MarginContainer = null
var _scroll: ScrollContainer = null
var _sliders: Dictionary = {}
var _toggles: Dictionary = {}
var _value_labels: Dictionary = {}
var _syncing: bool = false

func _ready() -> void:
	# 铺满父容器并拦截鼠标：点击不会穿透到下层按钮
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_sync_from_settings()
	# 窗口可缩放，尺寸变化时重新计算高度上限
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_viewport_limits()

func _build() -> void:
	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.14, 0.12, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 边距容器：限定面板最大高度为视口减去上下边距
	_margin = MarginContainer.new()
	_margin.name = "Margin"
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)

	# 不透明底板：深色底 + 青色描边，与游戏 UI 风格一致
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	XianxiaUITheme.attach_ornaments(panel, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	center.add_child(panel)

	# 滚动容器：窗口不足以显示全部设置时，内容可滚动而不被裁切
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 14)
	_content.custom_minimum_size = Vector2(520, 0)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var heading = Label.new()
	heading.text = "设置"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.10, 0.28, 0.24))
	var title_font = load("res://assets/title_font.tres")
	if title_font != null:
		heading.add_theme_font_override("font", title_font)
	_content.add_child(heading)
	_content.add_child(HSeparator.new())

	# 音量滑条：拖动实时预览，松手才落盘
	for item in SLIDER_KEYS:
		_content.add_child(_build_slider_row(item["key"], item["label"]))

	_content.add_child(HSeparator.new())

	# 无障碍与显示开关
	for item in TOGGLE_KEYS:
		_content.add_child(_build_toggle_row(item["key"], item["label"]))

	_content.add_child(HSeparator.new())

	var reset_btn = Button.new()
	reset_btn.text = "恢复默认设置"
	reset_btn.custom_minimum_size = Vector2(0, 50)
	reset_btn.add_theme_font_size_override("font_size", 24)
	_style_button(reset_btn, false)
	reset_btn.pressed.connect(_on_reset_pressed)
	_content.add_child(reset_btn)

	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(0, 56)
	back_btn.add_theme_font_size_override("font_size", 26)
	_style_button(back_btn, true)
	back_btn.pressed.connect(_on_back_pressed)
	_content.add_child(back_btn)
	# 键盘/手柄用户打开面板后直接能操作
	back_btn.grab_focus()

func _style_button(btn: Button, primary: bool) -> void:
	XianxiaUITheme.style_button(btn, "primary" if primary else "secondary")

func _make_panel_style() -> StyleBoxFlat:
	return XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, int(STYLE_CONTENT_MARGIN))

func _build_slider_row(key: String, label_text: String) -> Node:
	var row = VBoxContainer.new()
	var head = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.26, 0.22))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val = Label.new()
	val.add_theme_font_size_override("font_size", 24)
	val.add_theme_color_override("font_color", Color(0.16, 0.46, 0.38))
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(lbl)
	head.add_child(val)
	row.add_child(head)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 拖动中只生效不落盘，避免每帧写磁盘
	slider.value_changed.connect(func(v: float): _on_slider_dragged(key, v))
	slider.drag_ended.connect(func(_changed: bool): _on_slider_released(key))
	row.add_child(slider)

	_sliders[key] = slider
	_value_labels[key] = val
	return row

func _build_toggle_row(key: String, label_text: String) -> Node:
	var btn = CheckButton.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.12, 0.26, 0.22))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.20, 0.16))
	btn.add_theme_color_override("font_pressed_color", Color(0.10, 0.34, 0.28))
	btn.custom_minimum_size = Vector2(0, 42)
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
	# 松手播一个音效，让玩家确认音量已保存
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

# 面板尺寸 = 视口 - 边距，且不大于内容需要的高度。
# 必要性：CenterContainer 会把子节点压到其最小尺寸，而 ScrollContainer 的最小尺寸是 0，
# 不显式给定尺寸的话底板会塌缩成只剩内边距厚度，内容被整体挤出可视区。
func _apply_viewport_limits() -> void:
	if _margin == null or _scroll == null or _content == null:
		return
	var vp = get_viewport().get_visible_rect().size
	for side in ["margin_top", "margin_bottom", "margin_left", "margin_right"]:
		_margin.add_theme_constant_override(side, int(PANEL_MARGIN))

	var inset = 2.0 * STYLE_CONTENT_MARGIN
	# 可用空间：视口减去外边距与底板内边距
	var avail_w = vp.x - 2.0 * PANEL_MARGIN - inset
	var avail_h = vp.y - 2.0 * PANEL_MARGIN - inset
	var need = _content.get_combined_minimum_size()
	# 取"内容所需"与"可用空间"的较小值：窗口够大就按内容收缩，窗口小则填满并可滚动
	_scroll.custom_minimum_size = Vector2(
		clampf(need.x, 160.0, maxf(160.0, avail_w)),
		clampf(need.y, 120.0, maxf(120.0, avail_h)),
	)

func _on_viewport_resized() -> void:
	_apply_viewport_limits()

func _sync_from_settings() -> void:
	_syncing = true
	for key in _sliders.keys():
		var linear = Settings.db_to_linear(Settings.get_float(key))
		_sliders[key].value = linear
		_value_labels[key].text = "%d%%" % int(roundf(linear * 100.0))
	for key in _toggles.keys():
		_toggles[key].button_pressed = Settings.get_bool(key)
	_syncing = false
