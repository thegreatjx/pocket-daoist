class_name V2ShopUI
extends CanvasLayer

signal closed

const ITEM_ICONS := {
	"item_spirit_stone": "res://assets/icons/relic_insight.png",
	"item_whetstone": "res://assets/icons/relic_bone.png",
	"item_jade_pendant": "res://assets/icons/relic_armor.png",
	"item_wind_talisman": "res://assets/icons/relic_wind.png",
	"item_five_element_compass": "res://assets/icons/icon_taichi_array.png",
	"item_lightning_rod": "res://assets/icons/icon_jiutian_thunder.png",
	"item_crimson_furnace": "res://assets/icons/relic_pill.png",
	"item_frost_core": "res://assets/icons/relic_luck.png",
	"item_dash_boots": "res://assets/icons/relic_boots.png",
	"item_magnet_gourd": "res://assets/icons/relic_magnet.png",
	"item_greed_abacus": "res://assets/sprites/pickup_spirit_pouch.png",
	"item_blood_lotus": "res://assets/icons/relic_pill.png",
	"item_lucky_coin": "res://assets/icons/relic_luck.png",
	"item_heavenly_dice": "res://assets/icons/relic_insight.png",
	"item_obsidian_mirror": "res://assets/icons/icon_taichi_array.png",
	"item_blood_talisman": "res://assets/icons/relic_pill.png",
}

const ELEM_NAMES := {
	"metal": "金",
	"wood": "木",
	"fire": "火",
	"thunder": "雷",
	"ice": "冰",
	"venom": "毒",
	"water": "水",
}

const TIER_ROMAN := ["", "Lv.1", "Lv.2", "Lv.3", "Lv.4", "Lv.5", "Lv.6", "Lv.7", "Lv.8", "仙"]

var is_showing: bool = false
var _v2: V2CombatController = null
var _wave: int = 1
var _reroll_count: int = 0
var _slots_data: Array[Dictionary] = []
var _banished_ids: Dictionary = {}

var _root_dim: ColorRect = null
var _panel: Panel = null
var _title_lbl: Label = null
var _gold_lbl: Label = null
var _stats_lbl: Label = null
var _cards_row: HBoxContainer = null
var _loadout_row: HBoxContainer = null
var _reroll_btn: Button = null
var _continue_btn: Button = null
var _detail_drawer: V2DetailDrawer = null
var _detail_offer_idx: int = -1

func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for _i in range(4):
		_slots_data.append({"locked": false, "sold": false, "kind": "", "id": "", "tier": 1, "price": 20})
	_build_ui()

func _build_ui() -> void:
	_root_dim = ColorRect.new()
	_root_dim.color = Color(0.03, 0.08, 0.07, 0.62)
	_root_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_dim)

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -500.0
	_panel.offset_right = 500.0
	_panel.offset_top = -315.0
	_panel.offset_bottom = 315.0
	_panel.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 0))
	XianxiaUITheme.attach_ornaments(_panel, XianxiaUITheme.COL_GOLD, 16.0, 7.0)
	_root_dim.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 10)
	margin.add_child(main_vb)

	var header := HBoxContainer.new()
	main_vb.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tf = load("res://assets/title_font.tres")
	if tf != null:
		_title_lbl.add_theme_font_override("font", tf)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(0.10, 0.28, 0.24))
	header.add_child(_title_lbl)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 24)
	_gold_lbl.add_theme_color_override("font_color", Color(0.74, 0.44, 0.06))
	header.add_child(_gold_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.add_theme_font_size_override("font_size", 15)
	_stats_lbl.add_theme_color_override("font_color", Color(0.18, 0.34, 0.30))
	main_vb.add_child(_stats_lbl)

	_cards_row = HBoxContainer.new()
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 12)
	main_vb.add_child(_cards_row)

	var sep_lbl := Label.new()
	sep_lbl.text = "当前携带法宝（单件购买即淬炼升阶 · 点击可 55%% 折价出售）"
	sep_lbl.add_theme_font_size_override("font_size", 14)
	sep_lbl.add_theme_color_override("font_color", Color(0.28, 0.38, 0.34))
	main_vb.add_child(sep_lbl)

	_loadout_row = HBoxContainer.new()
	_loadout_row.custom_minimum_size = Vector2(0, 74)
	_loadout_row.add_theme_constant_override("separation", 8)
	main_vb.add_child(_loadout_row)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	main_vb.add_child(footer)

	_reroll_btn = Button.new()
	_reroll_btn.text = "重随"
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.add_theme_font_size_override("font_size", 18)
	XianxiaUITheme.style_button(_reroll_btn, "primary")
	_reroll_btn.custom_minimum_size = Vector2(210, 44)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	footer.add_child(_reroll_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "继续诛魔"
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_continue_btn.add_theme_font_size_override("font_size", 18)
	XianxiaUITheme.style_button(_continue_btn, "cinnabar")
	_continue_btn.custom_minimum_size = Vector2(250, 44)
	_continue_btn.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_btn)

	_detail_drawer = V2DetailDrawer.new()
	_detail_drawer.name = "V2DetailDrawer"
	_detail_drawer.confirm_action_requested.connect(_on_detail_confirm_pressed)
	_detail_drawer.closed.connect(func(): _detail_offer_idx = -1)
	_root_dim.add_child(_detail_drawer)

func _make_btn(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	return b

func open_shop(wave: int, v2: V2CombatController, banished: Dictionary = {}) -> void:
	_wave = maxi(1, wave)
	_v2 = v2
	_reroll_count = 0
	_banished_ids = banished.duplicate()
	is_showing = true
	visible = true
	_roll_unlocked_slots()
	_refresh_view()

func hide_panel() -> void:
	close_detail_drawer()
	visible = false
	is_showing = false

func open_offer_detail(idx: int) -> bool:
	if _detail_drawer == null or _v2 == null or idx < 0 or idx >= _slots_data.size():
		return false
	var offer := _slots_data[idx]
	if bool(offer.get("sold", false)):
		return false
	var kind := String(offer.get("kind", ""))
	var item_id := String(offer.get("id", ""))
	var tier := int(offer.get("tier", 1))
	var price := int(offer.get("price", 0))
	var detail := {}
	var can_buy := _v2.run_gold >= price
	if kind == "temper":
		var cur_lv := _v2.orbit_rig.get_weapon_tier(item_id) if _v2.orbit_rig != null else 0
		detail = V2DetailDrawer.build_weapon_detail(_v2, item_id, mini(OrbitWeaponRig.MAX_WEAPON_TIER, cur_lv + 1))
		can_buy = can_buy and _v2.orbit_rig != null and _v2.orbit_rig.can_upgrade_weapon(item_id)
	elif kind == "weapon":
		detail = V2DetailDrawer.build_weapon_detail(_v2, item_id, tier)
		can_buy = can_buy and _v2.can_add_weapon(item_id, tier)
	elif kind == "item":
		detail = V2DetailDrawer.build_item_detail(_v2, item_id)
	if detail.is_empty():
		return false
	_detail_offer_idx = idx
	_detail_drawer.open_detail(detail, "购买 (%d 灵石)" % price, can_buy)
	return true

func open_owned_weapon_detail(weapon_id: String, current_tier: int) -> bool:
	if _detail_drawer == null or _v2 == null:
		return false
	var detail := V2DetailDrawer.build_weapon_detail(_v2, weapon_id, current_tier)
	if detail.is_empty():
		return false
	_detail_offer_idx = -1
	_detail_drawer.open_detail(detail, "", false)
	return true

func close_detail_drawer() -> void:
	_detail_offer_idx = -1
	if _detail_drawer != null:
		_detail_drawer.close_detail()

func get_detail_drawer() -> V2DetailDrawer:
	return _detail_drawer

func _on_detail_confirm_pressed() -> void:
	var target_idx := _detail_offer_idx
	if target_idx < 0:
		return
	close_detail_drawer()
	_on_buy_offer(target_idx)

func _input(event: InputEvent) -> void:
	if not is_showing or not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE and _detail_drawer != null and _detail_drawer.is_open:
			get_viewport().set_input_as_handled()
			close_detail_drawer()

func _reroll_cost() -> int:
	if _v2 != null and _v2.loader != null:
		var eco := _v2.loader.shop_economy
		var base := int(eco.get("base_reroll_cost", 4))
		var per_w := int(eco.get("reroll_cost_per_wave", 2))
		var step := int(eco.get("reroll_escalation_step", 3))
		return base + _wave * per_w + _reroll_count * step
	return 4 + _wave * 2 + _reroll_count * 3

func _pick_weighted_candidate(cands: Array[Dictionary]) -> Dictionary:
	if cands.is_empty():
		return {}
	var total_w := 0.0
	for c in cands:
		total_w += maxf(0.1, float(c.get("weight", 1.0)))
	var r := randf() * total_w
	var acc := 0.0
	for c in cands:
		acc += maxf(0.1, float(c.get("weight", 1.0)))
		if r <= acc:
			return c
	return cands[cands.size() - 1]

func _build_item_candidates(luck: float, used_keys: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for iid_raw in _v2.loader.items_by_id.keys():
		var iid := String(iid_raw)
		if _banished_ids.has(iid) or used_keys.has("item:" + iid):
			continue
		if not _v2.can_add_item(iid):
			continue
		var it: Dictionary = _v2.loader.items_by_id[iid_raw]
		var w := 10.0
		var rarity := int(it.get("rarity", 1))
		if rarity == 2:
			w *= (0.65 + 0.55 * luck)
		elif rarity >= 3:
			w *= (0.35 + 0.65 * luck)
		if V2CombatController.item_has_tradeoff(it):
			w *= 1.30
		out.append({
			"kind": "item",
			"id": iid,
			"tier": 1,
			"price": int(it.get("cost", 24)),
			"weight": w,
		})
	return out

func _build_temper_candidates(used_keys: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _v2.orbit_rig == null:
		return out
	for slot in _v2.orbit_rig.slots:
		if bool(slot.get("is_fusion", false)):
			continue
		var wid := String(slot.get("id", ""))
		if _banished_ids.has("v2_wpn:" + wid) or used_keys.has("wpn:" + wid):
			continue
		if not _v2.orbit_rig.can_upgrade_weapon(wid):
			continue
		var cur_lv := int(slot.get("tier", 1))
		out.append({
			"kind": "temper",
			"id": wid,
			"tier": mini(OrbitWeaponRig.MAX_WEAPON_TIER, cur_lv + 1),
			"price": _v2.get_temper_price(wid, cur_lv),
			"weight": _v2.get_weapon_offer_weight(wid),
		})
	return out

func _build_new_weapon_candidates(luck: float, used_keys: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _v2.orbit_rig == null:
		return out
	var has_slot := _v2.orbit_rig.has_free_slot()
	var p2 := clampf(float(_wave - 2) * 0.08 * luck, 0.0, 0.45)
	for wid_raw in _v2.loader.weapons_by_id.keys():
		var wid := String(wid_raw)
		if _banished_ids.has("v2_wpn:" + wid) or used_keys.has("wpn:" + wid):
			continue
		if _v2.orbit_rig.get_weapon_tier(wid) > 0:
			continue
		var tier := 2 if (has_slot and randf() < p2) else 1
		if not has_slot:
			continue
		elif not _v2.can_add_weapon(wid, tier):
			continue
		out.append({
			"kind": "weapon",
			"id": wid,
			"tier": tier,
			"price": _v2.get_weapon_price(wid, tier, false),
			"weight": _v2.get_weapon_offer_weight(wid),
		})
	return out

func _pick_from_priority(order: Array[String], luck: float, used_keys: Dictionary) -> Dictionary:
	for cat in order:
		var cands: Array[Dictionary] = []
		match cat:
			"item":
				cands = _build_item_candidates(luck, used_keys)
			"temper":
				cands = _build_temper_candidates(used_keys)
			"weapon":
				cands = _build_new_weapon_candidates(luck, used_keys)
		if not cands.is_empty():
			return _pick_weighted_candidate(cands)
	return {}

func _roll_unlocked_slots() -> void:
	if _v2 == null or _v2.loader == null:
		return
	var luck := _v2.get_luck()
	var used_keys := {}
	for cur in _slots_data:
		if bool(cur.get("locked", false)) and not bool(cur.get("sold", false)) and String(cur.get("id", "")) != "":
			var ck := String(cur.get("kind", ""))
			var cid := String(cur.get("id", ""))
			if ck == "item":
				used_keys["item:" + cid] = true
			else:
				used_keys["wpn:" + cid] = true

	var slot_priorities: Array[Array] = [
		["item", "temper", "weapon"],
		["item", "temper", "weapon"],
		["temper", "weapon", "item"],
		["weapon", "temper", "item"],
	]

	for idx in range(_slots_data.size()):
		var cur := _slots_data[idx]
		if bool(cur.get("locked", false)) and not bool(cur.get("sold", false)) and String(cur.get("id", "")) != "":
			continue
		var order: Array[String] = ["item", "temper", "weapon"]
		if idx < slot_priorities.size():
			order.assign(slot_priorities[idx])
		var picked := _pick_from_priority(order, luck, used_keys)
		if picked.is_empty():
			_slots_data[idx] = {"locked": false, "sold": true, "kind": "", "id": "", "tier": 1, "price": 0}
			continue
		var pk := String(picked["kind"])
		var pid := String(picked["id"])
		if pk == "item":
			used_keys["item:" + pid] = true
		else:
			used_keys["wpn:" + pid] = true
		_slots_data[idx] = {
			"locked": false,
			"sold": false,
			"kind": pk,
			"id": pid,
			"tier": int(picked.get("tier", 1)),
			"price": int(picked.get("price", 20)),
		}

func _refresh_view() -> void:
	if _v2 == null or _v2.loader == null:
		return
	_title_lbl.text = "天机阁 · 第 %d 波行商" % _wave
	_gold_lbl.text = "灵石：%d" % _v2.run_gold
	var sm := _v2.get_stats_summary()
	_stats_lbl.text = "战力概览：伤害 +%d%%  |  攻速 +%d%%  |  暴击 %d%%  |  元素精通 +%d%%  |  闪避 %d%%  |  机缘 %d%%" % [
		int(sm["dmg_pct"]), int(sm["spd_pct"]), int(sm["crit_pct"]),
		int(sm["mastery_pct"]), int(sm["dodge_pct"]), int(sm.get("luck_pct", 100)),
	]
	var rc := _reroll_cost()
	_reroll_btn.text = "重随货架 (%d 灵石)" % rc
	_reroll_btn.disabled = _v2.run_gold < rc
	_continue_btn.text = "继续诛魔（第 %d 波）" % (_wave + 1)

	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	for idx in range(_slots_data.size()):
		_cards_row.add_child(_build_offer_card(idx, _slots_data[idx]))

	for c in _loadout_row.get_children():
		_loadout_row.remove_child(c)
		c.queue_free()
	var slots := _v2.orbit_rig.slots if _v2.orbit_rig != null else []
	var unlocked := _v2.get_unlocked_slots()
	var realm_by_slot := {}
	for entry in _v2.get_realm_table():
		realm_by_slot[int(entry.get("slots", 0))] = entry
	for i in range(_v2.get_max_weapon_slots()):
		if i < slots.size():
			_loadout_row.add_child(_build_owned_slot(i, slots[i], slots.size() > 1))
		elif i < unlocked:
			_loadout_row.add_child(_build_empty_owned_slot())
		else:
			var unlock_entry: Dictionary = realm_by_slot.get(i + 1, {})
			var unlock_lv := int(unlock_entry.get("level", 0))
			var unlock_realm := String(unlock_entry.get("realm", ""))
			var unlock_text := "未解锁"
			if unlock_lv > 0:
				unlock_text = "Lv.%d %s解锁" % [unlock_lv, unlock_realm]
			_loadout_row.add_child(_build_empty_owned_slot(unlock_text, true))

func _build_offer_card(idx: int, offer: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sold := bool(offer.get("sold", false))
	var locked := bool(offer.get("locked", false))
	var kind := String(offer.get("kind", ""))
	var item_id := String(offer.get("id", ""))
	var tier := int(offer.get("tier", 1))
	var price := int(offer.get("price", 20))

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.92, 0.90, 0.84, 0.72) if sold else Color(1.0, 0.98, 0.93, 1.0)
	st.set_border_width_all(2)
	st.border_color = Color(0.86, 0.62, 0.16) if locked else Color(0.22, 0.58, 0.50)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	if sold:
		var done_lbl := Label.new()
		done_lbl.text = "已收入囊中"
		done_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		done_lbl.add_theme_font_size_override("font_size", 20)
		done_lbl.add_theme_color_override("font_color", Color(0.42, 0.48, 0.45))
		vb.add_child(done_lbl)
		return card

	var tag := ""
	var title := ""
	var desc := ""
	var icon_path := ""
	var syn_text := ""
	var can_buy := _v2.run_gold >= price

	if kind == "temper" and _v2.loader.weapons_by_id.has(item_id):
		var w: Dictionary = _v2.loader.weapons_by_id[item_id]
		var elem := String(w.get("element", "metal"))
		var cur_lv := _v2.orbit_rig.get_weapon_tier(item_id) if _v2.orbit_rig != null else 0
		var next_lv := mini(OrbitWeaponRig.MAX_WEAPON_TIER, cur_lv + 1)
		tag = "【%s · 淬炼 Lv.%d→Lv.%d】" % [String(ELEM_NAMES.get(elem, "法")), cur_lv, next_lv]
		title = String(w.get("name", item_id))
		icon_path = String(w.get("icon", ""))
		var tiers: Array = w.get("tiers", [])
		var t_stat: Dictionary = tiers[clampi(next_lv - 1, 0, tiers.size() - 1)] if not tiers.is_empty() else {}
		var summary := String(t_stat.get("level_summary", ""))
		desc = "%s\n伤害 %d | 冷却 %.2fs" % [summary, int(t_stat.get("damage", 15)), float(t_stat.get("cooldown", 1.0))]
		if cur_lv <= 0 or cur_lv >= OrbitWeaponRig.MAX_WEAPON_TIER or (_v2.orbit_rig != null and not _v2.orbit_rig.can_upgrade_weapon(item_id)):
			can_buy = false
			syn_text = "已满级或未持有该法宝"
		else:
			syn_text = "✦ 原地淬炼升阶，不占法宝槽"
	elif kind == "weapon" and _v2.loader.weapons_by_id.has(item_id):
		var w: Dictionary = _v2.loader.weapons_by_id[item_id]
		var elem := String(w.get("element", "metal"))
		tag = "【%s · %s】" % [String(ELEM_NAMES.get(elem, "法")), TIER_ROMAN[clampi(tier, 1, OrbitWeaponRig.MAX_WEAPON_TIER)]]
		title = String(w.get("name", item_id))
		icon_path = String(w.get("icon", ""))
		var tiers: Array = w.get("tiers", [])
		var t_stat: Dictionary = tiers[clampi(tier - 1, 0, tiers.size() - 1)] if not tiers.is_empty() else {}
		desc = "伤害 %d | 冷却 %.2fs" % [int(t_stat.get("damage", 15)), float(t_stat.get("cooldown", 1.0))]
		if t_stat.has("aoe_radius"):
			desc += "\n范围 %d" % int(t_stat["aoe_radius"])
		elif t_stat.has("chain_count"):
			desc += "\n弹射 %d 目标" % int(t_stat["chain_count"])
		elif t_stat.has("projectile_count"):
			desc += "\n%d 棱冰锥" % int(t_stat["projectile_count"])
		elif t_stat.has("pierce"):
			desc += "\n穿透 %d 敌" % int(t_stat["pierce"])
		var cur_tier := _v2.orbit_rig.get_weapon_tier(item_id) if _v2.orbit_rig != null else 0
		if cur_tier >= OrbitWeaponRig.MAX_WEAPON_TIER:
			can_buy = false
			syn_text = "已淬炼至 Lv.%d 满级" % OrbitWeaponRig.MAX_WEAPON_TIER
		elif cur_tier > 0:
			var target_lv := mini(OrbitWeaponRig.MAX_WEAPON_TIER, maxi(cur_tier + 1, tier))
			syn_text = "✦ 购买即淬炼升至 %s!" % TIER_ROMAN[target_lv]
		elif not _v2.can_add_weapon(item_id, tier):
			can_buy = false
			syn_text = "槽位未解锁/已满"
	elif kind == "item" and _v2.loader.items_by_id.has(item_id):
		var it: Dictionary = _v2.loader.items_by_id[item_id]
		var rarity := int(it.get("rarity", 1))
		var r_name := "凡品奇物" if rarity <= 1 else ("稀有奇物" if rarity == 2 else "绝品奇物")
		if V2CombatController.item_has_tradeoff(it):
			r_name += " · 权衡"
		tag = "【%s】" % r_name
		if not locked and not sold:
			if rarity >= 3:
				st.border_color = Color(0.68, 0.34, 0.72)
			elif rarity == 2:
				st.border_color = Color(0.20, 0.48, 0.76)
		title = String(it.get("name", item_id))
		desc = String(it.get("desc", ""))
		icon_path = String(ITEM_ICONS.get(item_id, "res://assets/icons/relic_insight.png"))

	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 4)
	vb.add_child(tag_row)

	var tag_lbl := Label.new()
	tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_lbl.custom_minimum_size = Vector2(10, 0)
	tag_lbl.clip_text = true
	tag_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tag_lbl.text = tag
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", Color(0.14, 0.48, 0.42))
	tag_row.add_child(tag_lbl)

	var detail_btn := _make_btn("详", Color(0.12, 0.34, 0.30), Color(0.86, 0.72, 0.34))
	detail_btn.tooltip_text = "查看详细数值与五行联动"
	detail_btn.custom_minimum_size = Vector2(32, 24)
	detail_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	detail_btn.add_theme_font_size_override("font_size", 13)
	detail_btn.pressed.connect(func():
		if _detail_drawer != null and _detail_drawer.is_open and _detail_offer_idx == idx:
			close_detail_drawer()
		else:
			open_offer_detail(idx)
	)
	tag_row.add_child(detail_btn)

	var mid_vb := VBoxContainer.new()
	mid_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vb.add_theme_constant_override("separation", 5)
	vb.add_child(mid_vb)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(0, 56)
		var bg_box := PanelContainer.new()
		bg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.10, 0.22, 0.20, 0.92)
		bst.set_corner_radius_all(8)
		bst.set_content_margin_all(4)
		bg_box.add_theme_stylebox_override("panel", bst)
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture = load(icon_path)
		tr.custom_minimum_size = Vector2(46, 46)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_box.add_child(tr)
		holder.add_child(bg_box)
		mid_vb.add_child(holder)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(10, 0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	mid_vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(10, 0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.16, 0.24, 0.22))
	mid_vb.add_child(desc_lbl)

	if syn_text != "":
		var syn_lbl := Label.new()
		syn_lbl.text = syn_text
		syn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		syn_lbl.custom_minimum_size = Vector2(10, 0)
		syn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		syn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		syn_lbl.add_theme_font_size_override("font_size", 13)
		syn_lbl.add_theme_color_override("font_color", Color(0.78, 0.24, 0.10))
		mid_vb.add_child(syn_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vb.add_child(btn_row)

	var buy_btn := _make_btn("购 %d" % price, Color(0.14, 0.44, 0.36), Color(0.90, 0.74, 0.32))
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.custom_minimum_size = Vector2(0, 34)
	buy_btn.add_theme_font_size_override("font_size", 15)
	buy_btn.disabled = not can_buy
	buy_btn.pressed.connect(func(): _on_buy_offer(idx))
	btn_row.add_child(buy_btn)

	var lock_btn := _make_btn("已锁" if locked else "锁定", Color(0.55, 0.38, 0.12) if locked else Color(0.24, 0.30, 0.28), Color(0.82, 0.72, 0.40))
	lock_btn.custom_minimum_size = Vector2(64, 34)
	lock_btn.add_theme_font_size_override("font_size", 14)
	lock_btn.pressed.connect(func():
		_slots_data[idx]["locked"] = not bool(_slots_data[idx]["locked"])
		_refresh_view()
	)
	btn_row.add_child(lock_btn)
	return card

func _build_owned_slot(slot_idx: int, slot: Dictionary, can_sell: bool) -> Control:
	var p := PanelContainer.new()
	p.clip_contents = true
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	var is_f := bool(slot["is_fusion"])
	st.bg_color = Color(0.32, 0.14, 0.10, 0.94) if is_f else Color(0.10, 0.24, 0.22, 0.94)
	st.border_color = Color(0.98, 0.78, 0.26) if is_f else Color(0.30, 0.76, 0.66)
	st.set_border_width_all(2 if is_f else 1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", st)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	p.add_child(hb)

	var sp := slot.get("sprite") as Sprite2D
	if sp != null and sp.texture != null:
		var tr := TextureRect.new()
		tr.texture = sp.texture
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var wid := String(slot["id"])
	var tier := int(slot["tier"])
	var w_name := wid
	if _v2.loader.weapons_by_id.has(wid):
		w_name = String(_v2.loader.weapons_by_id[wid]["name"])

	var lbl_btn := Button.new()
	lbl_btn.flat = true
	lbl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_btn.custom_minimum_size = Vector2(10, 0)
	lbl_btn.clip_text = true
	lbl_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_btn.text = "%s (%s)" % [w_name, TIER_ROMAN[9] if is_f else TIER_ROMAN[clampi(tier, 1, OrbitWeaponRig.MAX_WEAPON_TIER)]]
	lbl_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_btn.focus_mode = Control.FOCUS_NONE
	lbl_btn.add_theme_font_size_override("font_size", 13)
	lbl_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76))
	if not is_f:
		lbl_btn.pressed.connect(func(): open_owned_weapon_detail(wid, tier))
	else:
		lbl_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl_btn)

	var refund := maxi(5, int(round(float(_v2.get_weapon_price(wid, tier, is_f)) * float(_v2.loader.shop_economy.get("sell_refund_ratio", 0.55)))))
	var sell_btn := Button.new()
	sell_btn.text = "出售 +%d" % refund
	sell_btn.focus_mode = Control.FOCUS_NONE
	sell_btn.disabled = not can_sell
	sell_btn.add_theme_font_size_override("font_size", 12)
	XianxiaUITheme.style_button(sell_btn, "dark_gold")
	sell_btn.pressed.connect(func():
		_v2.sell_weapon(slot_idx)
		_refresh_view()
	)
	vb.add_child(sell_btn)
	return p

func _build_empty_owned_slot(label_text: String = "", locked: bool = false) -> Control:
	var p := PanelContainer.new()
	p.clip_contents = true
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	if locked:
		st.bg_color = Color(0.06, 0.13, 0.12, 0.35)
		st.border_color = Color(0.26, 0.38, 0.34, 0.40)
	else:
		st.bg_color = Color(0.10, 0.20, 0.18, 0.35)
		st.border_color = Color(0.36, 0.58, 0.52, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = label_text if label_text != "" else "空法宝槽"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(10, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.30, 0.42, 0.38) if locked else Color(0.35, 0.48, 0.44))
	p.add_child(lbl)
	return p

func _on_buy_offer(idx: int) -> void:
	if _v2 == null or idx < 0 or idx >= _slots_data.size():
		return
	var offer := _slots_data[idx]
	if bool(offer.get("sold", false)):
		return
	var price := int(offer.get("price", 0))
	var kind := String(offer.get("kind", ""))
	var item_id := String(offer.get("id", ""))
	var tier := int(offer.get("tier", 1))
	if kind == "temper":
		if _v2.orbit_rig == null or not _v2.orbit_rig.can_upgrade_weapon(item_id):
			return
	elif kind == "weapon" and not _v2.can_add_weapon(item_id, tier):
		return
	if not _v2.spend_run_gold(price):
		return
	if kind == "temper":
		_v2.upgrade_weapon(item_id, 1)
	elif kind == "weapon":
		_v2.add_weapon(item_id, tier)
	else:
		_v2.add_item(item_id)
	_slots_data[idx]["sold"] = true
	_slots_data[idx]["locked"] = false
	_v2.play_v2_cue("ui_event", "ui_event")
	_refresh_view()

func _on_reroll_pressed() -> void:
	if _v2 == null:
		return
	var rc := _reroll_cost()
	if not _v2.spend_run_gold(rc):
		return
	_reroll_count += 1
	_v2.play_v2_cue("ui_event", "ui_event")
	_roll_unlocked_slots()
	_refresh_view()

func _on_continue_pressed() -> void:
	hide_panel()
	closed.emit()
