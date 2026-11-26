extends Node
class_name UpgradeManager

const V2_ELEM_NAMES := {
	"metal": "金系法宝",
	"fire": "火系法宝",
	"thunder": "雷系法宝",
	"ice": "冰系法宝",
	"wood": "木系法宝",
	"venom": "毒系法宝",
	"water": "水系法宝",
	"none": "器道奇宝",
}

const V2_TIER_NAMES := ["", "Lv.1", "Lv.2", "Lv.3", "Lv.4", "Lv.5", "Lv.6", "Lv.7", "Lv.8"]

const V2_REALM_BREAKTHROUGHS := [
	{"id": "v2_stat:dmg", "tag": "【灵力淬炼】", "title": "道心凝锋", "desc": "所有法宝与元素反应伤害 +7%（限叠 4 次）。", "icon": "res://assets/icons/icon_qingzhu_sword.png", "hint": "✦ 稳健全局增幅", "stackable": true, "max_stacks": 4},
	{"id": "v2_stat:spd", "tag": "【身法灵韵】", "title": "御风迅捷", "desc": "所有法宝攻速 +7%，移速 +4%（限叠 4 次）。", "icon": "res://assets/icons/relic_wind.png", "hint": "✦ 加快法宝出手与跑图", "stackable": true, "max_stacks": 4},
	{"id": "v2_stat:mastery", "tag": "【五行参悟】", "title": "五行通玄", "desc": "元素反应伤害 +12%，反应范围 +6%（限叠 4 次）。", "icon": "res://assets/icons/icon_taichi_array.png", "hint": "✦ 元素流派核心加成", "stackable": true, "max_stacks": 4},
	{"id": "v2_stat:crit", "tag": "【剑意凌厉】", "title": "破妄灵瞳", "desc": "暴击率 +5%，暴击伤害 +12%（限叠 4 次）。", "icon": "res://assets/icons/relic_luck.png", "hint": "✦ 单点高伤法宝首选", "stackable": true, "max_stacks": 4},
	{"id": "v2_stat:hp_armor", "tag": "【护体金身】", "title": "玄玉护脉", "desc": "最大气血 +24 并立刻回复 24 点（限叠 4 次）。", "icon": "res://assets/icons/relic_armor.png", "hint": "✦ 提高生存容错", "stackable": true, "max_stacks": 4},
	{"id": "v2_stat:gold_heal", "tag": "【灵露润脉】", "title": "甘露回春", "desc": "立刻回复 32 点气血，并提高 8 点最大气血。", "icon": "res://assets/sprites/pickup_peach.png", "hint": "✦ 续航保命补给", "stackable": false, "max_stacks": 0},
	{"id": "v2_stat:luck", "tag": "【天机气运】", "title": "天机福缘", "desc": "机缘 +15%，提高 4 选 1 与高阶宝物率（限叠 3 次）。", "icon": "res://assets/icons/relic_luck.png", "hint": "✦ 提高高阶卡出现率", "stackable": true, "max_stacks": 3},
	{"id": "v2_stat:area", "tag": "【乾坤法域】", "title": "法域扩张", "desc": "所有法宝攻击与法阵范围 +10%（限叠 3 次）。", "icon": "res://assets/icons/icon_taichi_array.png", "hint": "✦ 扩大火域/声波/藤蔓范围", "stackable": true, "max_stacks": 3},
	{"id": "v2_stat:proj", "tag": "【御器通灵】", "title": "灵器贯通", "desc": "飞剑/冰锥穿透 +1，雷系弹射目标 +1（限叠 2 次）。", "icon": "res://assets/icons/icon_jiutian_thunder.png", "hint": "✦ 适度提升清杂与连锁", "stackable": true, "max_stacks": 2},
	{"id": "v2_stat:dodge_dash", "tag": "【踏云灵步】", "title": "御风绝影", "desc": "闪避率 +4%，踏云步冷却 -8%（限叠 3 次）。", "icon": "res://assets/icons/relic_boots.png", "hint": "✦ 提高机动走位容错", "stackable": true, "max_stacks": 3},
]

var rerolls_left: int = 3
var banishes_left: int = 2
var skips_left: int = 2
var banished_ids: Dictionary = {}

func reset_run_controls() -> void:
	rerolls_left = 3 + Stats.get_sect_level("rerolls")
	banishes_left = 2 + (Stats.get_total_seal_bonus() if Stats.has_method("get_total_seal_bonus") else Stats.get_sect_level("seal"))
	skips_left = 2
	banished_ids.clear()

func _normalize_banish_key(choice_id: String) -> String:
	if not choice_id.begins_with("v2_wpn:"):
		return choice_id
	var parts := choice_id.split(":")
	if parts.size() >= 2:
		return "v2_wpn:" + parts[1]
	return choice_id

func banish_choice(choice_id: String) -> bool:
	if banishes_left <= 0 or choice_id == "":
		return false
	banishes_left -= 1
	banished_ids[_normalize_banish_key(choice_id)] = true
	return true

func get_random_choices(player: Node, count: int = 3) -> Array[Dictionary]:
	if player == null or not ("weapon_mgr" in player) or player.weapon_mgr == null:
		return []
	var wm: WeaponManager = player.weapon_mgr
	var pool: Array[Dictionary] = []

	var weapon_slots_full := wm.weapons.size() >= WeaponCatalog.MAX_WEAPON_SLOTS
	for wid in WeaponCatalog.weapon_ids():
		var uid := "weapon:" + wid
		if banished_ids.has(uid):
			continue
		var cur_lv := wm.weapon_level(wid)
		if wm.is_weapon_evolved(wid) or cur_lv >= WeaponCatalog.MAX_WEAPON_LEVEL:
			continue
		if cur_lv == 0 and weapon_slots_full:
			continue
		var cfg := WeaponCatalog.get_weapon(wid)
		var next_lv := cur_lv + 1
		var weight := 14 if cur_lv > 0 else 10
		if wm.has_passive(str(cfg["partner_passive"])):
			weight += 5
		pool.append({
			"id": uid,
			"kind": "weapon",
			"item_id": wid,
			"tag": "【%s】" % str(cfg["tag"]),
			"title": str(cfg["name"]),
			"desc": WeaponCatalog.weapon_level_desc(wid, next_lv),
			"level": cur_lv,
			"next_level": next_lv,
			"max_level": WeaponCatalog.MAX_WEAPON_LEVEL,
			"icon": str(cfg["icon"]),
			"synergy_hint": WeaponCatalog.evolution_hint_for_weapon(wid),
			"is_new": cur_lv == 0,
			"is_relic": false,
			"is_evo": false,
			"weight": weight,
		})

	var passive_slots_full := wm.passives.size() >= WeaponCatalog.MAX_PASSIVE_SLOTS
	for pid in WeaponCatalog.passive_ids():
		var uid := "passive:" + pid
		if banished_ids.has(uid):
			continue
		var cfg := WeaponCatalog.get_passive(pid)
		var max_lv := int(cfg.get("max_level", WeaponCatalog.MAX_PASSIVE_LEVEL))
		var cur_lv := wm.passive_level(pid)
		if cur_lv >= max_lv:
			continue
		if cur_lv == 0 and passive_slots_full:
			continue
		var next_lv := cur_lv + 1
		var partner_w := str(cfg["evolves_weapon"])
		var weight := 11 if cur_lv > 0 else 8
		if wm.has_weapon(partner_w) and not wm.is_weapon_evolved(partner_w):
			weight += 6
		var hint := WeaponCatalog.evolution_hint_for_passive(pid)
		if wm.is_weapon_evolved(partner_w):
			var wcfg := WeaponCatalog.get_weapon(partner_w)
			hint = "✦ 已共鸣超武【%s】" % str(wcfg.get("evo_name", ""))
		elif wm.weapon_level(partner_w) >= WeaponCatalog.MAX_WEAPON_LEVEL:
			var wcfg := WeaponCatalog.get_weapon(partner_w)
			hint = "✦【%s】已满级！拾取宝箱即可进化" % str(wcfg.get("name", ""))
		pool.append({
			"id": uid,
			"kind": "passive",
			"item_id": pid,
			"tag": "【法宝】",
			"title": str(cfg["name"]),
			"desc": str(cfg["desc"]),
			"level": cur_lv,
			"next_level": next_lv,
			"max_level": max_lv,
			"icon": str(cfg["icon"]),
			"synergy_hint": hint,
			"is_new": cur_lv == 0,
			"is_relic": true,
			"is_evo": false,
			"weight": weight,
		})

	var selected: Array[Dictionary] = []
	var draw_n := mini(count, pool.size())
	for _i in range(draw_n):
		var total_w := 0
		for item in pool:
			total_w += int(item["weight"])
		var r := randi() % maxi(1, total_w)
		var acc := 0
		var picked_idx := 0
		for idx in range(pool.size()):
			acc += int(pool[idx]["weight"])
			if r < acc:
				picked_idx = idx
				break
		selected.append(pool[picked_idx])
		pool.remove_at(picked_idx)
	return selected

func get_limit_break_choices(_player: Node, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{
			"id": "limit:might",
			"tag": "【破境】",
			"title": "剑意破限",
			"desc": "所有神通基础伤害永久 +8%（本局无限叠加）。",
			"level": 1,
			"next_level": 1,
			"max_level": 1,
			"icon": "res://assets/icons/icon_qingzhu_sword.png",
			"synergy_hint": "✦ 满级突破 · 无限成长",
			"is_new": false,
			"is_relic": false,
			"is_evo": true,
		},
		{
			"id": "limit:haste",
			"tag": "【破境】",
			"title": "行云神速",
			"desc": "所有神通施法冷却缩减 5%（本局无限叠加）。",
			"level": 1,
			"next_level": 1,
			"max_level": 1,
			"icon": "res://assets/icons/relic_wind.png",
			"synergy_hint": "✦ 满级突破 · 无限成长",
			"is_new": false,
			"is_relic": true,
			"is_evo": false,
		},
		{
			"id": "limit:heal",
			"tag": "【灵露】",
			"title": "甘露回春",
			"desc": "立刻恢复 35 点气血，并获得 12 枚灵石。",
			"level": 1,
			"next_level": 1,
			"max_level": 1,
			"icon": "res://assets/sprites/pickup_peach.png",
			"synergy_hint": "✦ 续航补给",
			"is_new": false,
			"is_relic": false,
			"is_evo": false,
		},
	]
	return pool.slice(0, mini(count, pool.size()))

func apply_upgrade(choice_id: String, player: Node) -> void:
	if player == null or not ("weapon_mgr" in player) or player.weapon_mgr == null:
		return
	var wm: WeaponManager = player.weapon_mgr
	if choice_id.begins_with("weapon:"):
		wm.add_or_upgrade_weapon(choice_id.substr(7))
	elif choice_id.begins_with("passive:"):
		wm.add_or_upgrade_passive(choice_id.substr(8))
	elif choice_id == "limit:might":
		if "limit_might_bonus" in player:
			player.limit_might_bonus += 0.08
			wm.refresh_stats()
	elif choice_id == "limit:haste":
		if "limit_haste_bonus" in player:
			player.limit_haste_bonus += 1.0
			wm.refresh_stats()
	elif choice_id == "limit:heal":
		if player.has_method("heal"):
			player.heal(35.0)
		Stats.add_spirit_stones(12)

func roll_chest_rewards(player: Node) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if player == null or not ("weapon_mgr" in player) or player.weapon_mgr == null:
		rewards.append(_chest_guarantee_reward(player))
		return rewards
	var wm: WeaponManager = player.weapon_mgr

	var evos := wm.evolve_candidates()
	if not evos.is_empty():
		var wid: String = evos[0]
		wm.evolve_weapon(wid)
		var cfg := WeaponCatalog.get_weapon(wid)
		var partner := WeaponCatalog.get_passive(str(cfg["partner_passive"]))
		rewards.append({
			"is_evo": true,
			"title": "【超武质变】%s" % str(cfg["evo_name"]),
			"subtitle": "%s + %s 灵韵合一！" % [str(cfg["name"]), str(partner.get("name", ""))],
			"desc": str(cfg["evo_desc"]),
			"icon": str(cfg["evo_icon"]),
		})
		return rewards

	var roll := randf()
	var count := 1
	if roll > 0.88:
		count = 5
	elif roll > 0.55:
		count = 3

	for _i in range(count):
		var cands: Array[Dictionary] = []
		for wid in wm.weapons.keys():
			var w_key := str(wid)
			if not wm.is_weapon_evolved(w_key) and wm.weapon_level(w_key) < WeaponCatalog.MAX_WEAPON_LEVEL:
				cands.append({"kind": "weapon", "id": w_key})
		for pid in wm.passives.keys():
			var pcfg := WeaponCatalog.get_passive(str(pid))
			if wm.passive_level(str(pid)) < int(pcfg.get("max_level", WeaponCatalog.MAX_PASSIVE_LEVEL)):
				cands.append({"kind": "passive", "id": str(pid)})
		if cands.is_empty():
			if player.has_method("heal"):
				player.heal(45.0)
			Stats.add_spirit_stones(25)
			rewards.append({
				"is_evo": false,
				"title": "仙果灵露",
				"subtitle": "所有神通法宝均已圆满",
				"desc": "恢复 45 点气血，并获赠 25 枚灵石！",
				"icon": "res://assets/sprites/pickup_peach.png",
			})
			break
		var pick: Dictionary = cands[randi() % cands.size()]
		if pick["kind"] == "weapon":
			var wid: String = pick["id"]
			wm.add_or_upgrade_weapon(wid)
			var cfg := WeaponCatalog.get_weapon(wid)
			var lv := wm.weapon_level(wid)
			rewards.append({
				"is_evo": false,
				"title": "%s Lv.%d" % [str(cfg["name"]), lv],
				"subtitle": "神通精进",
				"desc": WeaponCatalog.weapon_level_desc(wid, lv),
				"icon": str(cfg["icon"]),
			})
		else:
			var pid: String = pick["id"]
			wm.add_or_upgrade_passive(pid)
			var cfg := WeaponCatalog.get_passive(pid)
			var lv := wm.passive_level(pid)
			rewards.append({
				"is_evo": false,
				"title": "%s Lv.%d" % [str(cfg["name"]), lv],
				"subtitle": "法宝炼化",
				"desc": str(cfg["desc"]),
				"icon": str(cfg["icon"]),
			})
	return rewards

func get_v2_level_choices(player: Node, count: int = 3) -> Array[Dictionary]:
	if player == null or not ("v2_combat" in player) or player.v2_combat == null:
		return get_random_choices(player, count)
	var v2: V2CombatController = player.v2_combat
	if v2.loader == null or v2.orbit_rig == null:
		return get_random_choices(player, count)

	var is_breakthrough := v2.should_offer_breakthrough_pick()
	var owned_elems := v2.get_owned_elements()
	var new_weapon_cards: Array[Dictionary] = []
	var upgrade_weapon_cards: Array[Dictionary] = []

	for wid in v2.loader.weapons_by_id.keys():
		var sid := String(wid)
		if banished_ids.has("v2_wpn:" + sid):
			continue
		var w: Dictionary = v2.loader.weapons_by_id[wid]
		var elem := String(w.get("element", "metal"))
		var cur_lv := v2.orbit_rig.get_weapon_tier(sid)
		if cur_lv >= OrbitWeaponRig.MAX_WEAPON_TIER:
			continue
		if cur_lv == 0 and not v2.can_add_weapon(sid, 1):
			continue

		var next_lv := maxi(1, cur_lv + 1)
		var tiers: Array = w.get("tiers", [])
		var ts: Dictionary = tiers[clampi(next_lv - 1, 0, tiers.size() - 1)] if not tiers.is_empty() else {}
		var summary := String(ts.get("level_summary", ""))
		var desc := "%s\n伤害 %d · 冷却 %.2fs" % [summary, int(ts.get("damage", 15)), float(ts.get("cooldown", 1.0))]
		var w_weight := maxi(1, roundi(v2.get_weapon_offer_weight(sid) * 10.0))

		var syn_hint := ""
		if elem == "none":
			syn_hint = "✦ 器道奇宝 · 不占灵变冷却，本体高伤 + 卷经验定身"
		elif cur_lv > 0:
			syn_hint = "✦ 法宝原地淬炼，不占新槽位"
		else:
			var syns: Array[Dictionary] = v2.get_weapon_reaction_synergies(sid)
			if not syns.is_empty():
				var s0: Dictionary = syns[0]
				syn_hint = "✦ 可与【%s】触发：%s（%s）" % [s0["partner_name"], s0["rx_name"], s0["role_tag"]]
			else:
				syn_hint = "✦ 独立属性法宝 · 稳健补强当前流派"

		var card := {
			"id": "v2_wpn:%s:%d" % [sid, next_lv],
			"weapon_id": sid,
			"tag": "【%s · %s】" % [String(V2_ELEM_NAMES.get(elem, "法宝")), V2_TIER_NAMES[clampi(next_lv, 0, OrbitWeaponRig.MAX_WEAPON_TIER)]],
			"title": String(w.get("name", sid)),
			"desc": desc,
			"level": cur_lv,
			"next_level": next_lv,
			"max_level": OrbitWeaponRig.MAX_WEAPON_TIER,
			"icon": String(w.get("icon", "")),
			"synergy_hint": syn_hint,
			"fusion_hint": "",
			"offer_kind": "new_weapon" if cur_lv == 0 else "upgrade_weapon",
			"is_new": cur_lv == 0,
			"is_relic": false,
			"is_evo": (cur_lv > 0 and next_lv >= OrbitWeaponRig.MAX_WEAPON_TIER),
			"weight": w_weight,
			"elem": elem,
		}
		if cur_lv == 0:
			new_weapon_cards.append(card)
		else:
			upgrade_weapon_cards.append(card)

	var lb_cards: Array[Dictionary] = _build_weapon_limit_break_cards(v2)
	var stat_cards: Array[Dictionary] = []
	for b in V2_REALM_BREAKTHROUGHS:
		var bid := String(b["id"])
		if banished_ids.has(bid):
			continue
		var is_stackable := bool(b.get("stackable", true))
		var cur_stacks := v2.get_stat_pick_count(bid)
		var cap := int(b.get("max_stacks", 0))
		if cap > 0 and cur_stacks >= cap:
			continue
		stat_cards.append({
			"id": bid,
			"tag": String(b["tag"]),
			"title": String(b["title"]),
			"desc": String(b["desc"]),
			"level": cur_stacks,
			"next_level": cur_stacks + 1,
			"max_level": cap if cap > 0 else (0 if is_stackable else -1),
			"icon": String(b["icon"]),
			"synergy_hint": String(b["hint"]),
			"fusion_hint": "",
			"offer_kind": "stat",
			"is_new": false,
			"is_relic": true,
			"is_evo": false,
			"weight": 110,
		})

	var item_candidates: Array[Dictionary] = []
	if v2.loader != null:
		for iid in v2.loader.items_by_id.keys():
			var item_id := String(iid)
			if banished_ids.has("v2_item:" + item_id):
				continue
			if not v2.can_add_item(item_id):
				continue
			var it: Dictionary = v2.loader.items_by_id[iid]
			var cur_cnt := v2.get_item_count(item_id)
			var cap := maxi(1, int(it.get("max_stacks", 1)))
			item_candidates.append({
				"id": "v2_item:" + item_id,
				"tag": "【奇物】",
				"title": String(it.get("name", item_id)),
				"desc": String(it.get("desc", "")),
				"level": cur_cnt,
				"next_level": cur_cnt + 1,
				"max_level": cap,
				"icon": String(V2ShopUI.ITEM_ICONS.get(item_id, "res://assets/icons/relic_insight.png")),
				"synergy_hint": "",
				"fusion_hint": "",
				"offer_kind": "item",
				"is_new": cur_cnt == 0,
				"is_relic": true,
				"is_evo": false,
				"weight": 100,
			})
	item_candidates.shuffle()
	var item_cards: Array[Dictionary] = []
	for i in range(mini(3, item_candidates.size())):
		item_cards.append(item_candidates[i])

	var selected: Array[Dictionary] = []
	if is_breakthrough:
		_draw_weighted_cards(new_weapon_cards, count, selected)
		var fallback: Array[Dictionary] = []
		fallback.append_array(upgrade_weapon_cards)
		fallback.append_array(stat_cards)
		_draw_weighted_cards(fallback, count, selected)
	else:
		var combined: Array[Dictionary] = []
		combined.append_array(new_weapon_cards)
		combined.append_array(upgrade_weapon_cards)
		combined.append_array(lb_cards)
		combined.append_array(stat_cards)
		combined.append_array(item_cards)
		_draw_weighted_cards(combined, count, selected)

	return selected

func _build_weapon_limit_break_cards(v2: V2CombatController) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v2 == null or v2.orbit_rig == null or v2.loader == null:
		return out
	var defs := [
		{"stat": "damage_pct", "label": "破境·锋芒 +8%", "desc": "该法宝基础伤害永久 +8%（最多5层）", "max": 5, "weight": 85},
		{"stat": "cooldown_pct", "label": "破境·迅捷 -4%", "desc": "该法宝出手冷却永久 -4%（最多5层）", "max": 5, "weight": 65},
	]
	for s in v2.orbit_rig.slots:
		var wid := String(s.get("id", ""))
		var is_fus := bool(s.get("is_fusion", false))
		var tier := int(s.get("tier", 0))
		if not is_fus and tier < OrbitWeaponRig.MAX_WEAPON_TIER:
			continue
		var w_name := String(s.get("name", wid))
		var w_icon := String(s.get("icon", ""))
		if v2.loader.weapons_by_id.has(wid):
			var wd: Dictionary = v2.loader.weapons_by_id[wid]
			w_name = String(wd.get("name", w_name))
			w_icon = String(wd.get("icon", w_icon))
		for d in defs:
			var skey := String(d["stat"])
			var cur_st := v2.get_weapon_limit_break_stacks(wid, skey)
			if cur_st >= int(d["max"]):
				continue
			var cid := "v2_lb:%s:%s" % [wid, skey]
			if banished_ids.has(cid):
				continue
			out.append({
				"id": cid,
				"weapon_id": wid,
				"tag": "【%s】" % String(d["label"]),
				"title": w_name,
				"desc": String(d["desc"]),
				"level": cur_st,
				"next_level": cur_st + 1,
				"max_level": int(d["max"]),
				"icon": w_icon,
				"synergy_hint": "✦ 满阶法宝专属破境词条",
				"fusion_hint": "",
				"offer_kind": "limit_break",
				"is_new": false,
				"is_relic": false,
				"is_evo": true,
				"weight": int(d["weight"]),
			})
	return out

func _draw_weighted_cards(pool: Array[Dictionary], target_count: int, selected: Array[Dictionary]) -> void:
	while selected.size() < target_count and not pool.is_empty():
		var total_w := 0
		for it in pool:
			total_w += int(it.get("weight", 10))
		var r := randi() % maxi(1, total_w)
		var acc := 0
		var pick_idx := 0
		for idx in range(pool.size()):
			acc += int(pool[idx].get("weight", 10))
			if r < acc:
				pick_idx = idx
				break
		var chosen := pool[pick_idx]
		pool.remove_at(pick_idx)
		var dup := false
		for s in selected:
			if String(s["id"]) == String(chosen["id"]):
				dup = true
				break
		if not dup:
			selected.append(chosen)

func apply_v2_upgrade(choice_id: String, player: Node) -> void:
	if player == null or not ("v2_combat" in player) or player.v2_combat == null:
		apply_upgrade(choice_id, player)
		return
	var v2: V2CombatController = player.v2_combat
	if choice_id.begins_with("v2_wpn:"):
		var parts := choice_id.split(":")
		if parts.size() >= 3:
			v2.add_weapon(parts[1], int(parts[2]))
		return
	if choice_id.begins_with("v2_lb:"):
		var lb_parts := choice_id.split(":")
		if lb_parts.size() >= 3:
			var wid := lb_parts[1]
			var skey := lb_parts[2]
			var dval := 0.08 if skey == "damage_pct" else (-0.04 if skey == "cooldown_pct" else 1.0)
			v2.apply_weapon_limit_break(wid, skey, dval, 5)
		return
	if choice_id.begins_with("v2_item:"):
		v2.add_item(choice_id.substr(8))
		return
	if choice_id.begins_with("v2_arcana:"):
		return
	if choice_id.begins_with("v2_stat:"):
		v2.record_stat_pick(choice_id)
	match choice_id:
		"v2_stat:dmg":
			v2.add_realm_bonus("damage_pct", 0.07)
		"v2_stat:spd":
			v2.add_realm_bonus("attack_speed_pct", 0.07)
			v2.add_realm_bonus("move_speed_pct", 0.04)
		"v2_stat:mastery":
			v2.add_realm_bonus("reaction_damage_pct", 0.12)
			v2.add_realm_bonus("reaction_radius_pct", 0.06)
		"v2_stat:crit":
			v2.add_realm_bonus("crit_chance", 0.05)
			v2.add_realm_bonus("crit_mult_bonus", 0.12)
		"v2_stat:hp_armor":
			v2.add_realm_bonus("max_hp", 24.0)
			if player.has_method("heal"):
				player.heal(24.0)
		"v2_stat:gold_heal":
			v2.add_realm_bonus("max_hp", 8.0)
			if player.has_method("heal"):
				player.heal(32.0)
		"v2_stat:luck":
			v2.add_realm_bonus("luck", 0.15)
		"v2_stat:area":
			v2.add_realm_bonus("area_pct", 0.10)
		"v2_stat:proj":
			v2.add_realm_bonus("pierce_flat", 1.0)
			v2.add_realm_bonus("chain_bonus", 1.0)
		"v2_stat:dodge_dash":
			v2.add_realm_bonus("dodge_pct", 0.04)
			v2.add_realm_bonus("dash_cooldown_pct", -0.08)
		"limit:heal":
			if player.has_method("heal"):
				player.heal(35.0)
			v2.add_run_gold(12)
		_:
			apply_upgrade(choice_id, player)

func roll_v2_chest_rewards(player: Node) -> Array[Dictionary]:
	var bundle := roll_v2_chest_bundle(player, false)
	var out: Array[Dictionary] = []
	for r in bundle.get("rewards", []):
		if r is Dictionary:
			out.append(r)
	return out

func roll_v2_chest_bundle(player: Node, defer_new_weapon: bool = false) -> Dictionary:
	if player == null or not ("v2_combat" in player) or player.v2_combat == null:
		var legacy_rewards: Array[Dictionary] = roll_chest_rewards(player)
		if legacy_rewards.is_empty():
			legacy_rewards.append(_chest_guarantee_reward(player))
		return {"stones": 0, "tier": maxi(1, legacy_rewards.size()), "rewards": legacy_rewards}

	var v2: V2CombatController = player.v2_combat
	var luck := v2.get_luck()
	var p5 := clampf(0.10 * luck, 0.08, 0.32)
	var p3 := clampf(0.32 * luck, 0.25, 0.55)
	var r := randf()
	var tier := 5 if r < p5 else (3 if r < p5 + p3 else 1)

	var base_stones := randi_range(20, 30)
	if tier == 3:
		base_stones = randi_range(45, 65)
	elif tier >= 5:
		base_stones = randi_range(90, 125)
	var stones_gained := v2.add_run_gold(base_stones)

	var rewards: Array[Dictionary] = []
	var reserved_new_wids: Array[String] = []
	var guaranteed := false
	for i in range(tier):
		var reward := _roll_single_v2_chest_reward(v2, i == 0, defer_new_weapon, reserved_new_wids)
		if reward.is_empty():
			if not guaranteed:
				guaranteed = true
				stones_gained += v2.add_run_gold(15)
				rewards.append(_chest_guarantee_reward(player))
			break
		if String(reward.get("reward_kind", "")) == "pending_new_weapon":
			reserved_new_wids.append(String(reward.get("weapon_id", "")))
		rewards.append(reward)

	if rewards.is_empty():
		rewards.append(_chest_guarantee_reward(player))

	return {
		"stones": stones_gained,
		"tier": tier,
		"rewards": rewards,
	}

func resolve_chest_pending_rewards(rewards: Array, player: Node) -> int:
	if player == null or not ("v2_combat" in player) or player.v2_combat == null:
		return 0
	var v2: V2CombatController = player.v2_combat
	var salvage_stones_total := 0
	for item in rewards:
		if not (item is Dictionary):
			continue
		var r: Dictionary = item
		if String(r.get("reward_kind", "")) != "pending_new_weapon":
			continue
		var wid := String(r.get("weapon_id", ""))
		var accepted := bool(r.get("accepted", true))
		if accepted and wid != "" and v2.can_add_weapon(wid, 1) and v2.add_weapon(wid, 1):
			continue
		var salvage := maxi(15, int(r.get("salvage_stones", 30)))
		salvage_stones_total += v2.add_run_gold(salvage)
		if player.has_method("heal"):
			player.heal(15.0)
	return salvage_stones_total

func _build_synergy_hint_for_weapon(v2: V2CombatController, wid: String, elem: String) -> String:
	if elem == "none":
		return "✦ 器道百搭 · 不占反应，高伤卷经验"
	var syns: Array[Dictionary] = v2.get_weapon_reaction_synergies(wid)
	if not syns.is_empty():
		var s0: Dictionary = syns[0]
		return "✦ 可与【%s】触发：%s（%s）" % [s0["partner_name"], s0["rx_name"], s0["role_tag"]]
	return "✦ 可触发五行反应"

func _roll_single_v2_chest_reward(
	v2: V2CombatController,
	prefer_upgrade: bool,
	defer_new_weapon: bool = false,
	reserved_new_wids: Array[String] = []
) -> Dictionary:
	if v2 == null or v2.loader == null:
		return {}

	var upgradable_weapons: Array[Dictionary] = []
	var new_weapons: Array[String] = []
	if v2.orbit_rig != null:
		for s in v2.orbit_rig.slots:
			if not bool(s.get("is_fusion", false)) and int(s.get("tier", 1)) < OrbitWeaponRig.MAX_WEAPON_TIER:
				upgradable_weapons.append(s)
		var free_slots := maxi(0, v2.orbit_rig.get_unlocked_slots() - v2.orbit_rig.slots.size() - reserved_new_wids.size())
		if free_slots > 0:
			for wid_raw in v2.loader.weapons_by_id.keys():
				var wid := String(wid_raw)
				if banished_ids.has("v2_wpn:" + wid) or reserved_new_wids.has(wid):
					continue
				if v2.orbit_rig.get_weapon_tier(wid) == 0 and v2.can_add_weapon(wid, 1):
					var w_def: Dictionary = v2.loader.weapons_by_id[wid_raw]
					var elem := String(w_def.get("element", "none"))
					if elem == "none" or not v2.get_weapon_reaction_synergies(wid).is_empty():
						new_weapons.append(wid)

	if prefer_upgrade and not upgradable_weapons.is_empty():
		var pick_u: Dictionary = upgradable_weapons[randi() % upgradable_weapons.size()]
		var res := _apply_chest_weapon_upgrade(v2, String(pick_u["id"]), int(pick_u["tier"]))
		if not res.is_empty():
			return res

	var available_items: Array[String] = []
	for iid_raw in v2.loader.items_by_id.keys():
		var iid := String(iid_raw)
		if banished_ids.has("v2_item:" + iid):
			continue
		var it_def: Dictionary = v2.loader.items_by_id[iid_raw]
		var mods: Variant = it_def.get("mods", {})
		if mods is Dictionary and float((mods as Dictionary).get("curse_pct", 0.0)) > 0.0:
			continue
		if v2.can_add_item(iid):
			available_items.append(iid)

	var pool: Array[Dictionary] = []
	if not upgradable_weapons.is_empty():
		pool.append({"kind": "upgrade_weapon", "weight": 58})
	if not new_weapons.is_empty():
		pool.append({"kind": "new_weapon", "weight": 18})
	if not available_items.is_empty():
		pool.append({"kind": "item", "weight": 32})

	if pool.is_empty():
		return {}

	var total_w := 0
	for p_entry in pool:
		total_w += int(p_entry["weight"])
	var roll := randi() % maxi(1, total_w)
	var acc := 0
	var chosen_kind := String(pool[0]["kind"])
	for p_entry in pool:
		acc += int(p_entry["weight"])
		if roll < acc:
			chosen_kind = String(p_entry["kind"])
			break

	match chosen_kind:
		"upgrade_weapon":
			var pick_u: Dictionary = upgradable_weapons[randi() % upgradable_weapons.size()]
			return _apply_chest_weapon_upgrade(v2, String(pick_u["id"]), int(pick_u["tier"]))
		"new_weapon":
			var wid: String = new_weapons[randi() % new_weapons.size()]
			var w: Dictionary = v2.loader.weapons_by_id[wid]
			var elem := String(w.get("element", "none"))
			var syn_hint := _build_synergy_hint_for_weapon(v2, wid, elem)
			if defer_new_weapon:
				var alts: Array[String] = []
				for alt_id in new_weapons:
					if alt_id != wid:
						alts.append(alt_id)
				return {
					"is_evo": false,
					"reward_kind": "pending_new_weapon",
					"weapon_id": wid,
					"alt_weapon_ids": alts,
					"salvage_stones": 30,
					"accepted": true,
					"rerolled": false,
					"title": String(w.get("name", wid)),
					"subtitle": "天机赐宝 · 协同新法宝",
					"desc": "%s · Lv.1\n%s" % [String(V2_ELEM_NAMES.get(elem, "器道奇宝")), syn_hint],
					"icon": String(w.get("icon", "")),
				}
			if v2.add_weapon(wid, 1):
				return {
					"is_evo": false,
					"title": String(w.get("name", wid)),
					"subtitle": "天机赐宝 · 新获法宝",
					"desc": "%s · Lv.1 入手，立即参战！\n%s" % [String(V2_ELEM_NAMES.get(elem, "器道奇宝")), syn_hint],
					"icon": String(w.get("icon", "")),
				}
		"item":
			var iid: String = available_items[randi() % available_items.size()]
			if v2.add_item(iid):
				var it: Dictionary = v2.loader.items_by_id[iid]
				return {
					"is_evo": false,
					"title": String(it.get("name", iid)),
					"subtitle": "天机奇物 · 随身加持",
					"desc": String(it.get("desc", "")),
					"icon": String(V2ShopUI.ITEM_ICONS.get(iid, "res://assets/icons/relic_insight.png")),
				}
	return {}

func _apply_chest_weapon_upgrade(v2: V2CombatController, wid: String, cur_tier: int) -> Dictionary:
	if not v2.upgrade_weapon(wid, 1):
		return {}
	var w: Dictionary = v2.loader.weapons_by_id.get(wid, {})
	var next_tier := mini(cur_tier + 1, OrbitWeaponRig.MAX_WEAPON_TIER)
	return {
		"is_evo": false,
		"title": "%s 淬炼" % String(w.get("name", wid)),
		"subtitle": "天机奇缘 · 法宝淬炼",
		"desc": "法宝原地淬炼，提升至 %s！" % V2_TIER_NAMES[next_tier],
		"icon": String(w.get("icon", "")),
	}

func _chest_guarantee_reward(player: Node) -> Dictionary:
	var v2: V2CombatController = null
	if player != null and "v2_combat" in player and player.v2_combat != null:
		v2 = player.v2_combat
	if v2 == null:
		if player != null and player.has_method("heal"):
			player.heal(45.0)
		return {
			"is_evo": false,
			"title": "九转还魂丹",
			"subtitle": "保底奇珍 · 丹香续命",
			"desc": "九转丹成，立刻回复 45 点气血！",
			"icon": "res://assets/sprites/pickup_peach.png",
		}
	var pick := randi() % 3
	if pick == 0:
		v2.add_realm_bonus("damage_pct", 0.05)
		return {
			"is_evo": false,
			"title": "道心淬炼",
			"subtitle": "保底奇珍 · 剑意微增",
			"desc": "所有法宝伤害永久 +5%！",
			"icon": "res://assets/icons/relic_insight.png",
		}
	if pick == 1:
		if player.has_method("heal"):
			player.heal(60.0)
		return {
			"is_evo": false,
			"title": "九转还魂丹",
			"subtitle": "保底奇珍 · 丹香续命",
			"desc": "九转丹成，立刻回复 60 点气血！",
			"icon": "res://assets/sprites/pickup_peach.png",
		}
	v2.add_realm_bonus("damage_pct", 0.03)
	v2.add_realm_bonus("attack_speed_pct", 0.03)
	v2.add_realm_bonus("move_speed_pct", 0.02)
	v2.add_realm_bonus("max_hp", 8.0)
	if player.has_method("heal"):
		player.heal(8.0)
	return {
		"is_evo": false,
		"title": "天机洗髓",
		"subtitle": "保底奇珍 · 全属性小幅提升",
		"desc": "伤害 +3%，攻速 +3%，移速 +2%，气血上限 +8！",
		"icon": "res://assets/icons/icon_taichi_array.png",
	}
