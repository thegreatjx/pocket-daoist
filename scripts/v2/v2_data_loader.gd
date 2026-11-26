class_name V2DataLoader
extends Node

const BASE_PLAYER_SPEED := 250.0
const BASE_ENEMY_SPEED := 110.0
const BASE_UNIT_HP := 16.0

var weapons_by_id: Dictionary = {}
var fusion_recipes: Array = []
var max_weapon_slots: int = 4
var max_weapon_level: int = 8
var realm_slot_unlocks: Array = []
var reactions_by_key: Dictionary = {}
var reactions_list: Array[Dictionary] = []
var shatter_reaction: Dictionary = {}
var reaction_config: Dictionary = {}
var items_by_id: Dictionary = {}
var shop_economy: Dictionary = {}
var base_constants: Dictionary = {}
var enemy_archetypes: Dictionary = {}
var wave_config: Dictionary = {}
var stages: Array[Dictionary] = []
var stages_by_id: Dictionary = {}
var characters: Array[Dictionary] = []
var characters_by_id: Dictionary = {}
var arcanas: Array[Dictionary] = []
var arcanas_by_id: Dictionary = {}
var pickups: Array[Dictionary] = []
var pickups_by_id: Dictionary = {}
var achievements: Array[Dictionary] = []
var achievements_by_id: Dictionary = {}
var elite_affixes: Array[Dictionary] = []
var elite_affixes_by_id: Dictionary = {}

func load_all(base_dir: String = "res://data/v2") -> bool:
	var w_data: Dictionary = _read_json(base_dir.path_join("weapons_v2.json"))
	var r_data: Dictionary = _read_json(base_dir.path_join("reactions_v2.json"))
	var i_data: Dictionary = _read_json(base_dir.path_join("items_v2.json"))
	var e_data: Dictionary = _read_json(base_dir.path_join("enemies_waves_v2.json"))
	var s_data: Dictionary = _read_json(base_dir.path_join("stages_v2.json"))
	if w_data.is_empty() or r_data.is_empty() or i_data.is_empty() or e_data.is_empty() or s_data.is_empty():
		push_error("V2DataLoader: Failed to load one or more JSON files in %s" % base_dir)
		return false

	weapons_by_id.clear()
	for w in w_data.get("weapons", []):
		weapons_by_id[String(w["id"])] = w
	fusion_recipes = w_data.get("fusion_recipes", [])
	max_weapon_slots = int(w_data.get("max_weapon_slots", 4))
	max_weapon_level = int(w_data.get("max_weapon_level", 8))
	realm_slot_unlocks = w_data.get("realm_slot_unlocks", [])

	reactions_by_key.clear()
	reactions_list.clear()
	shatter_reaction.clear()
	reaction_config = r_data
	for r_raw in r_data.get("reactions", []):
		if not (r_raw is Dictionary):
			continue
		var r: Dictionary = r_raw
		reactions_list.append(r)
		var trig_list: Array = r.get("triggers", [])
		if trig_list.is_empty():
			var fallback_pair: Array = r.get("pair", [])
			if fallback_pair.size() >= 2:
				trig_list = [fallback_pair]
		for pair_item in trig_list:
			if pair_item is Array and (pair_item as Array).size() >= 2:
				var pa: String = String((pair_item as Array)[0])
				var pb: String = String((pair_item as Array)[1])
				reactions_by_key[make_pair_key(pa, pb)] = r
	var sh_raw: Variant = r_data.get("shatter_reaction", {})
	if sh_raw is Dictionary:
		shatter_reaction = sh_raw

	items_by_id.clear()
	shop_economy = i_data.get("shop_economy", {})
	for it in i_data.get("items", []):
		items_by_id[String(it["id"])] = it

	var raw_consts: Variant = e_data.get("base_constants", {})
	base_constants = raw_consts if raw_consts is Dictionary else {}
	var unit_hp := get_unit_hp()
	var enemy_spd := get_base_enemy_speed()

	enemy_archetypes.clear()
	wave_config = e_data
	for arch_raw in e_data.get("archetypes", []):
		if arch_raw is Dictionary:
			var resolved := resolve_archetype_stats(arch_raw, unit_hp, enemy_spd)
			enemy_archetypes[String(resolved["id"])] = resolved

	stages.clear()
	stages_by_id.clear()
	for st_raw in s_data.get("stages", []):
		if st_raw is Dictionary:
			var st := normalize_stage(st_raw)
			stages.append(st)
			stages_by_id[int(st.get("id", stages.size()))] = st

	characters.clear()
	characters_by_id.clear()
	var c_path := base_dir.path_join("characters_v2.json")
	if FileAccess.file_exists(c_path):
		var c_data: Dictionary = _read_json(c_path)
		for c_raw in c_data.get("characters", []):
			if c_raw is Dictionary:
				var ch := (c_raw as Dictionary).duplicate(true)
				characters.append(ch)
				characters_by_id[String(ch.get("id", ""))] = ch

	arcanas.clear()
	arcanas_by_id.clear()
	var a_path := base_dir.path_join("arcana_v2.json")
	if FileAccess.file_exists(a_path):
		var a_data: Dictionary = _read_json(a_path)
		for a_raw in a_data.get("arcanas", []):
			if a_raw is Dictionary:
				var arc := (a_raw as Dictionary).duplicate(true)
				arcanas.append(arc)
				arcanas_by_id[String(arc.get("id", ""))] = arc

	pickups.clear()
	pickups_by_id.clear()
	var p_path := base_dir.path_join("pickups_v2.json")
	if FileAccess.file_exists(p_path):
		var p_data: Dictionary = _read_json(p_path)
		for p_raw in p_data.get("pickups", []):
			if p_raw is Dictionary:
				var pk := (p_raw as Dictionary).duplicate(true)
				pickups.append(pk)
				pickups_by_id[String(pk.get("id", ""))] = pk

	achievements.clear()
	achievements_by_id.clear()
	var ach_path := base_dir.path_join("achievements_v2.json")
	if FileAccess.file_exists(ach_path):
		var ach_data: Dictionary = _read_json(ach_path)
		for ach_raw in ach_data.get("achievements", []):
			if ach_raw is Dictionary:
				var ac := (ach_raw as Dictionary).duplicate(true)
				achievements.append(ac)
				achievements_by_id[String(ac.get("id", ""))] = ac

	elite_affixes.clear()
	elite_affixes_by_id.clear()
	var aff_path := base_dir.path_join("elite_affixes.json")
	if FileAccess.file_exists(aff_path):
		var aff_data: Dictionary = _read_json(aff_path)
		for aff_raw in aff_data.get("affixes", []):
			if aff_raw is Dictionary:
				var aff := (aff_raw as Dictionary).duplicate(true)
				elite_affixes.append(aff)
				elite_affixes_by_id[String(aff.get("id", ""))] = aff

	return true

func get_unit_hp() -> float:
	return float(base_constants.get("unit_hp", BASE_UNIT_HP))

func get_base_enemy_speed() -> float:
	return float(base_constants.get("enemy_speed", BASE_ENEMY_SPEED))

func get_base_player_speed() -> float:
	return float(base_constants.get("player_speed", BASE_PLAYER_SPEED))

func get_random_elite_affix() -> Dictionary:
	if elite_affixes.is_empty():
		return {}
	return (elite_affixes[randi() % elite_affixes.size()] as Dictionary).duplicate(true)

func get_elite_affix(affix_id: String) -> Dictionary:
	if not elite_affixes_by_id.has(affix_id):
		return {}
	return (elite_affixes_by_id[affix_id] as Dictionary).duplicate(true)

func get_stage(stage_id: int) -> Dictionary:
	if not stages_by_id.has(stage_id):
		return {}
	return (stages_by_id[stage_id] as Dictionary).duplicate(true)

func get_stage_by_index(index: int) -> Dictionary:
	if index < 0 or index >= stages.size():
		return {}
	return stages[index].duplicate(true)

func get_character(char_id: String) -> Dictionary:
	if not characters_by_id.has(char_id):
		return {}
	return (characters_by_id[char_id] as Dictionary).duplicate(true)

func get_arcana(arcana_id: String) -> Dictionary:
	if not arcanas_by_id.has(arcana_id):
		return {}
	return (arcanas_by_id[arcana_id] as Dictionary).duplicate(true)

func get_pickup(pickup_id: String) -> Dictionary:
	if not pickups_by_id.has(pickup_id):
		return {}
	return (pickups_by_id[pickup_id] as Dictionary).duplicate(true)

func get_achievement(ach_id: String) -> Dictionary:
	if not achievements_by_id.has(ach_id):
		return {}
	return (achievements_by_id[ach_id] as Dictionary).duplicate(true)

static func resolve_archetype_stats(raw_arch: Dictionary, unit_hp: float = BASE_UNIT_HP, enemy_spd: float = BASE_ENEMY_SPEED) -> Dictionary:
	var out := raw_arch.duplicate(true)
	if out.has("hp_units"):
		out["base_hp"] = roundf(float(out["hp_units"]) * unit_hp)
	if out.has("speed_pct"):
		out["move_speed"] = float(out["speed_pct"]) * 0.01 * enemy_spd
	var dash_cfg: Variant = out.get("dash_telegraph", null)
	if dash_cfg is Dictionary:
		var dash_dict := dash_cfg as Dictionary
		if dash_dict.has("charge_speed_pct"):
			var c_spd := float(dash_dict["charge_speed_pct"]) * 0.01 * enemy_spd
			dash_dict["charge_speed"] = c_spd
			out["charge_speed"] = c_spd
	var ranged_cfg: Variant = out.get("ranged_attack", null)
	if ranged_cfg is Dictionary:
		var r_dict := ranged_cfg as Dictionary
		if r_dict.has("preferred_dist_min") and not out.has("preferred_dist_min"):
			out["preferred_dist_min"] = float(r_dict["preferred_dist_min"])
		if r_dict.has("preferred_dist_max") and not out.has("preferred_dist_max"):
			out["preferred_dist_max"] = float(r_dict["preferred_dist_max"])
	var res_cfg: Variant = out.get("resistances", null)
	if res_cfg is Dictionary and (res_cfg as Dictionary).has("knockback_resist") and not out.has("knockback_resist"):
		out["knockback_resist"] = float((res_cfg as Dictionary)["knockback_resist"])
	return out

static func normalize_stage(raw_stage: Dictionary) -> Dictionary:
	var st := raw_stage.duplicate(true)
	var pal: Variant = st.get("palette", null)
	if pal is Dictionary:
		var pal_dict := pal as Dictionary
		var g_val = pal_dict.get("ground", null)
		if g_val is String:
			pal_dict["ground"] = Color.from_string(String(g_val), Color(0.31, 0.36, 0.34, 1.0))
		var t_val = pal_dict.get("tint", null)
		if t_val is String:
			pal_dict["tint"] = Color.from_string(String(t_val), Color(0.24, 0.82, 0.70, 1.0))
	return st

static func make_pair_key(a: String, b: String) -> String:
	return "%s+%s" % ([a, b] if a <= b else [b, a])

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("V2DataLoader: Missing file %s" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}
