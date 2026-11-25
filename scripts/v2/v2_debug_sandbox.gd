class_name V2DebugSandbox
extends CanvasLayer

signal closed

var _main: Node = null
var _player: Player = null
var _spawner: Node = null
var _paused_by_sandbox: bool = false

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _status_lbl: Label = null
var _char_btns: Dictionary = {}
var _weapon_rows: Dictionary = {}
var _invincible_btn: Button = null
var _pause_spawn_btn: Button = null

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

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
	_panel.offset_left = -520.0
	_panel.offset_right = 520.0
	_panel.offset_top = -325.0
	_panel.offset_bottom = 325.0
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
	title.text = "秘境调试沙盒 (F9)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	header.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 14)
	_status_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_INK_MUTED)
	header.add_child(_status_lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭 (F9)"
	close_btn.custom_minimum_size = Vector2(110, 34)
	XianxiaUITheme.style_button(close_btn, "cinnabar")
	close_btn.pressed.connect(close_panel)
	header.add_child(close_btn)

	var quick_bar := HBoxContainer.new()
	quick_bar.add_theme_constant_override("separation", 6)
	root_box.add_child(quick_bar)

	_add_action_btn(quick_bar, "全开4槽", "primary", _on_unlock_all_slots)
	_add_action_btn(quick_bar, "已装备全Lv.8", "primary", _on_max_equipped_weapons)
	_add_action_btn(quick_bar, "清空法宝", "secondary", _on_clear_weapons)
	_add_action_btn(quick_bar, "+500灵石", "dark_gold", _on_add_gold)
	_add_action_btn(quick_bar, "升级+5", "dark_gold", _on_level_up_five)
	_add_action_btn(quick_bar, "开商店", "secondary", _on_open_shop_now)
	_add_action_btn(quick_bar, "开宝箱", "secondary", _on_open_chest_now)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	body.add_child(_make_section_label("一、切换人物（即时生效）"))
	var char_grid := GridContainer.new()
	char_grid.columns = 4
	char_grid.add_theme_constant_override("h_separation", 8)
	char_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(char_grid)
	for c in CharacterData.all():
		var cid := String(c.get("id", ""))
		var btn := Button.new()
		btn.text = "%s · %s" % [String(c.get("name", "")), String(c.get("role", ""))]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.pressed.connect(func(): _on_switch_character(cid))
		XianxiaUITheme.style_button(btn, "secondary")
		char_grid.add_child(btn)
		_char_btns[cid] = btn

	body.add_child(_make_section_label("二、合体超武 & 多元素反应一键预设"))
	var preset_grid := GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 8)
	preset_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(preset_grid)
	_add_action_btn(preset_grid, "诛仙烈焰剑阵（剑+火 Lv.8 合体）", "primary", func(): _apply_preset(["wpn_jade_sword", "wpn_fire_gourd"], 8))
	_add_action_btn(preset_grid, "九霄雷冰天域（雷+冰 Lv.8 合体）", "primary", func(): _apply_preset(["wpn_thunder_talisman", "wpn_ice_mirror"], 8))
	_add_action_btn(preset_grid, "镇岳枯荣梵钟（钟+毒 Lv.8 合体）", "primary", func(): _apply_preset(["wpn_gold_bell", "wpn_venom_banner"], 8))
	_add_action_btn(preset_grid, "四元素反应靶组（火+水+雷+藤 Lv.8）", "dark_gold", func(): _apply_preset(["wpn_fire_gourd", "wpn_jade_vase", "wpn_thunder_talisman", "wpn_spirit_vine"], 8))

	body.add_child(_make_section_label("三、法宝单选 / 升满级（Lv.8 质变特效）"))
	var w_box := VBoxContainer.new()
	w_box.add_theme_constant_override("separation", 5)
	body.add_child(w_box)

	var loader := V2DataLoader.new()
	loader.load_all("res://data/v2")
	for wid in loader.weapons_by_id.keys():
		var w: Dictionary = loader.weapons_by_id[wid]
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

		var add_btn := Button.new()
		add_btn.text = "+1级"
		add_btn.custom_minimum_size = Vector2(72, 30)
		XianxiaUITheme.style_button(add_btn, "secondary")
		add_btn.pressed.connect(func(): _on_step_weapon(w_id, 1))
		row.add_child(add_btn)

		var max_btn := Button.new()
		max_btn.text = "直满Lv.8"
		max_btn.custom_minimum_size = Vector2(96, 30)
		XianxiaUITheme.style_button(max_btn, "primary")
		max_btn.pressed.connect(func(): _on_set_weapon_max(w_id))
		row.add_child(max_btn)

		var rem_btn := Button.new()
		rem_btn.text = "移除"
		rem_btn.custom_minimum_size = Vector2(68, 30)
		XianxiaUITheme.style_button(rem_btn, "cinnabar")
		rem_btn.pressed.connect(func(): _on_remove_weapon(w_id))
		row.add_child(rem_btn)

		_weapon_rows[w_id] = {
			"name": String(w.get("name", w_id)),
			"elem": String(w.get("element", "")),
			"label": info,
			"rem_btn": rem_btn,
		}
	loader.free()

	body.add_child(_make_section_label("四、靶场测试（刷怪 / 木桩 / 无敌）"))
	var spawn_grid := GridContainer.new()
	spawn_grid.columns = 3
	spawn_grid.add_theme_constant_override("h_separation", 8)
	spawn_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(spawn_grid)
	_add_action_btn(spawn_grid, "刷 12 只小怪", "secondary", func(): _spawn_pack("minion", 12))
	_add_action_btn(spawn_grid, "刷 2 只精英", "secondary", func(): _spawn_pack("elite", 2))
	_add_action_btn(spawn_grid, "刷 3 个高血木桩(5000HP)", "dark_gold", func(): _spawn_pack("dummy", 3))
	_add_action_btn(spawn_grid, "清空非Boss怪物", "cinnabar", _on_clear_enemies)
	_invincible_btn = _add_action_btn(spawn_grid, "无敌：关", "secondary", _on_toggle_invincible)
	_pause_spawn_btn = _add_action_btn(spawn_grid, "刷怪：开启", "secondary", _on_toggle_spawning)

func _make_section_label(text_str: String) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 17)
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

func _get_v2() -> V2CombatController:
	if _player != null and "v2_combat" in _player:
		return _player.v2_combat as V2CombatController
	return null

func _ensure_4_slots(v2: V2CombatController) -> void:
	if v2 == null or v2.orbit_rig == null:
		return
	v2.unlocked_weapon_slots = v2.get_max_weapon_slots()
	v2.orbit_rig.set_unlocked_slots(v2.unlocked_weapon_slots)

func _refresh_ui() -> void:
	var v2 := _get_v2()
	var cur_cid := String(_player.character_id) if _player != null else ""
	for cid in _char_btns.keys():
		var b := _char_btns[cid] as Button
		var active := String(cid) == cur_cid
		XianxiaUITheme.style_button(b, "primary" if active else "secondary")
	for wid in _weapon_rows.keys():
		var row: Dictionary = _weapon_rows[wid]
		var lv := 0
		if v2 != null and v2.orbit_rig != null:
			lv = v2.orbit_rig.get_weapon_tier(String(wid))
		var status := "Lv.%d" % lv if lv > 0 else "未装备"
		(row["label"] as Label).text = "%s [%s] · %s" % [String(row["name"]), String(row["elem"]), status]
		(row["rem_btn"] as Button).disabled = lv <= 0
	if _status_lbl != null and _player != null:
		var gold := v2.run_gold if v2 != null else 0
		var slots_cnt := v2.orbit_rig.slots.size() if (v2 != null and v2.orbit_rig != null) else 0
		var max_slots := v2.get_unlocked_slots() if v2 != null else 1
		_status_lbl.text = "Lv.%d | 灵石:%d | 槽位:%d/%d" % [_player.level, gold, slots_cnt, max_slots]
	if _invincible_btn != null and _player != null:
		_invincible_btn.text = "无敌：%s" % ("开" if _player.debug_invincible else "关")
		XianxiaUITheme.style_button(_invincible_btn, "primary" if _player.debug_invincible else "secondary")
	if _pause_spawn_btn != null and _spawner != null and "debug_spawning_paused" in _spawner:
		var sp_paused := bool(_spawner.debug_spawning_paused)
		_pause_spawn_btn.text = "刷怪：%s" % ("暂停" if sp_paused else "开启")
		XianxiaUITheme.style_button(_pause_spawn_btn, "cinnabar" if sp_paused else "secondary")

func _on_switch_character(cid: String) -> void:
	if _player != null and _player.has_method("debug_switch_character"):
		_player.debug_switch_character(cid)
	_refresh_ui()

func _on_unlock_all_slots() -> void:
	var v2 := _get_v2()
	_ensure_4_slots(v2)
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
	_ensure_4_slots(v2)
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
	_ensure_4_slots(v2)
	for i in range(v2.orbit_rig.slots.size() - 1, -1, -1):
		v2.orbit_rig.sell_weapon(i)
	for wid in weapon_ids:
		v2.orbit_rig.add_weapon(String(wid), target_tier)
	_refresh_ui()

func _on_add_gold() -> void:
	var v2 := _get_v2()
	if v2 != null:
		v2.add_run_gold(500)
	_refresh_ui()

func _on_level_up_five() -> void:
	if _player == null:
		return
	for _i in range(5):
		_player.gain_exp(_player.exp_to_next_level)
	_refresh_ui()

func _on_open_shop_now() -> void:
	var v2 := _get_v2()
	if _main != null and v2 != null and "shop_ui" in _main and _main.shop_ui != null:
		close_panel()
		if GameFlow.request_upgrade():
			_main.shop_ui.open_shop(maxi(1, _player.level / 5), v2, {})

func _on_open_chest_now() -> void:
	if _main != null and "pending_chests" in _main:
		_main.pending_chests += 1
		close_panel()
		_main.call("_schedule_modal")

func _spawn_pack(kind: String, count: int) -> void:
	if _spawner != null and _spawner.has_method("debug_spawn_pack"):
		_spawner.debug_spawn_pack(kind, count)

func _on_clear_enemies() -> void:
	if _spawner != null and _spawner.has_method("debug_clear_enemies"):
		_spawner.debug_clear_enemies()

func _on_toggle_invincible() -> void:
	if _player != null:
		_player.debug_invincible = not _player.debug_invincible
	_refresh_ui()

func _on_toggle_spawning() -> void:
	if _spawner != null and "debug_spawning_paused" in _spawner:
		_spawner.debug_spawning_paused = not bool(_spawner.debug_spawning_paused)
	_refresh_ui()
