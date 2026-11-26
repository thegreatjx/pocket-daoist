extends Node

const PATH := "user://stats.cfg"
const SECTION := "best"
const META_SECTION := "meta"
const ACH_SECTION := "achievements"
const ACHIEVEMENTS_JSON_PATH := "res://data/v2/achievements_v2.json"

const SECT_CATALOG := [
	{"id": "hp", "name": "护体金身", "desc": "每级基础气血上限 +20", "max": 5, "costs": [40, 65, 95, 130, 170]},
	{"id": "might", "name": "剑魄淬炼", "desc": "每级所有神通伤害 +8%", "max": 5, "costs": [50, 80, 115, 155, 200]},
	{"id": "speed", "name": "御风身法", "desc": "每级基础移速 +6%", "max": 5, "costs": [40, 65, 95, 130, 170]},
	{"id": "magnet", "name": "聚灵仙诀", "desc": "每级灵丹拾取范围 +15%", "max": 5, "costs": [35, 55, 80, 110, 145]},
	{"id": "rerolls", "name": "天机推演", "desc": "每级每局额外重随次数 +1", "max": 3, "costs": [60, 110, 180]},
	{"id": "revival", "name": "九转金丹", "desc": "每局可逆天复活一次（满级1）", "max": 1, "costs": [180]},
	{"id": "armor", "name": "玄甲护体", "desc": "每级护甲 +1", "max": 5, "costs": [45, 75, 110, 150, 195]},
	{"id": "regen", "name": "吐纳回春", "desc": "每级每秒气血回复 +0.4", "max": 5, "costs": [45, 75, 110, 150, 195]},
	{"id": "attack_speed", "name": "疾风剑诀", "desc": "每级法宝攻速 +5%", "max": 5, "costs": [55, 90, 130, 175, 225]},
	{"id": "area", "name": "乾坤法域", "desc": "每级神通与法阵范围 +6%", "max": 5, "costs": [50, 85, 125, 170, 220]},
	{"id": "crit", "name": "破妄灵瞳", "desc": "每级暴击率 +3%", "max": 5, "costs": [55, 90, 130, 175, 225]},
	{"id": "luck", "name": "天机福缘", "desc": "每级机缘 +10%（提高4选1与奇物品质）", "max": 5, "costs": [50, 85, 125, 170, 220]},
	{"id": "curse", "name": "天劫引煞", "desc": "每级劫气 +10%（怪血+10%/密度+5%/灵石+15%）", "max": 5, "costs": [60, 100, 145, 195, 250]},
	{"id": "seal", "name": "封魔印诀", "desc": "每级每局封印次数上限 +1", "max": 3, "costs": [70, 130, 210]},
]

var best_time: float = 0.0
var best_level: int = 0
var best_kills: int = 0
var total_runs: int = 0

var spirit_stones: int = 0
var selected_stage_id: int = 1
var selected_character_id: String = "sword_immortal"
var cleared_stages: Array[int] = []
var sect_upgrades: Dictionary = {}

var unlocked_achievements: Array[String] = []
var unlocked_arcanas: Array[String] = []
var total_kills: int = 0
var total_reactions: int = 0
var total_fusions: int = 0
var total_jars_broken: int = 0
var bonus_seal_slots: int = 0
var _achievements_cache: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_sect_defaults()
	load_stats()

func _init_sect_defaults() -> void:
	for item in SECT_CATALOG:
		var uid := str(item["id"])
		if not sect_upgrades.has(uid):
			sect_upgrades[uid] = 0

func load_stats(custom_path: String = PATH) -> void:
	_init_sect_defaults()
	var cf = ConfigFile.new()
	if cf.load(custom_path) != OK:
		return
	best_time = float(cf.get_value(SECTION, "best_time", 0.0))
	best_level = int(cf.get_value(SECTION, "best_level", 0))
	best_kills = int(cf.get_value(SECTION, "best_kills", 0))
	total_runs = int(cf.get_value(SECTION, "total_runs", 0))

	spirit_stones = maxi(0, int(cf.get_value(META_SECTION, "spirit_stones", 0)))
	selected_stage_id = clampi(int(cf.get_value(META_SECTION, "selected_stage_id", 1)), 1, ChapterData.count())
	var loaded_char := str(cf.get_value(META_SECTION, "selected_character_id", "sword_immortal"))
	selected_character_id = loaded_char if str(CharacterData.get_character(loaded_char).get("id", "")) == loaded_char else "sword_immortal"
	cleared_stages.clear()
	var saved_cleared = cf.get_value(META_SECTION, "cleared_stages", [])
	if saved_cleared is Array:
		for s in saved_cleared:
			var sid := int(s)
			if sid >= 1 and not cleared_stages.has(sid):
				cleared_stages.append(sid)
	for item in SECT_CATALOG:
		var uid := str(item["id"])
		sect_upgrades[uid] = clampi(int(cf.get_value(META_SECTION, "sect_" + uid, 0)), 0, int(item["max"]))

	unlocked_achievements.clear()
	var saved_ach = cf.get_value(ACH_SECTION, "unlocked_ids", [])
	if saved_ach is Array:
		for a in saved_ach:
			var aid := str(a)
			if not aid.is_empty() and not unlocked_achievements.has(aid):
				unlocked_achievements.append(aid)
	unlocked_arcanas.clear()
	var saved_arc = cf.get_value(ACH_SECTION, "unlocked_arcanas", [])
	if saved_arc is Array:
		for ar in saved_arc:
			var arid := str(ar)
			if not arid.is_empty() and not unlocked_arcanas.has(arid):
				unlocked_arcanas.append(arid)
	total_kills = maxi(0, int(cf.get_value(ACH_SECTION, "total_kills", 0)))
	total_reactions = maxi(0, int(cf.get_value(ACH_SECTION, "total_reactions", 0)))
	total_fusions = maxi(0, int(cf.get_value(ACH_SECTION, "total_fusions", 0)))
	total_jars_broken = maxi(0, int(cf.get_value(ACH_SECTION, "total_jars_broken", 0)))
	bonus_seal_slots = maxi(0, int(cf.get_value(ACH_SECTION, "bonus_seal_slots", 0)))

func save_stats(custom_path: String = PATH) -> bool:
	var cf = ConfigFile.new()
	cf.set_value(SECTION, "best_time", best_time)
	cf.set_value(SECTION, "best_level", best_level)
	cf.set_value(SECTION, "best_kills", best_kills)
	cf.set_value(SECTION, "total_runs", total_runs)

	cf.set_value(META_SECTION, "spirit_stones", spirit_stones)
	cf.set_value(META_SECTION, "selected_stage_id", selected_stage_id)
	cf.set_value(META_SECTION, "selected_character_id", selected_character_id)
	cf.set_value(META_SECTION, "cleared_stages", cleared_stages)
	for item in SECT_CATALOG:
		var uid := str(item["id"])
		cf.set_value(META_SECTION, "sect_" + uid, int(sect_upgrades.get(uid, 0)))

	cf.set_value(ACH_SECTION, "unlocked_ids", unlocked_achievements)
	cf.set_value(ACH_SECTION, "unlocked_arcanas", unlocked_arcanas)
	cf.set_value(ACH_SECTION, "total_kills", total_kills)
	cf.set_value(ACH_SECTION, "total_reactions", total_reactions)
	cf.set_value(ACH_SECTION, "total_fusions", total_fusions)
	cf.set_value(ACH_SECTION, "total_jars_broken", total_jars_broken)
	cf.set_value(ACH_SECTION, "bonus_seal_slots", bonus_seal_slots)

	var err = cf.save(custom_path)
	if err != OK:
		push_warning("Stats: 保存失败 err=%d" % err)
		return false
	return true

func record_run(time_sec: float, level: int, kills: int) -> bool:
	total_runs += 1
	var improved = false
	if time_sec > best_time:
		best_time = time_sec
		improved = true
	if level > best_level:
		best_level = level
		improved = true
	if kills > best_kills:
		best_kills = kills
		improved = true
	save_stats()
	return improved

func calc_run_stones(time_sec: float, kills: int, victory: bool, stone_mult: float = 1.0, curse_pct: float = 0.0) -> int:
	var base := int(floor(time_sec / 20.0)) + int(floor(float(kills) / 25.0)) + (60 if victory else 5)
	var curse_mult := 1.0 + maxf(0.0, curse_pct) * 1.5
	return maxi(5, int(round(float(base) * stone_mult * curse_mult)))

func add_spirit_stones(amount: int) -> void:
	if amount <= 0:
		return
	spirit_stones += amount
	save_stats()

func get_sect_level(uid: String) -> int:
	return int(sect_upgrades.get(uid, 0))

func get_total_seal_bonus() -> int:
	return get_sect_level("seal") + bonus_seal_slots

func get_sect_cost(uid: String) -> int:
	var lv := get_sect_level(uid)
	for item in SECT_CATALOG:
		if str(item["id"]) == uid:
			var costs: Array = item["costs"]
			if lv >= costs.size():
				return -1
			return int(costs[lv])
	return -1

func buy_sect_upgrade(uid: String) -> bool:
	var cost := get_sect_cost(uid)
	if cost < 0 or spirit_stones < cost:
		return false
	spirit_stones -= cost
	sect_upgrades[uid] = get_sect_level(uid) + 1
	save_stats()
	return true

func get_sect_invested_stones() -> int:
	var total := 0
	for item in SECT_CATALOG:
		var uid := str(item["id"])
		var lv := get_sect_level(uid)
		var costs: Array = item["costs"]
		for i in range(mini(lv, costs.size())):
			total += int(costs[i])
	return total

func recycle_sect_upgrades() -> int:
	var refund := get_sect_invested_stones()
	if refund <= 0:
		return 0
	for item in SECT_CATALOG:
		sect_upgrades[str(item["id"])] = 0
	spirit_stones += refund
	save_stats()
	return refund

func get_sect_stat_mods() -> Dictionary:
	return {
		"armor": float(get_sect_level("armor")) * 1.0,
		"hp_regen": float(get_sect_level("regen")) * 0.4,
		"attack_speed_pct": float(get_sect_level("attack_speed")) * 0.05,
		"area_pct": float(get_sect_level("area")) * 0.06,
		"crit_chance": float(get_sect_level("crit")) * 0.03,
		"luck": float(get_sect_level("luck")) * 0.10,
		"curse_pct": float(get_sect_level("curse")) * 0.10,
	}

func load_achievements_catalog() -> Array[Dictionary]:
	if not _achievements_cache.is_empty():
		return _achievements_cache
	if FileAccess.file_exists(ACHIEVEMENTS_JSON_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACHIEVEMENTS_JSON_PATH))
		if parsed is Dictionary and parsed.has("achievements") and parsed["achievements"] is Array:
			for raw in parsed["achievements"]:
				if raw is Dictionary:
					_achievements_cache.append((raw as Dictionary).duplicate(true))
	return _achievements_cache

func is_achievement_unlocked(ach_id: String) -> bool:
	return unlocked_achievements.has(ach_id)

func is_arcana_unlocked(arcana_id: String) -> bool:
	return unlocked_arcanas.has(arcana_id)

func evaluate_run_achievements(run_summary: Dictionary, persist: bool = true) -> Array[Dictionary]:
	total_kills += maxi(0, int(run_summary.get("run_kills", 0)))
	total_reactions += maxi(0, int(run_summary.get("run_reactions", 0)))
	total_fusions += maxi(0, int(run_summary.get("run_fusions", 0)))
	total_jars_broken += maxi(0, int(run_summary.get("run_jars_broken", 0)))
	var newly_unlocked: Array[Dictionary] = []
	for ach in load_achievements_catalog():
		var aid := str(ach.get("id", ""))
		if aid.is_empty() or unlocked_achievements.has(aid):
			continue
		if _check_achievement_condition(ach, run_summary):
			unlocked_achievements.append(aid)
			_apply_achievement_reward(ach)
			newly_unlocked.append(ach.duplicate(true))
	if persist:
		save_stats()
	return newly_unlocked

func _check_achievement_condition(ach: Dictionary, run_summary: Dictionary) -> bool:
	var metric := str(ach.get("metric", ""))
	var target := float(ach.get("target", 1))
	match metric:
		"total_runs":
			return float(total_runs) >= target
		"run_kills":
			return float(run_summary.get("run_kills", 0)) >= target
		"total_kills":
			return float(total_kills) >= target
		"run_level":
			return float(run_summary.get("run_level", 0)) >= target
		"run_time":
			return float(run_summary.get("run_time", 0.0)) >= target
		"cleared_stage_1":
			return is_stage_cleared(1)
		"cleared_stage_2":
			return is_stage_cleared(2)
		"cleared_stage_3":
			return is_stage_cleared(3)
		"cleared_stage_4":
			return is_stage_cleared(4)
		"cleared_stage_5":
			return is_stage_cleared(5)
		"run_reactions":
			return float(run_summary.get("run_reactions", 0)) >= target
		"total_reactions":
			return float(total_reactions) >= target
		"run_fusions":
			return float(run_summary.get("run_fusions", 0)) >= target
		"total_jars_broken":
			return float(total_jars_broken) >= target
		"curse_victory_pct":
			var victory := bool(run_summary.get("victory", false))
			var curse_pct_int := roundf(float(run_summary.get("curse_pct", 0.0)) * 100.0)
			return victory and curse_pct_int >= target
		"sect_invested":
			return float(get_sect_invested_stones()) >= target
		_:
			return false

func _apply_achievement_reward(ach: Dictionary) -> void:
	var rtype := str(ach.get("reward_type", ""))
	var rid := str(ach.get("reward_id", ""))
	var rval := int(ach.get("reward_value", 0))
	match rtype:
		"spirit_stones":
			spirit_stones += maxi(0, rval)
		"unlock_arcana":
			if not rid.is_empty() and not unlocked_arcanas.has(rid):
				unlocked_arcanas.append(rid)
		"bonus_seal":
			bonus_seal_slots += maxi(0, rval)

func mark_stage_cleared(stage_id: int) -> void:
	if stage_id >= 1 and not cleared_stages.has(stage_id):
		cleared_stages.append(stage_id)
		save_stats()

func is_stage_cleared(stage_id: int) -> bool:
	return cleared_stages.has(stage_id)

func has_history() -> bool:
	return total_runs > 0

func format_time(seconds: float) -> String:
	var s = int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]

func summary_text() -> String:
	if not has_history():
		return ""
	return "最长修行 %s · 最高境界 Lv.%d · 最多诛魔 %d · 累计 %d 局" % [
		format_time(best_time), best_level, best_kills, total_runs
	]
