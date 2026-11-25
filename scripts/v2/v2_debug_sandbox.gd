class_name V2DebugSandbox
extends CanvasLayer

signal closed

const TAB_TITLES := ["靶场与人物", "法宝与超武", "秘宝与道韵", "反应与掉落测试"]

var _main: Node = null
var _player: Player = null
var _spawner: Node = null
var _paused_by_sandbox: bool = false
var _loader: V2DataLoader = null
var _active_tab: int = 0

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _status_lbl: Label = null
var _tab_btns: Array[Button] = []
var _tab_pages: Array[Control] = []

var _char_btns: Dictionary = {}
var _stage_btns: Dictionary = {}
var _weapon_rows: Dictionary = {}
var _item_rows: Dictionary = {}
var _arcana_rows: Dictionary = {}
var _invincible_btn: Button = null
var _active_stage_id: int = 1

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_active_stage_id = Stats.selected_stage_id
	_loader = V2DataLoader.new()
	_loader.load_all("res://data/v2")
	_build_ui()

func _exit_tree() -> void:
	if _loader != null and is_instance_valid(_loader):
		_loader.free()
	_loader = null

func setup(main_node: Node, player_node: Player, spawner_node: Node) -> void:
	_main = main_node
	_player = player_node
	_spawner = spawner_node
	_refresh_ui()

func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()

func open_panel() -> void:
	if visible:
		return
	if GameFlow.state == GameFlow.State.PLAYING:
		if GameFlow.request_upgrade():
			_paused_by_sandbox = true
	visible = true
	_refresh_ui()

func close_panel() -> void:
	if not visible:
		return
	visible = false
	if _paused_by_sandbox:
		_paused_by_sandbox = false
		GameFlow.finish_upgrade()
	if _main != null and _main.has_method("_refresh_hud_loadout"):
		_main.call("_refresh_hud_loadout")
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and (k.keycode == KEY_F9 or k.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_panel()

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.08, 0.07, 0.62)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -530.0
	_panel.offset_right = 530.0
	_panel.offset_top = -330.0
	_panel.offset_bottom = 330.0
	_panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 16))
	XianxiaUITheme.attach_ornaments(_panel, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	add_child(_panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	_panel.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_box.add_child(header)

	var title := Label.new()
	title.text = "演武实验台 · 数据驱动沙盒 (F9)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	header.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 14)
	_status_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_INK_MUTED)
	header.add_child(_status_lbl)

	var close_btn := Button.new()
	close_btn.text = "继续测试 (F9)"
	close_btn.custom_minimum_size = Vector2(130, 34)
	XianxiaUITheme.style_button(close_btn, "cinnabar")
	close_btn.pressed.connect(close_panel)
	header.add_child(close_btn)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	root_box.add_child(tab_bar)
	_tab_btns.clear()
	for i in range(TAB_TITLES.size()):
		var tab_idx := i
		var tb := _add_action_btn(tab_bar, TAB_TITLES[i], "secondary", func(): _switch_tab(tab_idx))
		_tab_btns.append(tb)

	var page_wrap := Control.new()
	page_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(page_wrap)

	_tab_pages.clear()
	_tab_pages.append(_build_arena_tab(page_wrap))
	_tab_pages.append(_build_weapons_tab(page_wrap))
	_tab_pages.append(_build_items_arcana_tab(page_wrap))
	_tab_pages.append(_build_reactions_pickups_tab(page_wrap))
	_switch_tab(0)

func _make_scroll_page(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body

func _build_arena_tab(parent: Control) -> Control:
	var body := _make_scroll_page(parent)

	body.add_child(_make_section_label("一、木桩靶场控制（纯实验目标，无刷怪波次）"))
	var dummy_grid := GridContainer.new()
	dummy_grid.columns = 3
	dummy_grid.add_theme_constant_override("h_separation", 8)
	dummy_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(dummy_grid)
	_add_action_btn(dummy_grid, "放 1 个无限DPS木桩", "primary", func(): _spawn_dummies(1, TrainingDummy.ResetMode.INFINITE, true))
	_add_action_btn(dummy_grid, "放 3 个聚阵无限木桩", "primary", func(): _spawn_dummies(3, TrainingDummy.ResetMode.INFINITE, true))
	_add_action_btn(dummy_grid, "放 3 个可击破木桩(5000HP)", "dark_gold", func(): _spawn_dummies(3, TrainingDummy.ResetMode.DESTRUCTIBLE, false))
	_add_action_btn(dummy_grid, "重置木桩血量与DPS", "secondary", _on_reset_dummies)
	_add_action_btn(dummy_grid, "清空场上所有单位", "cinnabar", _on_clear_enemies)
	_invincible_btn = _add_action_btn(dummy_grid, "玩家无敌：开", "primary", _on_toggle_invincible)

	body.add_child(_make_section_label("二、切换人物（自动读取 characters_v2.json）"))
	var char_grid := GridContainer.new()
	char_grid.columns = 4
	char_grid.add_theme_constant_override("h_separation", 8)
	char_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(char_grid)
	_char_btns.clear()
	for c in CharacterData.all():
		var cid := String(c.get("id", ""))
		var btn := _add_action_btn(char_grid, "%s · %s" % [String(c.get("name", "")), String(c.get("role", ""))], "secondary", func(): _on_switch_character(cid))
		_char_btns[cid] = btn

	body.add_child(_make_section_label("三、切换试验场地（自动读取 stages_v2.json）"))
	var stage_grid := GridContainer.new()
	stage_grid.columns = 3
	stage_grid.add_theme_constant_override("h_separation", 8)
	stage_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(stage_grid)
	_stage_btns.clear()
	for st in _loader.stages:
		var sid := int(st.get("id", 1))
		var sname := String(st.get("name", "秘境 %d" % sid))
		var sbtn := _add_action_btn(stage_grid, "第%d境 · %s" % [sid, sname], "secondary", func(): _on_switch_stage(sid))
		_stage_btns[sid] = sbtn

	return body.get_parent() as Control

func _build_weapons_tab(parent: Control) -> Control:
	var body := _make_scroll_page(parent)

	var quick_bar := HBoxContainer.new()
	quick_bar.add_theme_constant_override("separation", 8)
	body.add_child(quick_bar)
	_add_action_btn(quick_bar, "全开槽位", "primary", _on_unlock_all_slots)
	_add_action_btn(quick_bar, "已装备全满Lv.%d" % OrbitWeaponRig.MAX_WEAPON_TIER, "primary", _on_max_equipped_weapons)
	_add_action_btn(quick_bar, "清空法宝", "cinnabar", _on_clear_weapons)

	body.add_child(_make_section_label("一、合体超武一键测试（自动读取 fusion_recipes）"))
	var fusion_grid := GridContainer.new()
	fusion_grid.columns = 2
	fusion_grid.add_theme_constant_override("h_separation", 8)
	fusion_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(fusion_grid)
	for recipe in _loader.fusion_recipes:
		var ings: Array = recipe.get("ingredients", [])
		var req_tier := int(recipe.get("required_tier", OrbitWeaponRig.MAX_WEAPON_TIER))
		var ing_names: Array[String] = []
		for wid in ings:
			var w: Dictionary = _loader.weapons_by_id.get(String(wid), {})
			ing_names.append(String(w.get("name", String(wid))))
		var label_str := "%s（%s Lv.%d）" % [String(recipe.get("name", "")), " + ".join(ing_names), req_tier]
		var ing_copy := ings.duplicate()
		_add_action_btn(fusion_grid, label_str, "primary", func(): _apply_preset(ing_copy, req_tier))

	body.add_child(_make_section_label("二、全部基础法宝（自动读取 weapons_v2.json）"))
	var w_box := VBoxContainer.new()
	w_box.add_theme_constant_override("separation", 5)
	body.add_child(w_box)
	_weapon_rows.clear()
	for wid in _loader.weapons_by_id.keys():
		var w: Dictionary = _loader.weapons_by_id[wid]
		var w_id := String(wid)
		var row_plate := PanelContainer.new()
		row_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD_SOFT, 6, 8))
		w_box.add_child(row_plate)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_plate.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 15)
		info.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
		row.add_child(info)

		var add_btn := _add_fixed_btn(row, "+1级", 72, "secondary", func(): _on_step_weapon(w_id, 1))
		add_btn.size_flags_horizontal = 0
		var max_btn := _add_fixed_btn(row, "直满Lv.%d" % OrbitWeaponRig.MAX_WEAPON_TIER, 96, "primary", func(): _on_set_weapon_max(w_id))
		max_btn.size_flags_horizontal = 0
		var rem_btn := _add_fixed_btn(row, "移除", 68, "cinnabar", func(): _on_remove_weapon(w_id))
		rem_btn.size_flags_horizontal = 0

		_weapon_rows[w_id] = {
			"name": String(w.get("name", w_id)),
			"elem": String(w.get("element", "")),
			"label": info,
			"rem_btn": rem_btn,
		}

	return body.get_parent() as Control

func _build_items_arcana_tab(parent: Control) -> Control:
	var body := _make_scroll_page(parent)

	var quick_bar := HBoxContainer.new()
	quick_bar.add_theme_constant_override("separation", 8)
	body.add_child(quick_bar)
	_add_action_btn(quick_bar, "清空秘宝", "cinnabar", _on_clear_items)
	_add_action_btn(quick_bar, "清空道韵", "cinnabar", _on_clear_arcanas)

	body.add_child(_make_section_label("一、全部秘宝（自动读取 items_v2.json）"))
	var i_box := VBoxContainer.new()
	i_box.add_theme_constant_override("separation", 5)
	body.add_child(i_box)
	_item_rows.clear()
	for iid in _loader.items_by_id.keys():
		var it: Dictionary = _loader.items_by_id[iid]
		var item_id := String(iid)
		var row_plate := PanelContainer.new()
		row_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD_SOFT, 6, 8))
		i_box.add_child(row_plate)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_plate.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 14)
		info.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
		row.add_child(info)

		var plus_btn := _add_fixed_btn(row, "+1", 60, "primary", func(): _on_add_item(item_id))
		plus_btn.size_flags_horizontal = 0
		var minus_btn := _add_fixed_btn(row, "-1", 60, "cinnabar", func(): _on_remove_item(item_id))
		minus_btn.size_flags_horizontal = 0

		_item_rows[item_id] = {
			"name": String(it.get("name", item_id)),
			"desc": String(it.get("desc", "")),
			"max": int(it.get("max_stacks", 0)),
			"label": info,
			"plus_btn": plus_btn,
			"minus_btn": minus_btn,
		}

	body.add_child(_make_section_label("二、天道道韵开关（自动读取 arcana_v2.json）"))
	var a_box := VBoxContainer.new()
	a_box.add_theme_constant_override("separation", 5)
	body.add_child(a_box)
	_arcana_rows.clear()
	for arc in _loader.arcanas:
		var aid := String(arc.get("id", ""))
		if aid.is_empty():
			continue
		var row_plate := PanelContainer.new()
		row_plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD_SOFT, 6, 8))
		a_box.add_child(row_plate)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_plate.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 14)
		info.add_theme_color_override("font_color", XianxiaUITheme.COL_WARM_TEXT)
		row.add_child(info)

		var toggle_btn := _add_fixed_btn(row, "启用", 88, "secondary", func(): _on_toggle_arcana(aid))
		toggle_btn.size_flags_horizontal = 0

		_arcana_rows[aid] = {
			"name": String(arc.get("name", aid)),
			"desc": String(arc.get("desc", "")),
			"label": info,
			"btn": toggle_btn,
		}

	return body.get_parent() as Control

func _build_reactions_pickups_tab(parent: Control) -> Control:
	var body := _make_scroll_page(parent)

	body.add_child(_make_section_label("一、五行反应一键配装（自动匹配 reactions_v2.json 对应元素法宝）"))
	var rx_grid := GridContainer.new()
	rx_grid.columns = 2
	rx_grid.add_theme_constant_override("h_separation", 8)
	rx_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(rx_grid)
	for pk in _loader.reactions_by_key.keys():
		var rx: Dictionary = _loader.reactions_by_key[pk]
		var pair: Array = rx.get("pair", [])
		var matched: Array = _find_weapons_for_elements(pair)
		var btn_txt := "%s（%s）" % [String(rx.get("name", pk)), " + ".join(pair)]
		var btn := _add_action_btn(rx_grid, btn_txt, "dark_gold", func(): _apply_preset(matched, OrbitWeaponRig.MAX_WEAPON_TIER))
		btn.disabled = matched.is_empty()

	body.add_child(_make_section_label("二、世界掉落物生成测试（自动读取 pickups_v2.json）"))
	var pk_grid := GridContainer.new()
	pk_grid.columns = 3
	pk_grid.add_theme_constant_override("h_separation", 8)
	pk_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(pk_grid)
	for p_item in _loader.pickups:
		var pid := String(p_item.get("id", ""))
		if pid.is_empty():
			continue
		_add_action_btn(pk_grid, "生成 %s" % String(p_item.get("name", pid)), "secondary", func(): _on_spawn_pickup(pid))

	body.add_child(_make_section_label("三、单个敌方原型靶标（按需放 1 只测抗性/机制，非刷怪波次）"))
	var arch_grid := GridContainer.new()
	arch_grid.columns = 3
	arch_grid.add_theme_constant_override("h_separation", 8)
	arch_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(arch_grid)
	for arch_id in _loader.enemy_archetypes.keys():
		var arch: Dictionary = _loader.enemy_archetypes[arch_id]
		var aid := String(arch_id)
		_add_action_btn(arch_grid, "放1只 %s" % String(arch.get("name", aid)), "secondary", func(): _on_spawn_archetype(aid))

	return body.get_parent() as Control

func _find_weapons_for_elements(elems: Array) -> Array:
	var out: Array = []
	for raw_e in elems:
		var elem := String(raw_e)
		for wid in _loader.weapons_by_id.keys():
			var w: Dictionary = _loader.weapons_by_id[wid]
			if String(w.get("element", "")) == elem and not out.has(String(wid)):
				out.append(String(wid))
				break
	return out

func _switch_tab(idx: int) -> void:
	_active_tab = clampi(idx, 0, _tab_pages.size() - 1)
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == _active_tab)
	for i in range(_tab_btns.size()):
		XianxiaUITheme.style_button(_tab_btns[i], "primary" if i == _active_tab else "secondary")

func _make_section_label(text_str: String) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	return lbl

func _add_action_btn(parent: Container, text_str: String, variant: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 34)
	XianxiaUITheme.style_button(btn, variant)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _add_fixed_btn(parent: Container, text_str: String, w: float, variant: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(w, 30)
	XianxiaUITheme.style_button(btn, variant)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _get_v2() -> V2CombatController:
	if _player != null and "v2_combat" in _player:
		return _player.v2_combat as V2CombatController
	return null

func _ensure_all_slots(v2: V2CombatController) -> void:
	if v2 == null or v2.orbit_rig == null:
		return
	v2.unlocked_weapon_slots = v2.get_max_weapon_slots()
	v2.orbit_rig.set_unlocked_slots(v2.unlocked_weapon_slots)

func _refresh_ui() -> void:
	var v2 := _get_v2()
	var cur_cid := String(_player.character_id) if _player != null else ""
	for cid in _char_btns.keys():
		XianxiaUITheme.style_button(_char_btns[cid] as Button, "primary" if String(cid) == cur_cid else "secondary")
	for sid in _stage_btns.keys():
		XianxiaUITheme.style_button(_stage_btns[sid] as Button, "primary" if int(sid) == _active_stage_id else "secondary")
	for wid in _weapon_rows.keys():
		var row: Dictionary = _weapon_rows[wid]
		var lv := 0
		if v2 != null and v2.orbit_rig != null:
			lv = v2.orbit_rig.get_weapon_tier(String(wid))
		var status := "Lv.%d" % lv if lv > 0 else "未装备"
		(row["label"] as Label).text = "%s [%s] · %s" % [String(row["name"]), String(row["elem"]), status]
		(row["rem_btn"] as Button).disabled = lv <= 0
	for iid in _item_rows.keys():
		var row: Dictionary = _item_rows[iid]
		var cnt := v2.get_item_count(String(iid)) if v2 != null else 0
		var cap := int(row["max"])
		var cap_txt := "%d/%d" % [cnt, cap] if cap > 0 else "%d" % cnt
		(row["label"] as Label).text = "%s (%s) · %s" % [String(row["name"]), cap_txt, String(row["desc"])]
		(row["plus_btn"] as Button).disabled = (cap > 0 and cnt >= cap)
		(row["minus_btn"] as Button).disabled = cnt <= 0
	for aid in _arcana_rows.keys():
		var row: Dictionary = _arcana_rows[aid]
		var active := v2 != null and v2.has_arcana(String(aid))
		(row["label"] as Label).text = "%s · %s" % [String(row["name"]), String(row["desc"])]
		var btn := row["btn"] as Button
		btn.text = "已启用" if active else "启用"
		XianxiaUITheme.style_button(btn, "primary" if active else "secondary")
	if _status_lbl != null and _player != null:
		var slots_cnt := v2.orbit_rig.slots.size() if (v2 != null and v2.orbit_rig != null) else 0
		var max_slots := v2.get_unlocked_slots() if v2 != null else 1
		var dmg_m := int(round(v2.get_damage_mult() * 100.0)) if v2 != null else 100
		var spd_m := int(round(v2.get_attack_speed_mult() * 100.0)) if v2 != null else 100
		_status_lbl.text = "槽位:%d/%d | 伤:%d%% | 速:%d%% | 道韵:%d" % [slots_cnt, max_slots, dmg_m, spd_m, v2.active_arcanas.size() if v2 != null else 0]
	if _invincible_btn != null and _player != null:
		_invincible_btn.text = "玩家无敌：%s" % ("开" if _player.debug_invincible else "关")
		XianxiaUITheme.style_button(_invincible_btn, "primary" if _player.debug_invincible else "secondary")

func _on_switch_character(cid: String) -> void:
	if _player != null and _player.has_method("debug_switch_character"):
		_player.debug_switch_character(cid)
	_refresh_ui()

func _on_switch_stage(stage_id: int) -> void:
	_active_stage_id = stage_id
	if _main != null and _main.has_method("switch_stage"):
		_main.call("switch_stage", stage_id)
	_refresh_ui()

func _on_unlock_all_slots() -> void:
	_ensure_all_slots(_get_v2())
	_refresh_ui()

func _on_clear_weapons() -> void:
	var v2 := _get_v2()
	if v2 == null or v2.orbit_rig == null:
		return
	for i in range(v2.orbit_rig.slots.size() - 1, -1, -1):
		v2.orbit_rig.sell_weapon(i)
	_refresh_ui()

func _on_max_equipped_weapons() -> void:
	var v2 := _get_v2()
	if v2 == null or v2.orbit_rig == null:
		return
	var ids: Array[String] = []
	for s in v2.orbit_rig.slots:
		if not bool(s.get("is_fusion", false)):
			ids.append(String(s.get("id", "")))
	for wid in ids:
		v2.orbit_rig.upgrade_weapon(wid, OrbitWeaponRig.MAX_WEAPON_TIER)
	_refresh_ui()

func _on_step_weapon(wid: String, step: int) -> void:
	var v2 := _get_v2()
	if v2 == null or v2.orbit_rig == null:
		return
	_ensure_all_slots(v2)
	if v2.orbit_rig.find_weapon_slot(wid) != -1:
		v2.orbit_rig.upgrade_weapon(wid, step)
	else:
		v2.orbit_rig.add_weapon(wid, step)
	_refresh_ui()

func _on_set_weapon_max(wid: String) -> void:
	_on_step_weapon(wid, OrbitWeaponRig.MAX_WEAPON_TIER)

func _on_remove_weapon(wid: String) -> void:
	var v2 := _get_v2()
	if v2 == null or v2.orbit_rig == null:
		return
	var idx := v2.orbit_rig.find_weapon_slot(wid)
	if idx != -1:
		v2.orbit_rig.sell_weapon(idx)
	_refresh_ui()

func _apply_preset(weapon_ids: Array, target_tier: int) -> void:
	var v2 := _get_v2()
	if v2 == null or v2.orbit_rig == null:
		return
	_ensure_all_slots(v2)
	for i in range(v2.orbit_rig.slots.size() - 1, -1, -1):
		v2.orbit_rig.sell_weapon(i)
	for wid in weapon_ids:
		v2.orbit_rig.add_weapon(String(wid), target_tier)
	_refresh_ui()

func _on_add_item(iid: String) -> void:
	var v2 := _get_v2()
	if v2 != null:
		v2.add_item(iid)
	_refresh_ui()

func _on_remove_item(iid: String) -> void:
	var v2 := _get_v2()
	if v2 != null and v2.has_method("remove_item"):
		v2.remove_item(iid)
	_refresh_ui()

func _on_clear_items() -> void:
	var v2 := _get_v2()
	if v2 != null and v2.has_method("clear_items"):
		v2.clear_items()
	_refresh_ui()

func _on_toggle_arcana(aid: String) -> void:
	var v2 := _get_v2()
	if v2 == null:
		return
	if v2.has_arcana(aid):
		if v2.has_method("remove_arcana"):
			v2.remove_arcana(aid)
	else:
		v2.add_arcana(aid)
	_refresh_ui()

func _on_clear_arcanas() -> void:
	var v2 := _get_v2()
	if v2 == null:
		return
	for aid in v2.active_arcanas.duplicate():
		if v2.has_method("remove_arcana"):
			v2.remove_arcana(String(aid))
	_refresh_ui()

func _on_spawn_pickup(pid: String) -> void:
	if _player == null or _player.get_parent() == null:
		return
	var scene := load("res://scenes/world_pickup.tscn") as PackedScene
	if scene == null:
		return
	var pk := scene.instantiate() as WorldPickup
	if pk == null:
		return
	pk.global_position = _player.global_position + Vector2(110.0, randf_range(-40.0, 40.0))
	_player.get_parent().add_child(pk)
	pk.setup(pid)

func _on_spawn_archetype(aid: String) -> void:
	if _main != null and _main.has_method("spawn_specimen"):
		_main.call("spawn_specimen", aid)

func _spawn_dummies(count: int, mode: int, clear_first: bool) -> void:
	if clear_first and _main != null and _main.has_method("clear_dummies"):
		_main.call("clear_dummies")
	if _main != null and _main.has_method("spawn_dummies"):
		_main.call("spawn_dummies", count, mode)

func _on_reset_dummies() -> void:
	if _main != null and _main.has_method("reset_dummies"):
		_main.call("reset_dummies")

func _on_clear_enemies() -> void:
	if _main != null and _main.has_method("clear_all_targets"):
		_main.call("clear_all_targets")

func _on_toggle_invincible() -> void:
	if _player != null:
		_player.debug_invincible = not _player.debug_invincible
	_refresh_ui()
