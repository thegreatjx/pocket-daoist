class_name CharacterData

const DATA_PATH := "res://data/v2/characters_v2.json"

static var _cache: Array[Dictionary] = []

static func reload() -> void:
	_cache.clear()
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			for raw in (parsed as Dictionary).get("characters", []):
				if raw is Dictionary:
					_cache.append(_normalize(raw as Dictionary))
	if _cache.is_empty():
		_cache.append(_normalize({
			"id": "sword_immortal",
			"name": "沈砚",
			"role": "御剑道君",
			"desc": "脚踏本命青霜飞剑御空游斗，玄袍金纹束冠掐剑诀，号令漫天飞剑与百宝神通。",
			"sprite": "res://assets/v2/heroes/hero_sword_qwen.png",
			"motion_mode": "hover_ride",
			"mount_type": "sword",
			"draw_height": 88.0,
			"start_weapon": "lotus_slash",
			"v2_start_weapon": "wpn_jade_sword",
			"element_affinity": "metal",
			"affinity_bonus_pct": 0.15,
			"unlock_condition": {"type": "default", "desc": "初始可用"},
			"accent_color": "#42EBD1",
			"trait_mods": {"attack_speed_pct": 0.10, "crit_chance": 0.04},
			"trait_summary": "+10% 攻速 · +4% 暴击 · 金系亲和 +15%",
			"max_health": 120.0,
			"speed": 250.0,
			"crit_chance": 0.12,
			"magnet_radius": 170.0,
			"active_name": "御剑瞬步",
			"active_desc": "向移动方向高速瞬步穿怪脱身（纯位移无敌，无伤害与技能特效）。"
		}))

static func _normalize(raw: Dictionary) -> Dictionary:
	var d := raw.duplicate(true)
	var col_val: Variant = d.get("accent_color", "#42EBD1")
	if col_val is String:
		d["accent_color"] = Color.from_string(String(col_val), Color(0.26, 0.92, 0.82))
	elif not (col_val is Color):
		d["accent_color"] = Color(0.26, 0.92, 0.82)
	if not d.has("element_affinity"):
		d["element_affinity"] = "metal"
	if not d.has("affinity_bonus_pct"):
		d["affinity_bonus_pct"] = 0.15
	if not d.has("unlock_condition") or not (d["unlock_condition"] is Dictionary):
		d["unlock_condition"] = {"type": "default", "desc": "初始可用"}
	return d

static func all() -> Array[Dictionary]:
	if _cache.is_empty():
		reload()
	return _cache

static func get_character(char_id: String) -> Dictionary:
	for c in all():
		if str(c["id"]) == char_id:
			return c
	return all()[0]

static func get_v2_start_weapon(char_id: String) -> String:
	return str(get_character(char_id).get("v2_start_weapon", "wpn_jade_sword"))

static func get_element_affinity(char_id: String) -> String:
	return str(get_character(char_id).get("element_affinity", "metal"))

static func get_affinity_bonus(char_id: String) -> float:
	return float(get_character(char_id).get("affinity_bonus_pct", 0.15))

static func is_unlocked(char_id: String, stats_node: Object = null) -> bool:
	var c := get_character(char_id)
	var cond: Dictionary = c.get("unlock_condition", {"type": "default"})
	var ctype := str(cond.get("type", "default"))
	if ctype == "default" or ctype == "":
		return true
	if stats_node == null:
		return true
	var req_val := int(cond.get("value", 0))
	match ctype:
		"best_kills":
			return int(stats_node.get("best_kills")) >= req_val
		"best_level":
			return int(stats_node.get("best_level")) >= req_val
		"total_runs":
			return int(stats_node.get("total_runs")) >= req_val
		"clear_stage":
			if stats_node.has_method("is_stage_cleared"):
				return bool(stats_node.call("is_stage_cleared", req_val))
			return false
		_:
			return true
