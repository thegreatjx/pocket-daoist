extends CanvasLayer
class_name UpgradeUI

signal upgrade_selected(upgrade_id: String)
signal reroll_requested
signal banish_selected(upgrade_id: String)
signal skip_requested

const INPUT_GRACE_MSEC := 280

var is_showing: bool = false
var _opened_msec: int = 0
var _choice_ids: Array[String] = []
var _banish_mode: bool = false
var _rerolls_avail: int = 0
var _banishes_avail: int = 0
var _skips_avail: int = 0
var _is_breakthrough: bool = false
var _base_title: String = "境界精进 · 机缘降临"
var _choices_data: Array = []
var _v2: V2CombatController = null
var _detail_drawer: V2DetailDrawer = null
var _detail_index: int = -1

@onready var container: HBoxContainer = $Panel/CardContainer
@onready var title_label: Label = $Panel/TitleLabel
@onready var panel: Panel = $Panel

var _action_bar: HBoxContainer = null
var _reroll_btn: Button = null
var _banish_btn: Button = null
var _skip_btn: Button = null

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 0))
	XianxiaUITheme.attach_ornaments(panel, XianxiaUITheme.COL_GOLD, 16.0, 7.0)

	if title_label != null:
		var title_font = load("res://assets/title_font.tres")
		if title_font != null:
			title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)

	if panel != null:
		panel.offset_top = -272.0
		panel.offset_bottom = 272.0
	if title_label != null:
		title_label.offset_top = 22.0
		title_label.offset_bottom = 66.0
	if container != null:
		container.offset_top = -176.0
		container.offset_bottom = 176.0
	_build_action_bar()
	_detail_drawer = V2DetailDrawer.new()
	_detail_drawer.name = "V2DetailDrawer"
	_detail_drawer.confirm_action_requested.connect(_on_detail_confirm_pressed)
	_detail_drawer.closed.connect(func(): _detail_index = -1)
	add_child(_detail_drawer)

func _build_action_bar() -> void:
	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 18)
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_action_bar.offset_top = -56.0
	_action_bar.offset_bottom = -20.0

	_reroll_btn = _make_action_btn("重随 [R]")
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	_action_bar.add_child(_reroll_btn)

	_banish_btn = _make_action_btn("封印 [B]")
	_banish_btn.pressed.connect(_toggle_banish_mode)
	_action_bar.add_child(_banish_btn)

	_skip_btn = _make_action_btn("跳过回血 [K]")
	_skip_btn.pressed.connect(_on_skip_pressed)
	_action_bar.add_child(_skip_btn)

	panel.add_child(_action_bar)
	_action_bar.visible = false

func _make_action_btn(label_text: String) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(150, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	XianxiaUITheme.style_button(b, "dark_gold")
	return b

func show_choices(choices: Array, remaining_after: int = 0, rerolls: int = 0, banishes: int = 0, skips: int = 0, is_limit: bool = false, is_breakthrough: bool = false, v2_combat: V2CombatController = null) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

	close_detail_drawer()
	_choices_data = choices.duplicate(true)
	_v2 = v2_combat
	_banish_mode = false
	_rerolls_avail = rerolls
	_banishes_avail = banishes
	_skips_avail = skips
	_is_breakthrough = is_breakthrough

	var is_four := choices.size() >= 4
	if panel != null:
		panel.offset_left = -576.0 if is_four else -476.0
		panel.offset_right = 576.0 if is_four else 476.0
	if container != null:
		container.offset_left = -542.0 if is_four else -442.0
		container.offset_right = 542.0 if is_four else 442.0
		container.add_theme_constant_override("separation", 14 if is_four else 20)

	if is_limit:
		_base_title = "圆满破境 · 无限淬炼"
	elif is_breakthrough:
		_base_title = "破境开槽 · 祭炼新法宝"
	else:
		_base_title = "境界精进 · 机缘降临"
	if not is_limit and remaining_after > 0:
		_base_title += "（其后还有 %d 次机缘）" % remaining_after
	title_label.text = _base_title

	visible = true
	is_showing = true
	_opened_msec = Time.get_ticks_msec()
	_choice_ids.clear()

	if _action_bar != null:
		_action_bar.visible = (not is_limit) and (rerolls > 0 or banishes > 0 or skips > 0)
		_refresh_action_buttons()

	for i in range(choices.size()):
		var item: Dictionary = choices[i]
		var is_evo: bool = bool(item.get("is_evo", false))
		var is_relic: bool = bool(item.get("is_relic", false))
		var is_new: bool = bool(item.get("is_new", false))

		var btn = Button.new()
		btn.clip_contents = true
		btn.custom_minimum_size = Vector2(240 if is_four else 260, 344)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE

		var accent := Color(0.18, 0.62, 0.54)
		var card_tint := XianxiaUITheme.COL_PAPER_CARD
		var tag_color := Color(0.10, 0.48, 0.42)
		if is_evo:
			accent = Color(0.84, 0.30, 0.16)
			card_tint = Color(1.0, 0.96, 0.87, 1.0)
			tag_color = Color(0.76, 0.22, 0.12)
		elif is_relic:
			accent = Color(0.82, 0.60, 0.18)
			card_tint = Color(0.98, 0.97, 0.91, 1.0)
			tag_color = Color(0.65, 0.42, 0.08)

		var card_bg := XianxiaUITheme.make_card_style(card_tint, accent, 2, 10, 0)
		btn.add_theme_stylebox_override("normal", card_bg)

		var card_hover := card_bg.duplicate() as StyleBoxFlat
		card_hover.bg_color = Color(1.0, 0.99, 0.95, 1.0)
		card_hover.border_color = XianxiaUITheme.COL_GOLD_BRIGHT
		card_hover.shadow_size = 10
		btn.add_theme_stylebox_override("hover", card_hover)
		btn.add_theme_stylebox_override("focus", card_hover)
		XianxiaUITheme.attach_ornaments(btn, Color(accent.r, accent.g, accent.b, 0.72), 7.0, 4.0)

		var margin = MarginContainer.new()
		margin.clip_contents = true
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_PASS
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		btn.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_theme_constant_override("separation", 5)
		margin.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.mouse_filter = Control.MOUSE_FILTER_PASS
		top_row.add_theme_constant_override("separation", 4)
		vbox.add_child(top_row)

		var tag_lbl = Label.new()
		tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_lbl.custom_minimum_size = Vector2(10, 0)
		tag_lbl.clip_text = true
		tag_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tag_lbl.text = "[%d] %s%s" % [i + 1, str(item.get("tag", "")), " · 新" if is_new else ""]
		tag_lbl.add_theme_font_size_override("font_size", 13 if is_four else 14)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_color_override("font_color", Color(0.76, 0.28, 0.14) if is_new else tag_color)
		top_row.add_child(tag_lbl)

		var detail_btn := Button.new()
		detail_btn.text = "详"
		detail_btn.tooltip_text = "查看详细数值与五行联动"
		detail_btn.custom_minimum_size = Vector2(30, 24)
		detail_btn.focus_mode = Control.FOCUS_NONE
		detail_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		detail_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		detail_btn.add_theme_font_size_override("font_size", 13)
		XianxiaUITheme.style_button(detail_btn, "dark_gold")
		var card_idx := i
		detail_btn.pressed.connect(func():
			if _detail_drawer != null and _detail_drawer.is_open and _detail_index == card_idx:
				close_detail_drawer()
			else:
				open_card_detail(card_idx)
		)
		top_row.add_child(detail_btn)

		var uid := str(item["id"])

		var mid_vb := VBoxContainer.new()
		mid_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid_vb.add_theme_constant_override("separation", 5)
		vbox.add_child(mid_vb)

		var icon_path := str(item.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var icon_holder = CenterContainer.new()
			icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_holder.custom_minimum_size = Vector2(0, 56)
			var badge = PanelContainer.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var b_style = StyleBoxFlat.new()
			b_style.bg_color = Color(0.10, 0.24, 0.22, 0.92)
			b_style.set_border_width_all(2)
			b_style.border_color = accent
			b_style.set_corner_radius_all(10)
			b_style.set_content_margin_all(5)
			badge.add_theme_stylebox_override("panel", b_style)
			var tr = TextureRect.new()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.texture = load(icon_path)
			tr.custom_minimum_size = Vector2(44, 44)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.add_child(tr)
			icon_holder.add_child(badge)
			mid_vb.add_child(icon_holder)

		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(10, 0)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.text = str(item.get("title", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18 if is_four else 20)
		name_lbl.add_theme_color_override("font_color", Color(0.76, 0.22, 0.12) if is_evo else XianxiaUITheme.COL_INK)
		mid_vb.add_child(name_lbl)

		var hs = HSeparator.new()
		hs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hs.modulate = Color(accent.r, accent.g, accent.b, 0.45)
		mid_vb.add_child(hs)

		var cur_lv := int(item.get("level", 0))
		var next_lv := int(item.get("next_level", cur_lv + 1))
		var max_lv := int(item.get("max_level", 8))
		var offer_kind := str(item.get("offer_kind", ""))
		var will_max := (not is_new) and next_lv >= max_lv and max_lv > 1
		var lvl_lbl = Label.new()
		lvl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl_lbl.custom_minimum_size = Vector2(10, 0)
		lvl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if is_limit:
			lvl_lbl.text = "破限增幅"
			lvl_lbl.add_theme_color_override("font_color", Color(0.76, 0.28, 0.12))
		elif offer_kind == "stat":
			if max_lv < 0:
				lvl_lbl.text = "即时补给 · 每次可用"
				lvl_lbl.add_theme_color_override("font_color", Color(0.14, 0.46, 0.36))
			elif max_lv == 0:
				lvl_lbl.text = "可无限叠加 · 第 %d 层" % next_lv
				lvl_lbl.add_theme_color_override("font_color", Color(0.14, 0.46, 0.36))
			elif cur_lv <= 0:
				lvl_lbl.text = "限叠 %d 次 · 第 1/%d 层" % [max_lv, max_lv]
				lvl_lbl.add_theme_color_override("font_color", Color(0.14, 0.46, 0.36))
			elif next_lv >= max_lv:
				lvl_lbl.text = "限叠 %d 次 · 第 %d → %d/%d 层（将满）" % [max_lv, cur_lv, next_lv, max_lv]
				lvl_lbl.add_theme_color_override("font_color", Color(0.76, 0.28, 0.12))
			else:
				lvl_lbl.text = "限叠 %d 次 · 第 %d → %d/%d 层" % [max_lv, cur_lv, next_lv, max_lv]
				lvl_lbl.add_theme_color_override("font_color", Color(0.72, 0.34, 0.12))
		elif is_new:
			lvl_lbl.text = "修习 Lv.1 / %d" % max_lv
			lvl_lbl.add_theme_color_override("font_color", Color(0.24, 0.40, 0.36))
		elif will_max:
			lvl_lbl.text = "Lv.%d → 满级 (Lv.%d)" % [cur_lv, max_lv]
			lvl_lbl.add_theme_color_override("font_color", Color(0.76, 0.28, 0.12))
		else:
			lvl_lbl.text = "Lv.%d → Lv.%d / %d" % [cur_lv, next_lv, max_lv]
			lvl_lbl.add_theme_color_override("font_color", Color(0.24, 0.40, 0.36))
		lvl_lbl.add_theme_font_size_override("font_size", 15)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid_vb.add_child(lvl_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = str(item.get("desc", ""))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.custom_minimum_size = Vector2(10, 0)
		desc_lbl.add_theme_font_size_override("font_size", 15 if is_four else 16)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_color_override("font_color", Color(0.16, 0.24, 0.22))
		mid_vb.add_child(desc_lbl)

		var synergy := str(item.get("synergy_hint", ""))
		if synergy != "":
			var syn_panel := PanelContainer.new()
			syn_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			syn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sst := StyleBoxFlat.new()
			sst.bg_color = Color(0.93, 0.90, 0.78, 0.95)
			sst.set_corner_radius_all(6)
			sst.content_margin_left = 6
			sst.content_margin_right = 6
			sst.content_margin_top = 4
			sst.content_margin_bottom = 4
			syn_panel.add_theme_stylebox_override("panel", sst)
			var syn_lbl := Label.new()
			syn_lbl.text = synergy
			syn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			syn_lbl.custom_minimum_size = Vector2(10, 0)
			syn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			syn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			syn_lbl.add_theme_font_size_override("font_size", 12)
			syn_lbl.add_theme_color_override("font_color", Color(0.56, 0.24, 0.10))
			syn_panel.add_child(syn_lbl)
			mid_vb.add_child(syn_panel)

		var pick_btn := Button.new()
		pick_btn.text = "选定 [%d]" % (i + 1)
		pick_btn.custom_minimum_size = Vector2(0, 32)
		pick_btn.focus_mode = Control.FOCUS_NONE
		pick_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		pick_btn.add_theme_font_size_override("font_size", 15)
		XianxiaUITheme.style_button(pick_btn, "cinnabar" if is_evo else "primary")
		pick_btn.pressed.connect(func():
			btn.emit_signal("pressed")
		)
		vbox.add_child(pick_btn)

		_choice_ids.append(uid)
		btn.pressed.connect(func():
			_on_card_pressed(uid)
		)
		container.add_child(btn)

func _refresh_action_buttons() -> void:
	if _reroll_btn != null:
		_reroll_btn.text = "重随 (%d) [R]" % _rerolls_avail
		_reroll_btn.disabled = _rerolls_avail <= 0
	if _banish_btn != null:
		_banish_btn.text = ("点选要封印的卡..." if _banish_mode else "封印 (%d) [B]" % _banishes_avail)
		_banish_btn.disabled = _banishes_avail <= 0
	if _skip_btn != null:
		_skip_btn.text = "跳过回血 (%d) [K]" % _skips_avail
		_skip_btn.disabled = _skips_avail <= 0

func _on_reroll_pressed() -> void:
	if not is_showing or _rerolls_avail <= 0:
		return
	_banish_mode = false
	emit_signal("reroll_requested")

func _toggle_banish_mode() -> void:
	if not is_showing or _banishes_avail <= 0:
		return
	close_detail_drawer()
	_banish_mode = not _banish_mode
	_refresh_action_buttons()
	if _banish_mode:
		title_label.text = "选择一张机缘永久封印（本局不再出现）"
	else:
		title_label.text = _base_title

func open_card_detail(index: int) -> bool:
	if _detail_drawer == null or index < 0 or index >= _choices_data.size():
		return false
	var item: Dictionary = _choices_data[index]
	var uid := String(item.get("id", ""))
	var detail := {}
	if uid.begins_with("v2_wpn:") and _v2 != null:
		var wid := String(item.get("weapon_id", ""))
		if wid.is_empty():
			var parts := uid.split(":")
			if parts.size() >= 2:
				wid = parts[1]
		detail = V2DetailDrawer.build_weapon_detail(_v2, wid, int(item.get("next_level", 1)))
	else:
		detail = V2DetailDrawer.build_stat_detail(_v2, item)
	if detail.is_empty():
		return false
	_detail_index = index
	var action_lbl := "封印此卡" if _banish_mode else "选定 [%d]" % (index + 1)
	_detail_drawer.open_detail(detail, action_lbl, true)
	return true

func close_detail_drawer() -> void:
	_detail_index = -1
	if _detail_drawer != null:
		_detail_drawer.close_detail()

func get_detail_drawer() -> V2DetailDrawer:
	return _detail_drawer

func _on_detail_confirm_pressed() -> void:
	if _detail_index >= 0 and _detail_index < _choice_ids.size():
		_on_card_pressed(_choice_ids[_detail_index])

func _on_skip_pressed() -> void:
	if not is_showing or _skips_avail <= 0:
		return
	hide_panel()
	emit_signal("skip_requested")

func _input(event: InputEvent) -> void:
	if not is_showing or not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if Time.get_ticks_msec() - _opened_msec < INPUT_GRACE_MSEC:
		return
	if ke.keycode == KEY_ESCAPE and _detail_drawer != null and _detail_drawer.is_open:
		get_viewport().set_input_as_handled()
		close_detail_drawer()
		return
	if ke.keycode == KEY_R and _rerolls_avail > 0:
		get_viewport().set_input_as_handled()
		_on_reroll_pressed()
		return
	if ke.keycode == KEY_B and _banishes_avail > 0:
		get_viewport().set_input_as_handled()
		_toggle_banish_mode()
		return
	if ke.keycode == KEY_K and _skips_avail > 0:
		get_viewport().set_input_as_handled()
		_on_skip_pressed()
		return
	var idx := -1
	match ke.keycode:
		KEY_1, KEY_KP_1: idx = 0
		KEY_2, KEY_KP_2: idx = 1
		KEY_3, KEY_KP_3: idx = 2
		KEY_4, KEY_KP_4: idx = 3
	if idx >= 0 and idx < _choice_ids.size():
		get_viewport().set_input_as_handled()
		_on_card_pressed(_choice_ids[idx])

func _on_card_pressed(uid: String) -> void:
	if not is_showing:
		return
	if _banish_mode:
		hide_panel()
		emit_signal("banish_selected", uid)
		return
	hide_panel()
	emit_signal("upgrade_selected", uid)

func hide_panel() -> void:
	close_detail_drawer()
	visible = false
	is_showing = false
	_banish_mode = false
	_choice_ids.clear()
	_choices_data.clear()
