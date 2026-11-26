class_name V2CodexPanel
extends Control

signal closed

const TAB_NAMES := ["五大灵变 (5)", "法宝图鉴 (8)", "境界与奇物 (4+16)"]

var active_tab: int = 0
var codex_data: Dictionary = {}

var _v2: V2CombatController = null
var _own_loader: V2DataLoader = null
var _summary_lbl: Label = null
var _tab_btns: Array[Button] = []
var _content_vb: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if not codex_data.is_empty():
		_refresh_view()

func setup(v2: V2CombatController = null) -> void:
	_v2 = v2
	var loader: V2DataLoader = v2.loader if (v2 != null and v2.loader != null) else null
	if loader == null:
		if _own_loader == null:
			_own_loader = V2DataLoader.new()
			add_child(_own_loader)
			_own_loader.load_all("res://data/v2")
		loader = _own_loader
	codex_data = build_codex_data(loader, v2)
	if _content_vb != null:
		_refresh_view()

func switch_tab(tab_idx: int) -> void:
	active_tab = clampi(tab_idx, 0, TAB_NAMES.size() - 1)
	if _content_vb != null:
		_refresh_view()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.07, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			closed.emit()
	)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -500.0
	panel.offset_right = 500.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 26))
	XianxiaUITheme.attach_ornaments(panel, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	add_child(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	panel.add_child(root_vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_vb.add_child(header)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 2)
	header.add_child(title_vb)

	var title_lbl := Label.new()
	title_lbl.text = "五行法典 · 构筑图鉴"
	var tf = load("res://assets/title_font.tres")
	if tf != null:
		title_lbl.add_theme_font_override("font", tf)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.09, 0.28, 0.24))
	title_vb.add_child(title_lbl)

	_summary_lbl = Label.new()
	_summary_lbl.add_theme_font_size_override("font_size", 14)
	_summary_lbl.add_theme_color_override("font_color", Color(0.24, 0.42, 0.37))
	title_vb.add_child(_summary_lbl)

	var close_btn := _make_btn("返回 [ESC]", Color(0.24, 0.32, 0.30), Color(0.72, 0.76, 0.72))
	close_btn.custom_minimum_size = Vector2(116, 36)
	close_btn.pressed.connect(func(): closed.emit())
	header.add_child(close_btn)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	root_vb.add_child(tabs_row)

	_tab_btns.clear()
	for i in range(TAB_NAMES.size()):
		var b := _make_btn(TAB_NAMES[i], Color(0.88, 0.86, 0.78), Color(0.32, 0.58, 0.50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		var idx := i
		b.pressed.connect(func(): switch_tab(idx))
		tabs_row.add_child(b)
		_tab_btns.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	XianxiaUITheme.style_scroll_container(scroll)
	root_vb.add_child(scroll)

	_content_vb = XianxiaUITheme.make_scroll_body(scroll, 12, 10, 4)

func _make_btn(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	_apply_btn_style(b, bg, border, Color(1.0, 0.96, 0.86))
	return b

func _apply_btn_style(b: Button, bg: Color, border: Color, font_col: Color) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.10)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_color_override("font_color", font_col)

func _refresh_view() -> void:
	if _content_vb == null or codex_data.is_empty():
		return
	var sm: Dictionary = codex_data.get("summary", {})
	var elems: Array = sm.get("owned_elements", [])
	var elem_txt := "暂无元素" if elems.is_empty() else "、".join(elems)
	_summary_lbl.text = "境界 Lv.%d  |  法宝槽 %d/%d  |  已持元素：%s  |  可触发五大灵变：%d/%d" % [
		int(sm.get("player_level", 1)),
		int(sm.get("unlocked_slots", 1)),
		int(sm.get("max_slots", 4)),
		elem_txt,
		int(sm.get("active_reaction_count", 0)),
		int(sm.get("total_reactions", 5)),
	]

	for i in range(_tab_btns.size()):
		var selected := (i == active_tab)
		if selected:
			_apply_btn_style(_tab_btns[i], Color(0.14, 0.44, 0.36), Color(0.92, 0.74, 0.30), Color(1.0, 0.96, 0.86))
		else:
			_apply_btn_style(_tab_btns[i], Color(0.92, 0.90, 0.84), Color(0.42, 0.62, 0.56), Color(0.14, 0.30, 0.26))

	for c in _content_vb.get_children():
		_content_vb.remove_child(c)
		c.queue_free()

	match active_tab:
		0:
			_render_reactions_tab(sm)
		1:
			_render_weapons_tab()
		_:
			_render_realms_items_tab()

func _make_card_panel(bg: Color, border: Color, bw: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(bw)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	return p

func _render_reactions_tab(sm: Dictionary) -> void:
	var icd_lbl := Label.new()
	icd_lbl.text = "单怪反应冷却 %.1fs（精英/首领 %.1fs），单怪同时至多附着 1 种元素，反应不可暴击。" % [float(sm.get("icd_normal", 2.0)), float(sm.get("icd_boss", 2.5))]
	icd_lbl.add_theme_font_size_override("font_size", 13)
	icd_lbl.add_theme_color_override("font_color", Color(0.28, 0.40, 0.36))
	_content_vb.add_child(icd_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_content_vb.add_child(grid)

	for rx in codex_data.get("reactions", []):
		var active := bool(rx.get("active_now", false))
		var missing := String(rx.get("partial_missing", ""))
		var bg := Color(0.87, 0.96, 0.90) if active else (Color(0.99, 0.96, 0.86) if missing != "" else Color(0.94, 0.92, 0.87))
		var bd := Color(0.14, 0.64, 0.40) if active else (Color(0.84, 0.62, 0.22) if missing != "" else Color(0.68, 0.72, 0.68))
		var card := _make_card_panel(bg, bd, 2 if active else 1)
		grid.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		card.add_child(vb)

		var status := "✦ 已激活" if active else (("缺【%s】可激活" % missing) if missing != "" else "未集齐")
		var head := Label.new()
		var formula_txt := String(rx.get("formula_cn", "%s + %s" % [String(rx.get("elem_a_cn", "")), String(rx.get("elem_b_cn", ""))]))
		head.text = "【%s】 %s  (%s)" % [String(rx.get("name", "")), formula_txt, status]
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Color(0.06, 0.36, 0.20) if active else (Color(0.66, 0.34, 0.08) if missing != "" else Color(0.24, 0.32, 0.29)))
		vb.add_child(head)

		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = String(rx.get("effect_text", ""))
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.22, 0.30, 0.27))
		vb.add_child(desc)

func _render_weapons_tab() -> void:
	var weapons_list: Array = codex_data.get("weapons", [])
	var h2 := Label.new()
	h2.text = "%d 大基础法宝 Lv.1 → Lv.%d 成长路线" % [weapons_list.size(), OrbitWeaponRig.MAX_WEAPON_TIER]
	h2.add_theme_font_size_override("font_size", 15)
	h2.add_theme_color_override("font_color", Color(0.10, 0.36, 0.30))
	_content_vb.add_child(h2)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_content_vb.add_child(grid)

	for w in weapons_list:
		var cur_lv := int(w.get("cur_lv", 0))
		var card := _make_card_panel(Color(0.90, 0.96, 0.92) if cur_lv > 0 else Color(0.95, 0.93, 0.88), Color(0.18, 0.58, 0.46) if cur_lv > 0 else Color(0.68, 0.72, 0.68), 2 if cur_lv > 0 else 1)
		grid.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		card.add_child(vb)

		var title := Label.new()
		var lv_str := "当前 Lv.%d/%d" % [cur_lv, OrbitWeaponRig.MAX_WEAPON_TIER] if cur_lv > 0 else "未携带"
		title.text = "【%s】%s · %s" % [String(w.get("element_cn", "")), String(w.get("name", "")), lv_str]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.08, 0.36, 0.26) if cur_lv > 0 else Color(0.22, 0.30, 0.28))
		vb.add_child(title)

		for t in w.get("tiers", []):
			var t_lv := int(t.get("tier", 1))
			var tl := Label.new()
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tl.text = "%sLv.%d：%s" % ["✓ " if cur_lv >= t_lv else "○ ", t_lv, String(t.get("level_summary", ""))]
			tl.add_theme_font_size_override("font_size", 12)
			tl.add_theme_color_override("font_color", Color(0.10, 0.44, 0.30) if cur_lv >= t_lv else Color(0.36, 0.42, 0.40))
			vb.add_child(tl)

func _render_realms_items_tab() -> void:
	var h1 := Label.new()
	var max_slots := int(codex_data.get("summary", {}).get("max_slots", 4))
	h1.text = "大境界法宝槽解锁进度（击杀第 2 只大精英亦可提前解封全部 %d 槽）" % max_slots
	h1.add_theme_font_size_override("font_size", 15)
	h1.add_theme_color_override("font_color", Color(0.10, 0.36, 0.30))
	_content_vb.add_child(h1)

	var realm_row := HBoxContainer.new()
	realm_row.add_theme_constant_override("separation", 8)
	_content_vb.add_child(realm_row)
	for rm in codex_data.get("realms", []):
		var unlocked := bool(rm.get("unlocked", false))
		var card := _make_card_panel(Color(0.88, 0.96, 0.90) if unlocked else Color(0.93, 0.91, 0.86), Color(0.16, 0.60, 0.44) if unlocked else Color(0.68, 0.72, 0.68), 2 if unlocked else 1)
		realm_row.add_child(card)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text = "%s\n%d 槽 · Lv.%d\n%s" % [String(rm.get("realm", "")), int(rm.get("slots", 1)), int(rm.get("level", 1)), "✓ 已开" if unlocked else "未解"]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.08, 0.40, 0.26) if unlocked else Color(0.38, 0.44, 0.42))
		card.add_child(l)

	var h2 := Label.new()
	h2.text = "随身奇物录（共 16 件 · 含权衡代价词条）"
	h2.add_theme_font_size_override("font_size", 15)
	h2.add_theme_color_override("font_color", Color(0.10, 0.36, 0.30))
	_content_vb.add_child(h2)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_content_vb.add_child(grid)

	for it in codex_data.get("items", []):
		var cnt := int(it.get("owned_count", 0))
		var rarity := int(it.get("rarity", 1))
		var tradeoff := bool(it.get("has_tradeoff", false))
		var r_name := "普通" if rarity <= 1 else ("稀有" if rarity == 2 else "绝品")
		var bd := Color(0.68, 0.34, 0.72) if rarity >= 3 else (Color(0.20, 0.48, 0.76) if rarity == 2 else Color(0.62, 0.68, 0.64))
		var card := _make_card_panel(Color(0.90, 0.96, 0.92) if cnt > 0 else Color(0.95, 0.93, 0.88), bd, 2 if cnt > 0 else 1)
		grid.add_child(card)
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var own_txt := "（已持 %d）" % cnt if cnt > 0 else "（%d 灵石）" % int(it.get("cost", 20))
		l.text = "【%s%s】%s %s\n%s" % [r_name, "·权衡" if tradeoff else "", String(it.get("name", "")), own_txt, String(it.get("desc", ""))]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.12, 0.26, 0.22))
		card.add_child(l)

static func build_codex_data(loader: V2DataLoader, v2: V2CombatController = null) -> Dictionary:
	if loader == null:
		return {}
	var owned_elems := v2.get_owned_elements() if v2 != null else {}
	var player_lv := int(v2.player.level) if (v2 != null and v2.player != null) else 1
	var unlocked_slots := v2.get_unlocked_slots() if v2 != null else 1

	var rx_active: Array[Dictionary] = []
	var rx_partial: Array[Dictionary] = []
	var rx_other: Array[Dictionary] = []
	for rx in loader.reactions_list:
		var trig_list: Array = rx.get("triggers", [])
		if trig_list.is_empty():
			var fb: Array = rx.get("pair", [])
			if fb.size() >= 2:
				trig_list = [fb]
		if trig_list.is_empty():
			continue
		var ea := String((trig_list[0] as Array)[0])
		var eb := String((trig_list[0] as Array)[1])
		var active := false
		var missing := ""
		for pair_raw in trig_list:
			if not (pair_raw is Array) or (pair_raw as Array).size() < 2:
				continue
			var pa := String((pair_raw as Array)[0])
			var pb := String((pair_raw as Array)[1])
			var has_a := owned_elems.has(pa)
			var has_b := owned_elems.has(pb)
			if has_a and has_b:
				active = true
				ea = pa
				eb = pb
				missing = ""
				break
			if missing.is_empty():
				if has_a and not has_b:
					missing = String(V2DetailDrawer.ELEM_CN.get(pb, pb))
				elif has_b and not has_a:
					missing = String(V2DetailDrawer.ELEM_CN.get(pa, pa))
		var entry := {
			"id": String(rx.get("id", "")),
			"name": String(rx.get("name", "")),
			"formula_cn": String(rx.get("formula_cn", "%s + %s" % [String(V2DetailDrawer.ELEM_CN.get(ea, ea)), String(V2DetailDrawer.ELEM_CN.get(eb, eb))])),
			"elem_a": ea,
			"elem_b": eb,
			"elem_a_cn": String(V2DetailDrawer.ELEM_CN.get(ea, ea)),
			"elem_b_cn": String(V2DetailDrawer.ELEM_CN.get(eb, eb)),
			"damage_mult": float(rx.get("damage_mult", 0.2)),
			"effect_text": V2DetailDrawer.format_reaction_effect(rx),
			"active_now": active,
			"partial_missing": missing,
		}
		if active:
			rx_active.append(entry)
		elif missing != "":
			rx_partial.append(entry)
		else:
			rx_other.append(entry)
	var reactions: Array[Dictionary] = []
	reactions.append_array(rx_active)
	reactions.append_array(rx_partial)
	reactions.append_array(rx_other)

	var weapons: Array[Dictionary] = []
	for wid_raw in loader.weapons_by_id.keys():
		var wid := String(wid_raw)
		var w: Dictionary = loader.weapons_by_id[wid_raw]
		var el := String(w.get("element", "metal"))
		weapons.append({
			"id": wid,
			"name": String(w.get("name", wid)),
			"element": el,
			"element_cn": String(V2DetailDrawer.ELEM_CN.get(el, el)),
			"icon": String(w.get("icon", "")),
			"cur_lv": v2.orbit_rig.get_weapon_tier(wid) if (v2 != null and v2.orbit_rig != null) else 0,
			"tiers": w.get("tiers", []),
		})

	var fusions: Array[Dictionary] = []

	var realms: Array[Dictionary] = []
	var r_table := v2.get_realm_table() if v2 != null else loader.realm_slot_unlocks
	for entry in r_table:
		var s := int(entry.get("slots", 1))
		realms.append({
			"slots": s,
			"level": int(entry.get("level", 1)),
			"realm": String(entry.get("realm", "")),
			"alt_elite_kills": int(entry.get("alt_elite_kills", 0)),
			"unlocked": s <= unlocked_slots,
		})

	var item_counts := {}
	if v2 != null:
		for owned in v2.owned_items:
			var oid := String(owned.get("id", ""))
			item_counts[oid] = int(item_counts.get(oid, 0)) + 1

	var items: Array[Dictionary] = []
	for iid_raw in loader.items_by_id.keys():
		var iid := String(iid_raw)
		var it: Dictionary = loader.items_by_id[iid_raw]
		items.append({
			"id": iid,
			"name": String(it.get("name", iid)),
			"desc": String(it.get("desc", "")),
			"cost": int(it.get("cost", 20)),
			"rarity": int(it.get("rarity", 1)),
			"has_tradeoff": V2CombatController.item_has_tradeoff(it),
			"owned_count": int(item_counts.get(iid, 0)),
		})

	var owned_elem_names: Array[String] = []
	for el_k in owned_elems.keys():
		owned_elem_names.append(String(V2DetailDrawer.ELEM_CN.get(String(el_k), String(el_k))))

	return {
		"reactions": reactions,
		"weapons": weapons,
		"fusions": fusions,
		"realms": realms,
		"items": items,
		"summary": {
			"player_level": player_lv,
			"unlocked_slots": unlocked_slots,
			"max_slots": v2.get_max_weapon_slots() if v2 != null else loader.max_weapon_slots,
			"owned_elements": owned_elem_names,
			"active_reaction_count": rx_active.size(),
			"total_reactions": reactions.size(),
			"icd_normal": float(loader.reaction_config.get("per_enemy_icd_sec", 2.0)),
			"icd_boss": float(loader.reaction_config.get("boss_icd_sec", 2.5)),
		},
	}
