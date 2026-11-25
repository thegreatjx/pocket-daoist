class_name ReactionEngine
extends RefCounted

var loader: V2DataLoader
var _aura_dur: float = 3.5
var _icd_sec: float = 1.8
var _boss_icd_sec: float = 1.2
var _global_vfx_cap: int = 12
var _modifiers: Dictionary = {}
var _enemy_auras: Dictionary = {}
var _enemy_icd: Dictionary = {}
var _vfx_timestamps: Array[float] = []

func _init(data_loader: V2DataLoader) -> void:
	loader = data_loader
	_aura_dur = float(loader.reaction_config.get("aura_duration_sec", 3.5))
	_icd_sec = float(loader.reaction_config.get("per_enemy_icd_sec", 1.8))
	_boss_icd_sec = float(loader.reaction_config.get("boss_icd_sec", 1.2))
	_global_vfx_cap = int(loader.reaction_config.get("global_vfx_cap_per_sec", 12))

func configure_modifiers(mods: Dictionary) -> void:
	_modifiers = mods.duplicate()

func apply_element_hit(
	enemy_id: int,
	incoming_elem: String,
	now_sec: float,
	base_damage: float,
	mastery_bonus: float = 0.0,
	mods: Dictionary = {},
	is_boss: bool = false
) -> Dictionary:
	if incoming_elem.is_empty():
		return {}

	var eff_mods: Dictionary = _modifiers if mods.is_empty() else _merge_mods(_modifiers, mods)
	var auras: Dictionary = _enemy_auras.get(enemy_id, {})
	for k in auras.keys():
		if float(auras[k]) <= now_sec:
			auras.erase(k)

	var icd_ready: float = float(_enemy_icd.get(enemy_id, 0.0))
	if now_sec >= icd_ready:
		for existing_elem in auras.keys():
			if String(existing_elem) == incoming_elem:
				continue
			var key: String = V2DataLoader.make_pair_key(String(existing_elem), incoming_elem)
			if loader.reactions_by_key.has(key):
				var rx: Dictionary = loader.reactions_by_key[key]
				var rx_id: String = String(rx["id"])
				auras.erase(existing_elem)
				_enemy_auras[enemy_id] = auras
				var base_icd: float = _boss_icd_sec if is_boss else _icd_sec
				var icd_red: float = clampf(float(eff_mods.get("reaction_icd_reduction", 0.0)), 0.0, 0.45)
				var eff_icd: float = maxf(0.70 if is_boss else 0.05, base_icd - icd_red)
				_enemy_icd[enemy_id] = now_sec + eff_icd

				var total_mastery: float = minf(3.5, mastery_bonus + float(eff_mods.get("reaction_damage_pct", 0.0)))
				var base_mult: float = float(rx.get("damage_mult", 1.5))
				if rx_id == "react_shatter":
					base_mult += float(eff_mods.get("shatter_mult_bonus", 0.0))
				var mult: float = base_mult * (1.0 + total_mastery)
				var aoe_r: float = float(rx.get("aoe_radius", 0.0)) * (1.0 + float(eff_mods.get("reaction_radius_pct", 0.0)))
				var chain_count: int = int(rx.get("chain_count", 0))
				if chain_count > 0:
					chain_count += int(eff_mods.get("chain_bonus", 0))

				return {
					"reaction_id": rx_id,
					"name": String(rx["name"]),
					"bonus_damage": base_damage * mult,
					"aoe_radius": aoe_r,
					"chain_count": chain_count,
					"emit_vfx": _consume_vfx_budget(now_sec),
					"vfx_color": String(rx.get("vfx_color", "#FFFFFF")),
					"sfx_cue": String(rx.get("sfx_cue", "")),
					"spec": rx
				}
	else:
		for existing_elem in auras.keys():
			if String(existing_elem) != incoming_elem:
				var pair_key: String = V2DataLoader.make_pair_key(String(existing_elem), incoming_elem)
				if loader.reactions_by_key.has(pair_key):
					_enemy_auras[enemy_id] = auras
					return {}

	var dur: float = _aura_dur
	if incoming_elem == "fire":
		dur += float(eff_mods.get("fire_aura_dur_bonus", 0.0))
	auras[incoming_elem] = now_sec + dur
	_enemy_auras[enemy_id] = auras
	return {}

func get_aura_elements(enemy_id: int, now_sec: float) -> Array[String]:
	var out: Array[String] = []
	var auras: Dictionary = _enemy_auras.get(enemy_id, {})
	for k in auras.keys():
		if float(auras[k]) > now_sec:
			out.append(String(k))
	return out

func has_aura(enemy_id: int, elem: String, now_sec: float) -> bool:
	var auras: Dictionary = _enemy_auras.get(enemy_id, {})
	return auras.has(elem) and float(auras[elem]) > now_sec

func clear_enemy(enemy_id: int) -> void:
	_enemy_auras.erase(enemy_id)
	_enemy_icd.erase(enemy_id)

func prune_stale(now_sec: float) -> void:
	for eid in _enemy_auras.keys():
		var auras: Dictionary = _enemy_auras[eid]
		for k in auras.keys():
			if float(auras[k]) <= now_sec:
				auras.erase(k)
		if auras.is_empty():
			_enemy_auras.erase(eid)
	for eid in _enemy_icd.keys():
		if float(_enemy_icd[eid]) <= now_sec:
			_enemy_icd.erase(eid)

func _consume_vfx_budget(now_sec: float) -> bool:
	var cutoff: float = now_sec - 1.0
	var write_idx: int = 0
	for i in range(_vfx_timestamps.size()):
		if _vfx_timestamps[i] >= cutoff:
			_vfx_timestamps[write_idx] = _vfx_timestamps[i]
			write_idx += 1
	_vfx_timestamps.resize(write_idx)
	if _vfx_timestamps.size() >= _global_vfx_cap:
		return false
	_vfx_timestamps.append(now_sec)
	return true

func _merge_mods(base_mods: Dictionary, extra: Dictionary) -> Dictionary:
	var out: Dictionary = base_mods.duplicate()
	for k in extra.keys():
		out[k] = float(out.get(k, 0.0)) + float(extra[k])
	return out
