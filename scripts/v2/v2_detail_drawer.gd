class_name V2DetailDrawer
extends Control

signal closed
signal confirm_action_requested

const ELEM_CN := {
	"metal": "金",
	"wood": "木",
	"fire": "火",
	"thunder": "雷",
	"ice": "冰",
	"venom": "毒",
	"water": "水",
	"none": "器道",
}

const ELEM_HEX := {
	"metal": "#D97706",
	"wood": "#16A34A",
	"fire": "#EA580C",
	"thunder": "#6366F1",
	"ice": "#0284C7",
	"venom": "#059669",
	"water": "#0891B2",
	"none": "#64748B",
}

const STAT_FIELD_SPECS := [
	["damage", "伤害", "", false, false],
	["cooldown", "冷却", "s", true, false],
	["range", "射程", "", false, false],
	["aoe_radius", "范围", "", false, false],
	["pierce", "穿透", "", false, false],
	["projectile_count", "弹道数", "", false, false],
	["chain_count", "弹射目标", "", false, false],
	["chain_range", "弹射半径", "", false, false],
	["tick_dps", "火域秒伤", "/s", false, false],
	["dot_dps", "剧毒秒伤", "/s", false, false],
	["zone_duration", "火域持续", "s", false, false],
	["dot_dur", "毒伤持续", "s", false, false],
	["slow_pct", "减速", "%", false, true],
	["root_dur", "定身", "s", false, false],
	["knockback", "击退", "", false, false],
	["clear_enemy_bullets", "清弹幕", "bool", false, false],
]

const MOD_SPECS := {
	"damage_pct": ["全伤害", "pct", false],
	"attack_speed_pct": ["攻速", "pct", false],
	"area_pct": ["法宝范围", "pct", false],
	"crit_chance": ["暴击率", "pct", false],
	"crit_mult_bonus": ["暴击伤害", "pct", false],
	"mastery_pct": ["元素精通", "pct", false],
	"reaction_damage_pct": ["反应伤害", "pct", false],
	"reaction_radius_pct": ["反应范围", "pct", false],
	"reaction_icd_reduction": ["反应内置冷却", "neg_sec", false],
	"dot_damage_pct": ["灼烧与毒伤", "pct", false],
	"fire_aura_dur_bonus": ["火附着延长", "sec", false],
	"shatter_mult_bonus": ["碎冰穿刺倍率", "pct", false],
	"chain_bonus": ["雷系弹射", "int", false],
	"pierce_flat": ["穿透", "int", false],
	"max_hp": ["最大气血", "int", false],
	"dodge_pct": ["闪避率", "pct", false],
	"move_speed_pct": ["移速", "pct", false],
	"pickup_radius_pct": ["拾取范围", "pct", false],
	"dash_cooldown_pct": ["踏云步冷却", "pct_low_good", false],
	"hp_regen": ["每秒回血", "float_sec", false],
	"lifesteal_pct": ["攻击吸血", "pct", false],
	"gold_gain_pct": ["灵石掉落", "pct", false],
	"enemy_spawn_pct": ["刷怪密度", "pct", true],
	"curse_pct": ["劫难", "pct", true],
	"luck": ["机缘", "pct", false],
}

const TRIGGER_LABELS := {
	"every_25_orbs_clear_bullets": "每拾取 25 颗灵珠释放半径 260px 清弹气浪",
}

const ELEM_COLOR := {
	"metal": Color(0.84, 0.56, 0.14),
	"wood": Color(0.14, 0.68, 0.34),
	"fire": Color(0.86, 0.34, 0.14),
	"thunder": Color(0.42, 0.38, 0.86),
	"ice": Color(0.10, 0.54, 0.78),
	"venom": Color(0.12, 0.60, 0.40),
	"water": Color(0.05, 0.62, 0.74),
	"none": Color(0.36, 0.48, 0.46),
}

const COL_HEADER_BG := Color(0.07, 0.19, 0.17, 1.0)
const COL_GOLD := Color(0.86, 0.70, 0.32, 1.0)
const COL_PAPER := Color(0.98, 0.96, 0.91, 0.99)
const COL_SIDEBAR := Color(0.93, 0.91, 0.85, 1.0)
const COL_INK := Color(0.09, 0.21, 0.18, 1.0)
const COL_INK_SUB := Color(0.32, 0.42, 0.38, 1.0)
const COL_JADE := Color(0.10, 0.50, 0.36, 1.0)
const COL_CINNABAR := Color(0.76, 0.24, 0.14, 1.0)

var is_open: bool = false
var current_detail: Dictionary = {}

var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _icon_box: PanelContainer = null
var _icon_rect: TextureRect = null
var _title_lbl: Label = null
var _badge_row: HBoxContainer = null
var _confirm_btn: Button = null
var _close_btn: Button = null
var _left_vb: VBoxContainer = null
var _right_vb: VBoxContainer = null
var _open_tween: Tween = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.06, 0.05, 0.62)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_detail()
	)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_set_panel_size(860.0, 356.0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = COL_PAPER
	pst.border_color = Color(0.12, 0.36, 0.31, 0.98)
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(12)
	pst.shadow_color = Color(0.02, 0.07, 0.06, 0.48)
	pst.shadow_size = 24
	pst.shadow_offset = Vector2(0, 8)
	pst.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", pst)
	add_child(_panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 0)
	_panel.add_child(root_vb)

	var header_bar := PanelContainer.new()
	var hst := StyleBoxFlat.new()
	hst.bg_color = COL_HEADER_BG
	hst.border_color = COL_GOLD
	hst.border_width_bottom = 2
	hst.corner_radius_top_left = 10
	hst.corner_radius_top_right = 10
	hst.content_margin_left = 18
	hst.content_margin_right = 18
	hst.content_margin_top = 13
	hst.content_margin_bottom = 13
	header_bar.add_theme_stylebox_override("panel", hst)
	root_vb.add_child(header_bar)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header_bar.add_child(header)

	_icon_box = PanelContainer.new()
	_icon_box.custom_minimum_size = Vector2(54, 54)
	_apply_icon_frame(Color(0.24, 0.64, 0.54))
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(42, 42)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_box.add_child(_icon_rect)
	header.add_child(_icon_box)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vb.add_theme_constant_override("separation", 5)
	header.add_child(title_vb)

	_title_lbl = Label.new()
	var title_font = load("res://assets/title_font.tres")
	if title_font != null:
		_title_lbl.add_theme_font_override("font", title_font)
	_title_lbl.add_theme_font_size_override("font_size", 26)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	title_vb.add_child(_title_lbl)

	_badge_row = HBoxContainer.new()
	_badge_row.add_theme_constant_override("separation", 6)
	title_vb.add_child(_badge_row)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 8)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(btn_box)

	_confirm_btn = _make_btn("选定此项", Color(0.12, 0.48, 0.37), COL_GOLD, Color(1.0, 0.97, 0.88))
	_confirm_btn.custom_minimum_size = Vector2(128, 38)
	_confirm_btn.pressed.connect(func():
		confirm_action_requested.emit()
	)
	btn_box.add_child(_confirm_btn)

	_close_btn = _make_btn("收起 [ESC]", Color(0.14, 0.27, 0.25), Color(0.42, 0.56, 0.52), Color(0.88, 0.93, 0.90))
	_close_btn.custom_minimum_size = Vector2(104, 38)
	_close_btn.pressed.connect(close_detail)
	btn_box.add_child(_close_btn)

	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 18)
	body_margin.add_theme_constant_override("margin_right", 18)
	body_margin.add_theme_constant_override("margin_top", 14)
	body_margin.add_theme_constant_override("margin_bottom", 16)
	root_vb.add_child(body_margin)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	body_margin.add_child(cols)

	_left_vb = _make_scroll_column(cols, 1.18, false)
	_right_vb = _make_scroll_column(cols, 0.92, true)

func _set_panel_size(w: float, h: float) -> void:
	if _panel == null:
		return
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	_panel.offset_top = -h * 0.5
	_panel.offset_bottom = h * 0.5
	_panel.pivot_offset = Vector2(w * 0.5, h * 0.5)

func _apply_icon_frame(accent: Color) -> void:
	if _icon_box == null:
		return
	var ist := StyleBoxFlat.new()
	ist.bg_color = Color(0.05, 0.13, 0.12, 0.96)
	ist.border_color = accent
	ist.set_border_width_all(2)
	ist.set_corner_radius_all(10)
	ist.set_content_margin_all(5)
	_icon_box.add_theme_stylebox_override("panel", ist)

func _make_scroll_column(parent_row: HBoxContainer, ratio: float, is_sidebar: bool) -> VBoxContainer:
	var host: Control = parent_row
	if is_sidebar:
		var side_panel := PanelContainer.new()
		side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_panel.size_flags_stretch_ratio = ratio
		var sst := StyleBoxFlat.new()
		sst.bg_color = COL_SIDEBAR
		sst.border_color = Color(0.76, 0.80, 0.75, 0.80)
		sst.set_border_width_all(1)
		sst.set_corner_radius_all(10)
		sst.content_margin_left = 14
		sst.content_margin_right = 14
		sst.content_margin_top = 12
		sst.content_margin_bottom = 12
		side_panel.add_theme_stylebox_override("panel", sst)
		parent_row.add_child(side_panel)
		host = side_panel

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not is_sidebar:
		sc.size_flags_stretch_ratio = ratio
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	XianxiaUITheme.style_scroll_container(sc)
	host.add_child(sc)

	return XianxiaUITheme.make_scroll_body(sc, 12, 6 if is_sidebar else 10, 2)

func _make_btn(text: String, bg: Color, border: Color, font_col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 15)
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 12
	st.content_margin_right = 12
	b.add_theme_stylebox_override("normal", st)

	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.12)
	hv.border_color = border.lightened(0.15)
	b.add_theme_stylebox_override("hover", hv)

	var pr := st.duplicate() as StyleBoxFlat
	pr.bg_color = bg.darkened(0.12)
	b.add_theme_stylebox_override("pressed", pr)

	var dis := st.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.22, 0.27, 0.26, 0.65)
	dis.border_color = Color(0.40, 0.45, 0.43, 0.55)
	b.add_theme_stylebox_override("disabled", dis)

	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.94))
	b.add_theme_color_override("font_disabled_color", Color(0.68, 0.72, 0.70, 0.75))
	return b

func _make_pill(text: String, bg: Color, border: Color, fg: Color, font_size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", fg)
	p.add_child(lbl)
	return p

func _resolve_accent(detail: Dictionary) -> Color:
	var kind := String(detail.get("kind", "stat"))
	if kind == "weapon":
		var el := String(detail.get("element", "metal"))
		return ELEM_COLOR.get(el, Color(0.24, 0.64, 0.54))
	if kind == "item":
		var rarity := int(detail.get("rarity", 1))
		if rarity >= 3:
			return Color(0.72, 0.36, 0.78)
		if rarity == 2:
			return Color(0.24, 0.56, 0.84)
		return COL_GOLD
	return Color(0.24, 0.66, 0.54)

func open_detail(detail: Dictionary, action_label: String = "", action_enabled: bool = true) -> void:
	if detail.is_empty():
		return
	current_detail = detail
	is_open = true
	visible = true

	var kind := String(detail.get("kind", "stat"))
	if kind == "weapon":
		_set_panel_size(900.0, 496.0)
	elif kind == "item":
		_set_panel_size(860.0, 368.0)
	else:
		_set_panel_size(860.0, 416.0)

	var accent := _resolve_accent(detail)
	_apply_icon_frame(accent)

	var icon_path := String(detail.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon_rect.texture = load(icon_path)
	else:
		_icon_rect.texture = null

	_title_lbl.text = String(detail.get("title", ""))
	_render_header_badges(detail, accent)

	if action_label != "":
		_confirm_btn.visible = true
		_confirm_btn.text = action_label
		_confirm_btn.disabled = not action_enabled
	else:
		_confirm_btn.visible = false

	_render_columns(detail)
	_play_open_anim()

func _play_open_anim() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if not is_inside_tree():
		return
	_backdrop.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.set_parallel(true)
	_open_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _render_header_badges(detail: Dictionary, accent: Color) -> void:
	_clear_box(_badge_row)
	var kind := String(detail.get("kind", "stat"))
	if kind == "weapon":
		var elem_cn := String(detail.get("element_cn", ""))
		var cur_lv := int(detail.get("cur_lv", 0))
		var next_lv := int(detail.get("next_lv", 1))
		_badge_row.add_child(_make_pill("%s系法宝" % elem_cn, Color(accent.r, accent.g, accent.b, 0.28), accent, Color(1.0, 0.97, 0.90), 12))
		var lv_txt := "新祭炼 · 预览 Lv.%d" % next_lv if cur_lv <= 0 else ("Lv.%d → Lv.%d" % [cur_lv, next_lv] if cur_lv < next_lv else "已圆满 Lv.%d" % cur_lv)
		_badge_row.add_child(_make_pill(lv_txt, Color(1.0, 1.0, 1.0, 0.10), Color(0.75, 0.85, 0.80, 0.35), Color(0.88, 0.95, 0.91), 12))
	elif kind == "item":
		var rarity := int(detail.get("rarity", 1))
		var r_label := "凡品奇物" if rarity <= 1 else ("稀有奇物" if rarity == 2 else "绝品奇物")
		_badge_row.add_child(_make_pill(r_label, Color(accent.r, accent.g, accent.b, 0.28), accent, Color(1.0, 0.97, 0.90), 12))
		if bool(detail.get("has_tradeoff", false)):
			_badge_row.add_child(_make_pill("高收益 · 权衡", Color(0.76, 0.24, 0.14, 0.28), Color(0.95, 0.52, 0.38), Color(1.0, 0.88, 0.82), 12))
		var owned_cnt := int(detail.get("owned_count", 0))
		_badge_row.add_child(_make_pill("已持有 %d 件" % owned_cnt, Color(1.0, 1.0, 1.0, 0.10), Color(0.75, 0.85, 0.80, 0.35), Color(0.88, 0.95, 0.91), 12))
	else:
		var clean_tag := String(detail.get("subtitle", "境界突破")).replace("【", "").replace("】", "")
		_badge_row.add_child(_make_pill(clean_tag, Color(accent.r, accent.g, accent.b, 0.28), accent, Color(1.0, 0.97, 0.90), 12))
		_badge_row.add_child(_make_pill("境界突破增益", Color(1.0, 1.0, 1.0, 0.10), Color(0.75, 0.85, 0.80, 0.35), Color(0.88, 0.95, 0.91), 12))

func close_detail() -> void:
	if not is_open and not visible:
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	visible = false
	is_open = false
	current_detail = {}
	closed.emit()

func _clear_box(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _render_columns(detail: Dictionary) -> void:
	_clear_box(_left_vb)
	_clear_box(_right_vb)
	var kind := String(detail.get("kind", "stat"))
	if kind == "weapon":
		_render_weapon_left(detail)
		_render_weapon_right(detail)
	elif kind == "item":
		_render_item_left(detail)
		_render_synergy_right(detail)
	else:
		_render_stat_left(detail)
		_render_synergy_right(detail)

func _add_section(parent: VBoxContainer, heading: String, meta_pill_text: String = "", meta_accent: Color = COL_JADE) -> VBoxContainer:
	var sec := VBoxContainer.new()
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec.add_theme_constant_override("separation", 8)
	parent.add_child(sec)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	head_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sec.add_child(head_row)

	var h := Label.new()
	h.text = heading
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", Color(0.09, 0.30, 0.25))
	head_row.add_child(h)

	if meta_pill_text != "":
		head_row.add_child(_make_pill(meta_pill_text, Color(meta_accent.r, meta_accent.g, meta_accent.b, 0.14), Color(meta_accent.r, meta_accent.g, meta_accent.b, 0.50), meta_accent.darkened(0.15), 11))

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.16, 0.44, 0.37, 0.24)
	sec.add_child(rule)
	return sec

func _render_weapon_left(detail: Dictionary) -> void:
	var cur_lv := int(detail.get("cur_lv", 0))
	var next_lv := int(detail.get("next_lv", 1))
	var diff_title := "初阶面板" if cur_lv <= 0 else ("圆满面板" if cur_lv == next_lv else "淬炼数值变化")
	var diff_meta := "Lv.%d" % next_lv if (cur_lv <= 0 or cur_lv == next_lv) else "Lv.%d → Lv.%d" % [cur_lv, next_lv]
	var diff_box := _add_section(_left_vb, diff_title, diff_meta, COL_JADE)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 10)
	stat_grid.add_theme_constant_override("v_separation", 8)
	diff_box.add_child(stat_grid)

	for row in detail.get("stat_diffs", []):
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cst := StyleBoxFlat.new()
		cst.bg_color = Color(0.95, 0.93, 0.87, 1.0)
		cst.border_color = Color(0.80, 0.82, 0.76, 0.85)
		cst.set_border_width_all(1)
		cst.set_corner_radius_all(7)
		cst.content_margin_left = 10
		cst.content_margin_right = 10
		cst.content_margin_top = 6
		cst.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel", cst)
		stat_grid.add_child(chip)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		chip.add_child(hb)

		var lbl := Label.new()
		lbl.text = String(row.get("label", ""))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", COL_INK_SUB)
		hb.add_child(lbl)

		var val_lbl := Label.new()
		var delta_t := String(row.get("delta_text", ""))
		if cur_lv <= 0 or cur_lv == next_lv:
			val_lbl.text = String(row.get("next_text", ""))
			val_lbl.add_theme_color_override("font_color", COL_INK)
		else:
			val_lbl.text = "%s → %s" % [String(row.get("cur_text", "")), String(row.get("next_text", ""))]
			val_lbl.add_theme_color_override("font_color", COL_JADE if bool(row.get("is_positive", true)) else COL_INK)
		val_lbl.add_theme_font_size_override("font_size", 13)
		hb.add_child(val_lbl)

		if delta_t != "" and cur_lv > 0 and cur_lv != next_lv:
			var is_pos := bool(row.get("is_positive", true))
			var dcol := COL_JADE if is_pos else COL_CINNABAR
			hb.add_child(_make_pill(delta_t, Color(dcol.r, dcol.g, dcol.b, 0.14), Color(dcol.r, dcol.g, dcol.b, 0.45), dcol, 11))

	var road_box := _add_section(_left_vb, "淬炼阶梯", "Lv.1 → Lv.%d" % OrbitWeaponRig.MAX_WEAPON_TIER, COL_GOLD)
	var roadmap: Array = detail.get("tier_roadmap", [])
	var pip_bar := HBoxContainer.new()
	pip_bar.add_theme_constant_override("separation", 6)
	road_box.add_child(pip_bar)
	for step in roadmap:
		var state := String(step.get("state", "future"))
		var seg := ColorRect.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0, 6)
		if state == "reached" or state == "current":
			seg.color = COL_JADE
		elif state == "next":
			seg.color = Color(0.86, 0.44, 0.16)
		else:
			seg.color = Color(0.80, 0.82, 0.77, 0.85)
		pip_bar.add_child(seg)

	for step in roadmap:
		var state := String(step.get("state", "future"))
		var tier_num := int(step.get("tier", 1))
		var row_hb := HBoxContainer.new()
		row_hb.add_theme_constant_override("separation", 8)
		road_box.add_child(row_hb)

		var badge_bg := Color(0.86, 0.86, 0.82, 0.75)
		var badge_bd := Color(0.72, 0.74, 0.70, 0.75)
		var badge_fg := COL_INK_SUB
		var text_col := Color(0.42, 0.48, 0.45)
		if state == "next":
			badge_bg = Color(0.98, 0.90, 0.82, 1.0)
			badge_bd = Color(0.86, 0.44, 0.16, 0.90)
			badge_fg = COL_CINNABAR
			text_col = COL_CINNABAR
		elif state == "current" or state == "reached":
			badge_bg = Color(0.86, 0.95, 0.90, 1.0)
			badge_bd = Color(0.16, 0.58, 0.42, 0.85)
			badge_fg = COL_JADE
			text_col = COL_INK

		row_hb.add_child(_make_pill("Lv.%d" % tier_num, badge_bg, badge_bd, badge_fg, 11))
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = String(step.get("summary", ""))
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", text_col)
		row_hb.add_child(lbl)

func _render_weapon_right(detail: Dictionary) -> void:
	var syn: Dictionary = detail.get("synergy_summary", {})
	var syn_badge := "已持 %d → 选用后 %d 组" % [int(syn.get("active_reaction_count", 0)), int(syn.get("projected_reaction_count", 0))]
	var rx_box := _add_section(_right_vb, "五行反应联动", syn_badge, COL_JADE)
	var new_rx: Array = syn.get("new_reactions", [])
	if not new_rx.is_empty():
		var banner := PanelContainer.new()
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.85, 0.95, 0.89, 1.0)
		bst.border_color = Color(0.14, 0.58, 0.38, 0.85)
		bst.set_border_width_all(1)
		bst.set_corner_radius_all(6)
		bst.content_margin_left = 10
		bst.content_margin_right = 10
		bst.content_margin_top = 5
		bst.content_margin_bottom = 5
		banner.add_theme_stylebox_override("panel", bst)
		var tip := Label.new()
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.text = "获取后立刻激活：%s" % "、".join(new_rx)
		tip.add_theme_font_size_override("font_size", 12)
		tip.add_theme_color_override("font_color", Color(0.06, 0.38, 0.24))
		banner.add_child(tip)
		rx_box.add_child(banner)

	var self_elem := String(detail.get("element", "metal"))
	var self_cn := String(detail.get("element_cn", ""))
	for rx in detail.get("reactions", []):
		var active := bool(rx.get("can_activate_now", false))
		var other_el := String(rx.get("other_element", "fire"))
		var other_cn := String(rx.get("other_elem_name", ""))
		rx_box.add_child(_build_reaction_row(self_elem, self_cn, other_el, other_cn, String(rx.get("name", "")), String(rx.get("effect_text", "")), active, "已就绪" if active else ("缺 %s" % other_cn)))

func _build_reaction_row(elem_a: String, cn_a: String, elem_b: String, cn_b: String, rx_name: String, effect_text: String, active: bool, status_text: String) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var rst := StyleBoxFlat.new()
	rst.bg_color = Color(0.98, 0.99, 0.96, 1.0) if active else Color(0.95, 0.94, 0.90, 0.65)
	rst.border_color = Color(0.14, 0.58, 0.38, 0.82) if active else Color(0.76, 0.78, 0.74, 0.65)
	rst.set_border_width_all(1)
	rst.set_corner_radius_all(7)
	rst.content_margin_left = 9
	rst.content_margin_right = 9
	rst.content_margin_top = 6
	rst.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", rst)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	row_panel.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	vb.add_child(top)

	var ca: Color = ELEM_COLOR.get(elem_a, COL_JADE)
	var cb: Color = ELEM_COLOR.get(elem_b, COL_GOLD)
	top.add_child(_make_pill(cn_a, Color(ca.r, ca.g, ca.b, 0.18), Color(ca.r, ca.g, ca.b, 0.55), ca.darkened(0.20), 11))
	var plus_lbl := Label.new()
	plus_lbl.text = "+"
	plus_lbl.add_theme_font_size_override("font_size", 11)
	plus_lbl.add_theme_color_override("font_color", COL_INK_SUB)
	top.add_child(plus_lbl)
	top.add_child(_make_pill(cn_b, Color(cb.r, cb.g, cb.b, 0.18), Color(cb.r, cb.g, cb.b, 0.55), cb.darkened(0.20), 11))

	var name_lbl := Label.new()
	name_lbl.text = rx_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", COL_INK if active else COL_INK_SUB)
	top.add_child(name_lbl)

	if status_text != "":
		var scol := COL_JADE if active else COL_INK_SUB
		top.add_child(_make_pill(status_text, Color(scol.r, scol.g, scol.b, 0.14), Color(scol.r, scol.g, scol.b, 0.42), scol, 11))

	var eff := Label.new()
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.text = effect_text
	eff.add_theme_font_size_override("font_size", 12)
	eff.add_theme_color_override("font_color", Color(0.18, 0.34, 0.28) if active else Color(0.45, 0.49, 0.47))
	vb.add_child(eff)
	return row_panel

func _render_item_left(detail: Dictionary) -> void:
	var mod_box := _add_section(_left_vb, "词条收益与代偿")
	var rows: Array = detail.get("mod_rows", [])
	if rows.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = String(detail.get("desc", ""))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", COL_INK)
		mod_box.add_child(empty_lbl)
	else:
		var pos_rows: Array = []
		var neg_rows: Array = []
		for r in rows:
			if bool(r.get("is_negative", false)):
				neg_rows.append(r)
			else:
				pos_rows.append(r)
		for r in pos_rows + neg_rows:
			var is_neg := bool(r.get("is_negative", false))
			var col := COL_CINNABAR if is_neg else COL_JADE
			var row_p := PanelContainer.new()
			var rst := StyleBoxFlat.new()
			rst.bg_color = Color(col.r, col.g, col.b, 0.08)
			rst.border_color = Color(col.r, col.g, col.b, 0.28)
			rst.set_border_width_all(1)
			rst.set_corner_radius_all(7)
			rst.content_margin_left = 10
			rst.content_margin_right = 12
			rst.content_margin_top = 6
			rst.content_margin_bottom = 6
			row_p.add_theme_stylebox_override("panel", rst)
			mod_box.add_child(row_p)

			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			row_p.add_child(hb)

			hb.add_child(_make_pill("代偿" if is_neg else "增益", Color(col.r, col.g, col.b, 0.16), Color(col.r, col.g, col.b, 0.45), col, 11))
			var k_lbl := Label.new()
			k_lbl.text = String(r.get("label", ""))
			k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			k_lbl.add_theme_font_size_override("font_size", 14)
			k_lbl.add_theme_color_override("font_color", COL_INK)
			hb.add_child(k_lbl)

			var v_lbl := Label.new()
			v_lbl.text = String(r.get("value_text", ""))
			v_lbl.add_theme_font_size_override("font_size", 15)
			v_lbl.add_theme_color_override("font_color", col)
			hb.add_child(v_lbl)

	var trig := String(detail.get("trigger_desc", ""))
	if trig != "":
		var mech_box := _add_section(_left_vb, "特殊机制", "主动 / 被动触发", COL_GOLD)
		var m_lbl := Label.new()
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_lbl.text = trig
		m_lbl.add_theme_font_size_override("font_size", 14)
		m_lbl.add_theme_color_override("font_color", COL_INK)
		mech_box.add_child(m_lbl)
	elif not rows.is_empty():
		var max_st := maxi(1, int(detail.get("max_stacks", 1)))
		var owned_st := int(detail.get("owned_count", 0))
		var cap_badge := "限持 1 件" if max_st == 1 else "限叠 %d 件 (%d/%d)" % [max_st, owned_st, max_st]
		var note_box := _add_section(_left_vb, "佩戴说明", cap_badge, COL_GOLD)
		var n_lbl := Label.new()
		n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if max_st == 1:
			n_lbl.text = "同款奇物限持 1 件，购入后立即作用于本局属性。"
		else:
			n_lbl.text = "同款奇物最多叠加 %d 件；若含代偿词条，请结合当前气血与容错权衡。" % max_st if bool(detail.get("has_tradeoff", false)) else "同款奇物最多叠加 %d 件，购入后立即作用于本局属性。" % max_st
		n_lbl.add_theme_font_size_override("font_size", 13)
		n_lbl.add_theme_color_override("font_color", COL_INK_SUB)
		note_box.add_child(n_lbl)

func _render_stat_left(detail: Dictionary) -> void:
	var info_box := _add_section(_left_vb, "突破效果")
	var d_lbl := Label.new()
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.text = String(detail.get("desc", ""))
	d_lbl.add_theme_font_size_override("font_size", 16)
	d_lbl.add_theme_color_override("font_color", COL_INK)
	info_box.add_child(d_lbl)

	var hint_txt := String(detail.get("hint", "")).strip_edges()
	if hint_txt != "":
		var hint_p := PanelContainer.new()
		var hst := StyleBoxFlat.new()
		hst.bg_color = Color(0.95, 0.91, 0.81, 0.96)
		hst.border_color = Color(0.84, 0.72, 0.42, 0.65)
		hst.set_border_width_all(1)
		hst.set_corner_radius_all(7)
		hst.content_margin_left = 10
		hst.content_margin_right = 10
		hst.content_margin_top = 6
		hst.content_margin_bottom = 6
		hint_p.add_theme_stylebox_override("panel", hst)
		var h_lbl := Label.new()
		h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_lbl.text = hint_txt
		h_lbl.add_theme_font_size_override("font_size", 13)
		h_lbl.add_theme_color_override("font_color", Color(0.54, 0.28, 0.10))
		hint_p.add_child(h_lbl)
		info_box.add_child(hint_p)

	var snap_box := _add_section(_left_vb, "当前战力快照")
	var sm: Dictionary = detail.get("stats_summary", {})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	snap_box.add_child(grid)

	var dmg_v := int(sm.get("dmg_pct", 0))
	var spd_v := int(sm.get("spd_pct", 0))
	var crit_v := int(sm.get("crit_pct", 12))
	var mst_v := int(sm.get("mastery_pct", 0))
	var ddg_v := int(sm.get("dodge_pct", 0))
	var lck_v := int(sm.get("luck_pct", 100))
	var cur_v := int(sm.get("curse_pct", 0))
	var bond_cnt: int = (detail.get("owned_bonds", []) as Array).size()

	var stat_items := [
		["全伤害", "%s%d%%" % ["+" if dmg_v >= 0 else "", dmg_v], dmg_v > 0],
		["攻速", "%s%d%%" % ["+" if spd_v >= 0 else "", spd_v], spd_v > 0],
		["暴击率", "%d%%" % crit_v, crit_v > 12],
		["元素精通", "%s%d%%" % ["+" if mst_v >= 0 else "", mst_v], mst_v > 0],
		["闪避率", "%d%%" % ddg_v, ddg_v > 0],
		["机缘", "%d%%" % lck_v, lck_v > 100],
		["劫难", "%d%%" % cur_v, false],
		["已持法宝", "%d 件" % bond_cnt, bond_cnt >= 2],
	]
	for si in stat_items:
		grid.add_child(_build_stat_chip(String(si[0]), String(si[1]), bool(si[2])))

func _build_stat_chip(label_text: String, value_text: String, highlighted: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.91, 0.96, 0.92, 1.0) if highlighted else Color(0.95, 0.93, 0.87, 0.95)
	st.border_color = Color(0.20, 0.58, 0.44, 0.55) if highlighted else Color(0.80, 0.81, 0.76, 0.80)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)

	var k := Label.new()
	k.text = label_text
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", COL_INK_SUB)
	vb.add_child(k)

	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 16)
	v.add_theme_color_override("font_color", COL_JADE if highlighted else COL_INK)
	vb.add_child(v)
	return p

func _render_synergy_right(detail: Dictionary) -> void:
	var active_list: Array = detail.get("active_reactions", [])
	var rx_box := _add_section(_right_vb, "已激活五行反应", "%d 组" % active_list.size(), COL_JADE if not active_list.is_empty() else COL_INK_SUB)
	if active_list.is_empty():
		var empty_p := PanelContainer.new()
		var est := StyleBoxFlat.new()
		est.bg_color = Color(0.97, 0.96, 0.92, 0.90)
		est.border_color = Color(0.76, 0.79, 0.74, 0.75)
		est.set_border_width_all(1)
		est.set_corner_radius_all(8)
		est.content_margin_left = 10
		est.content_margin_right = 10
		est.content_margin_top = 8
		est.content_margin_bottom = 8
		empty_p.add_theme_stylebox_override("panel", est)
		rx_box.add_child(empty_p)

		var evb := VBoxContainer.new()
		evb.add_theme_constant_override("separation", 6)
		empty_p.add_child(evb)

		var owned_els: Array = detail.get("owned_elements", [])
		if not owned_els.is_empty():
			var el_row := HBoxContainer.new()
			el_row.add_theme_constant_override("separation", 5)
			var pre := Label.new()
			pre.text = "当前元素："
			pre.add_theme_font_size_override("font_size", 12)
			pre.add_theme_color_override("font_color", COL_INK_SUB)
			el_row.add_child(pre)
			for el in owned_els:
				var ek := String(el)
				var ec: Color = ELEM_COLOR.get(ek, COL_JADE)
				el_row.add_child(_make_pill(String(ELEM_CN.get(ek, ek)), Color(ec.r, ec.g, ec.b, 0.18), Color(ec.r, ec.g, ec.b, 0.55), ec.darkened(0.20), 11))
			evb.add_child(el_row)

		var tip := Label.new()
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.text = "尚未凑齐双元素；破境开槽或在升级三选一中补入第 2 种元素法宝即可激活反应。"
		tip.add_theme_font_size_override("font_size", 12)
		tip.add_theme_color_override("font_color", COL_INK_SUB)
		evb.add_child(tip)
	else:
		for rx in active_list:
			rx_box.add_child(_build_reaction_row(
				String(rx.get("elem_a", "metal")),
				String(rx.get("elem_a_cn", "")),
				String(rx.get("elem_b", "fire")),
				String(rx.get("elem_b_cn", "")),
				String(rx.get("name", "")),
				String(rx.get("effect_text", "")),
				true,
				"生效中"
			))

	var bond_items: Array = detail.get("owned_bond_items", [])
	var bonds: Array = detail.get("owned_bonds", [])
	var bond_box := _add_section(_right_vb, "当前携带法宝", "%d 槽" % maxi(bond_items.size(), bonds.size()), COL_GOLD)
	if not bond_items.is_empty():
		for bi in bond_items:
			bond_box.add_child(_build_bond_row(bi))
	elif bonds.is_empty():
		var b_empty := Label.new()
		b_empty.text = "暂无法宝羁绊进度"
		b_empty.add_theme_font_size_override("font_size", 12)
		b_empty.add_theme_color_override("font_color", COL_INK_SUB)
		bond_box.add_child(b_empty)
	else:
		for b in bonds:
			var bl := Label.new()
			bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bl.text = String(b)
			bl.add_theme_font_size_override("font_size", 13)
			bl.add_theme_color_override("font_color", COL_INK)
			bond_box.add_child(bl)

func _build_bond_row(bi: Dictionary) -> PanelContainer:
	var is_f := bool(bi.get("is_fusion", false))
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.99, 0.94, 0.85, 1.0) if is_f else Color(0.98, 0.97, 0.93, 0.96)
	st.border_color = Color(0.86, 0.48, 0.18, 0.80) if is_f else Color(0.76, 0.80, 0.75, 0.80)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 7
	st.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(top)

	var el := String(bi.get("element", ""))
	if not is_f and el != "":
		var ec: Color = ELEM_COLOR.get(el, COL_JADE)
		top.add_child(_make_pill(String(ELEM_CN.get(el, el)), Color(ec.r, ec.g, ec.b, 0.18), Color(ec.r, ec.g, ec.b, 0.55), ec.darkened(0.20), 11))

	var name_lbl := Label.new()
	name_lbl.text = String(bi.get("name", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_CINNABAR if is_f else COL_INK)
	top.add_child(name_lbl)

	if is_f:
		top.add_child(_make_pill("满阶", Color(0.86, 0.36, 0.16, 0.18), Color(0.86, 0.36, 0.16, 0.65), COL_CINNABAR, 11))
	else:
		var lv := int(bi.get("level", 1))
		var max_t := OrbitWeaponRig.MAX_WEAPON_TIER
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		for k in range(max_t):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(7, 9)
			dot.color = COL_JADE if k < lv else Color(0.78, 0.80, 0.75, 0.85)
			pips.add_child(dot)
		top.add_child(pips)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv.%d/%d" % [lv, max_t]
		lv_lbl.add_theme_font_size_override("font_size", 12)
		lv_lbl.add_theme_color_override("font_color", COL_JADE if lv >= max_t else COL_INK_SUB)
		top.add_child(lv_lbl)

	return p

static func format_reaction_effect(rx: Dictionary) -> String:
	var parts: Array[String] = []
	var chains := int(rx.get("chain_count", 0))
	if chains > 0:
		parts.append("弹射%d怪" % chains)
	var stun_d := float(rx.get("stun_dur", 0.0))
	if stun_d > 0.0:
		parts.append("微麻痹%.2fs" % stun_d)
	var freeze_d := float(rx.get("freeze_dur", 0.0))
	if freeze_d > 0.0:
		parts.append("冰封%.1fs" % freeze_d)
	var exp_sh_pct := float(rx.get("expire_shatter_shield_max_pct", 0.0))
	if exp_sh_pct > 0.0:
		parts.append("破冰削%d%%白盾" % roundi(exp_sh_pct * 100.0))
	var sh_pct := float(rx.get("shield_max_pct", 0.0))
	if sh_pct > 0.0:
		parts.append("削%d%%白盾" % roundi(sh_pct * 100.0))
	if bool(rx.get("clear_enemy_bullets", false)):
		parts.append("清敌方弹幕")
	if bool(rx.get("interrupt_charge", false)):
		parts.append("打断蓄力")
	var kb := float(rx.get("knockback", 0.0))
	if kb > 0.0:
		parts.append("击退%d" % roundi(kb))
	var vuln_m := float(rx.get("vuln_mult", 1.0))
	if vuln_m > 1.0:
		parts.append("易伤+%d%%(%.1fs)" % [roundi((vuln_m - 1.0) * 100.0), float(rx.get("vuln_dur", 4.0))])
	var sh_mult := float(rx.get("shield_damage_mult", 1.0))
	if sh_mult > 1.0:
		parts.append("破盾%.1f×" % sh_mult)
	var mark_d := float(rx.get("mark_dur", 0.0))
	if mark_d > 0.0:
		parts.append("死亡爆%d%%血量" % roundi(float(rx.get("death_max_hp_pct", 0.22)) * 100.0))
	var mult := float(rx.get("damage_mult", 0.2))
	parts.append("附伤 %.2f×" % mult)
	return " · ".join(parts)

static func _format_stat_value(val: Variant, unit: String, is_pct: bool) -> String:
	if unit == "bool":
		return "可清弹" if bool(val) else "无"
	if is_pct:
		return "%d%%" % roundi(float(val) * 100.0)
	if unit == "s":
		return "%.2fs" % float(val)
	if unit == "/s":
		return "%d/s" % roundi(float(val))
	return str(roundi(float(val)))

static func build_weapon_detail(v2: V2CombatController, weapon_id: String, preview_next_lv: int = -1) -> Dictionary:
	if v2 == null or v2.loader == null or not v2.loader.weapons_by_id.has(weapon_id):
		return {}
	var w: Dictionary = v2.loader.weapons_by_id[weapon_id]
	var elem := String(w.get("element", "metal"))
	var elem_cn := String(ELEM_CN.get(elem, elem))
	var tiers: Array = w.get("tiers", [])
	var cur_lv := v2.orbit_rig.get_weapon_tier(weapon_id) if v2.orbit_rig != null else 0
	var next_lv := preview_next_lv if preview_next_lv >= 1 else mini(OrbitWeaponRig.MAX_WEAPON_TIER, cur_lv + 1)
	next_lv = clampi(next_lv, 1, maxi(1, tiers.size()))

	var cur_ts: Dictionary = tiers[clampi(cur_lv - 1, 0, tiers.size() - 1)] if cur_lv > 0 and not tiers.is_empty() else {}
	var next_ts: Dictionary = tiers[clampi(next_lv - 1, 0, tiers.size() - 1)] if not tiers.is_empty() else {}

	var stat_diffs: Array[Dictionary] = []
	for spec in STAT_FIELD_SPECS:
		var key := String(spec[0])
		if not next_ts.has(key) and not cur_ts.has(key):
			continue
		var label := String(spec[1])
		var unit := String(spec[2])
		var lower_better := bool(spec[3])
		var is_pct := bool(spec[4])
		var next_val: Variant = next_ts.get(key, cur_ts.get(key, 0))
		var next_txt := _format_stat_value(next_val, unit, is_pct)
		if cur_lv <= 0 or cur_lv == next_lv:
			stat_diffs.append({"label": label, "cur_text": next_txt, "next_text": next_txt, "delta_text": "", "is_positive": true})
			continue
		var cur_val: Variant = cur_ts.get(key, 0)
		var cur_txt := _format_stat_value(cur_val, unit, is_pct)
		if unit == "bool":
			if bool(cur_val) == bool(next_val):
				continue
			stat_diffs.append({"label": label, "cur_text": cur_txt, "next_text": next_txt, "delta_text": "解锁", "is_positive": true})
			continue
		var diff := float(next_val) - float(cur_val)
		if is_zero_approx(diff):
			continue
		var sign_str := "+" if diff > 0.0 else ""
		var d_txt := ""
		if is_pct:
			d_txt = "%s%d%%" % [sign_str, roundi(diff * 100.0)]
		elif unit == "s":
			d_txt = "%s%.2fs" % [sign_str, diff]
		elif unit == "/s":
			d_txt = "%s%d/s" % [sign_str, roundi(diff)]
		else:
			d_txt = "%s%d" % [sign_str, roundi(diff)]
		var pos := (diff < 0.0) if lower_better else (diff > 0.0)
		stat_diffs.append({"label": label, "cur_text": cur_txt, "next_text": next_txt, "delta_text": d_txt, "is_positive": pos})

	var tier_roadmap: Array[Dictionary] = []
	for t_raw in tiers:
		var t: Dictionary = t_raw
		var t_lv := int(t.get("tier", 1))
		var st_name := "future"
		if cur_lv > 0 and t_lv < cur_lv:
			st_name = "reached"
		elif cur_lv > 0 and t_lv == cur_lv:
			st_name = "current"
		elif t_lv == next_lv and next_lv > cur_lv:
			st_name = "next"
		tier_roadmap.append({
			"tier": t_lv,
			"summary": String(t.get("level_summary", "")),
			"perk": String(t.get("max_tier_perk", "")),
			"state": st_name,
		})

	var fusions: Array[Dictionary] = []

	var owned_elems := v2.get_owned_elements()
	var active_rx_list: Array[Dictionary] = []
	var inactive_rx_list: Array[Dictionary] = []
	if elem != "none" and not elem.is_empty():
		for rx in v2.loader.reactions_list:
			var trig_list: Array = rx.get("triggers", [])
			if trig_list.is_empty():
				var fb: Array = rx.get("pair", [])
				if fb.size() >= 2:
					trig_list = [fb]
			var partners: Array[String] = []
			var can_now := false
			for pair_raw in trig_list:
				if not (pair_raw is Array) or (pair_raw as Array).size() < 2:
					continue
				var pa := String((pair_raw as Array)[0])
				var pb := String((pair_raw as Array)[1])
				var other := ""
				if pa == elem:
					other = pb
				elif pb == elem:
					other = pa
				if other.is_empty():
					continue
				if not partners.has(other):
					partners.append(other)
				if owned_elems.has(other):
					can_now = true
			if partners.is_empty():
				continue
			var first_other := partners[0]
			var other_names: Array[String] = []
			for po in partners:
				other_names.append(String(ELEM_CN.get(po, po)))
			var entry := {
				"id": String(rx.get("id", "")),
				"name": String(rx.get("name", "")),
				"other_element": first_other,
				"other_elem_name": " / ".join(other_names),
				"damage_mult": float(rx.get("damage_mult", 0.2)),
				"effect_text": format_reaction_effect(rx),
				"color_hex": String(rx.get("vfx_color", "#FFFFFF")),
				"can_activate_now": can_now,
			}
			if can_now:
				active_rx_list.append(entry)
			else:
				inactive_rx_list.append(entry)
	var reactions: Array[Dictionary] = []
	reactions.append_array(active_rx_list)
	reactions.append_array(inactive_rx_list)

	var projected_elems := owned_elems.duplicate()
	if elem != "none" and not elem.is_empty():
		projected_elems[elem] = true
	var active_count := _count_reactions_in_elements(v2.loader, owned_elems)
	var projected_count := _count_reactions_in_elements(v2.loader, projected_elems)
	var new_rx_names: Array[String] = []
	if not owned_elems.has(elem):
		for rx_entry in active_rx_list:
			new_rx_names.append(String(rx_entry["name"]))

	var status_sub := "新法宝（预览 Lv.%d）" % next_lv if cur_lv <= 0 else ("当前 Lv.%d → 预览 Lv.%d" % [cur_lv, next_lv] if cur_lv < next_lv else "当前已达 Lv.%d" % cur_lv)
	return {
		"kind": "weapon",
		"id": weapon_id,
		"title": String(w.get("name", weapon_id)),
		"subtitle": "【%s系法宝】 · %s" % [elem_cn, status_sub],
		"icon": String(w.get("icon", "")),
		"element": elem,
		"element_cn": elem_cn,
		"cur_lv": cur_lv,
		"next_lv": next_lv,
		"stat_diffs": stat_diffs,
		"tier_roadmap": tier_roadmap,
		"fusions": fusions,
		"reactions": reactions,
		"synergy_summary": {
			"active_reaction_count": active_count,
			"projected_reaction_count": projected_count,
			"new_reactions": new_rx_names,
		},
	}

static func _count_reactions_in_elements(loader: V2DataLoader, elems: Dictionary) -> int:
	if loader == null:
		return 0
	var cnt := 0
	for rx in loader.reactions_list:
		var trig_list: Array = rx.get("triggers", [])
		if trig_list.is_empty():
			var fb: Array = rx.get("pair", [])
			if fb.size() >= 2:
				trig_list = [fb]
		for pair_raw in trig_list:
			if pair_raw is Array and (pair_raw as Array).size() >= 2:
				if elems.has(String((pair_raw as Array)[0])) and elems.has(String((pair_raw as Array)[1])):
					cnt += 1
					break
	return cnt

static func _collect_owned_synergy_context(v2: V2CombatController) -> Dictionary:
	var active_reactions: Array[Dictionary] = []
	var owned_bonds: Array[String] = []
	var owned_bond_items: Array[Dictionary] = []
	var owned_elements: Array[String] = []
	if v2 == null or v2.loader == null:
		return {
			"active_reactions": active_reactions,
			"owned_bonds": owned_bonds,
			"owned_bond_items": owned_bond_items,
			"owned_elements": owned_elements,
		}
	var owned_elems := v2.get_owned_elements()
	for ek in owned_elems.keys():
		owned_elements.append(String(ek))
	for rx in v2.loader.reactions_list:
		var trig_list: Array = rx.get("triggers", [])
		if trig_list.is_empty():
			var fb: Array = rx.get("pair", [])
			if fb.size() >= 2:
				trig_list = [fb]
		for pair_raw in trig_list:
			if pair_raw is Array and (pair_raw as Array).size() >= 2:
				var ea := String((pair_raw as Array)[0])
				var eb := String((pair_raw as Array)[1])
				if owned_elems.has(ea) and owned_elems.has(eb):
					active_reactions.append({
						"id": String(rx.get("id", "")),
						"name": String(rx.get("name", "")),
						"elem_a": ea,
						"elem_b": eb,
						"elem_a_cn": String(ELEM_CN.get(ea, ea)),
						"elem_b_cn": String(ELEM_CN.get(eb, eb)),
						"effect_text": format_reaction_effect(rx),
					})
					break
	if v2.orbit_rig != null:
		for slot in v2.orbit_rig.slots:
			var wid := String(slot.get("id", ""))
			var lv := int(slot.get("tier", 1))
			if v2.loader.weapons_by_id.has(wid):
				var wdata: Dictionary = v2.loader.weapons_by_id[wid]
				var wname := String(wdata.get("name", wid))
				var welem := String(wdata.get("element", "metal"))
				owned_bonds.append("• %s Lv.%d/%d" % [wname, lv, OrbitWeaponRig.MAX_WEAPON_TIER])
				owned_bond_items.append({
					"is_fusion": false,
					"id": wid,
					"name": wname,
					"level": lv,
					"element": welem,
					"partner_name": "",
					"fusion_name": "",
				})
	return {
		"active_reactions": active_reactions,
		"owned_bonds": owned_bonds,
		"owned_bond_items": owned_bond_items,
		"owned_elements": owned_elements,
	}

static func build_item_detail(v2: V2CombatController, item_id: String) -> Dictionary:
	if v2 == null or v2.loader == null or not v2.loader.items_by_id.has(item_id):
		return {}
	var it: Dictionary = v2.loader.items_by_id[item_id]
	var rarity := int(it.get("rarity", 1))
	var r_label := "凡品奇物" if rarity <= 1 else ("稀有奇物" if rarity == 2 else "绝品奇物")
	var has_tradeoff := V2CombatController.item_has_tradeoff(it)
	var mod_rows: Array[Dictionary] = []
	var mods: Dictionary = it.get("mods", {})
	for k in mods.keys():
		var ks := String(k)
		var v := float(mods[k])
		var spec: Array = MOD_SPECS.get(ks, [ks, "float", false])
		var label := String(spec[0])
		var fmt := String(spec[1])
		var pos_is_bad := bool(spec[2])
		var v_txt := ""
		var is_neg := false
		match fmt:
			"pct":
				v_txt = "%s%d%%" % ["+" if v > 0.0 else "", roundi(v * 100.0)]
				is_neg = (v > 0.0) if pos_is_bad else (v < 0.0)
			"pct_low_good":
				v_txt = "%s%d%%" % ["+" if v > 0.0 else "", roundi(v * 100.0)]
				is_neg = v > 0.0
			"neg_sec":
				v_txt = "-%.2fs" % absf(v)
				is_neg = v < 0.0
			"sec":
				v_txt = "%s%.1fs" % ["+" if v > 0.0 else "", v]
				is_neg = v < 0.0
			"float_sec":
				v_txt = "%s%.1f/s" % ["+" if v > 0.0 else "", v]
				is_neg = v < 0.0
			"int":
				v_txt = "%s%d" % ["+" if v > 0.0 else "", roundi(v)]
				is_neg = v < 0.0
			_:
				v_txt = str(v)
				is_neg = v < 0.0
		mod_rows.append({"label": label, "value_text": v_txt, "is_negative": is_neg})

	var owned_cnt := 0
	for owned in v2.owned_items:
		if String(owned.get("id", "")) == item_id:
			owned_cnt += 1
	var trig_key := String(it.get("trigger", ""))
	var ctx := _collect_owned_synergy_context(v2)
	return {
		"kind": "item",
		"id": item_id,
		"title": String(it.get("name", item_id)),
		"subtitle": "【%s%s】 · 已持有 %d 件" % [r_label, " · 权衡" if has_tradeoff else "", owned_cnt],
		"icon": String(V2ShopUI.ITEM_ICONS.get(item_id, "res://assets/icons/relic_insight.png")),
		"rarity": rarity,
		"has_tradeoff": has_tradeoff,
		"owned_count": owned_cnt,
		"max_stacks": maxi(1, int(it.get("max_stacks", 1))),
		"mod_rows": mod_rows,
		"trigger_desc": String(TRIGGER_LABELS.get(trig_key, "")),
		"desc": String(it.get("desc", "")),
		"active_reactions": ctx["active_reactions"],
		"owned_bonds": ctx["owned_bonds"],
		"owned_bond_items": ctx["owned_bond_items"],
		"owned_elements": ctx["owned_elements"],
	}

static func build_stat_detail(v2: V2CombatController, choice: Dictionary) -> Dictionary:
	var ctx := _collect_owned_synergy_context(v2)
	var sm := v2.get_stats_summary() if v2 != null else {}
	return {
		"kind": "stat",
		"id": String(choice.get("id", "")),
		"title": String(choice.get("title", "")),
		"subtitle": String(choice.get("tag", "【境界突破】")),
		"icon": String(choice.get("icon", "")),
		"desc": String(choice.get("desc", "")),
		"hint": String(choice.get("synergy_hint", "")),
		"stats_summary": sm,
		"active_reactions": ctx["active_reactions"],
		"owned_bonds": ctx["owned_bonds"],
		"owned_bond_items": ctx["owned_bond_items"],
		"owned_elements": ctx["owned_elements"],
	}
