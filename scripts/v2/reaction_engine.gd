class_name ReactionEngine
extends RefCounted

var loader: V2DataLoader
var _aura_dur: float = 3.5
var _icd_sec: float = 2.0
var _min_icd_sec: float = 1.2
var _boss_icd_sec: float = 2.5
var _min_boss_icd_sec: float = 1.6
var _mastery_cap: float = 1.0
var _boss_damage_scale: float = 0.60
var _boss_cc_scale: float = 0.35
var _global_vfx_cap: int = 12
var _modifiers: Dictionary = {}
var _enemy_auras: Dictionary = {}
var _enemy_icd: Dictionary = {}
var _vfx_timestamps: Array[float] = []

func _init(data_loader: V2DataLoader) -> void:
	loader = data_loader
	if loader != null:
		var cfg: Dictionary = loader.reaction_config
		_aura_dur = float(cfg.get("aura_duration_sec", 3.5))
		_icd_sec = float(cfg.get("per_enemy_icd_sec", 2.0))
		_min_icd_sec = float(cfg.get("min_enemy_icd_sec", 1.2))
		_boss_icd_sec = float(cfg.get("boss_icd_sec", 2.5))
		_min_boss_icd_sec = float(cfg.get("min_boss_icd_sec", 1.6))
		_mastery_cap = float(cfg.get("mastery_cap", 1.0))
		_boss_damage_scale = float(cfg.get("boss_damage_scale", 0.60))
		_boss_cc_scale = float(cfg.get("boss_cc_scale", 0.35))
		_global_vfx_cap = int(cfg.get("global_vfx_cap_per_sec", 12))

func configure_modifiers(mods: Dictionary) -> void:
	_modifiers = mods.duplicate()

func apply_element_hit(
	enemy_id: int,
	incoming_elem: String,
	now_sec: float,
	base_damage: float,
	mastery_bonus: float = 0.0,
	mods: Dictionary = {},
	is_boss: bool = false,
	is_frozen: bool = false,
	is_reaction_damage: bool = false
) -> Dictionary:
	# 无属性器道、空元素、反应衍生伤严禁进入反应链，防止二次套娃
	if is_reaction_damage or incoming_elem.is_empty() or incoming_elem == "none":
		return {}
	if loader == null:
		return {}

	var eff_mods: Dictionary = _modifiers if mods.is_empty() else _merge_mods(_modifiers, mods)

	var aura: Dictionary = _enemy_auras.get(enemy_id, {})
	if not aura.is_empty() and float(aura.get("expires", 0.0)) <= now_sec:
		aura.clear()
		_enemy_auras.erase(enemy_id)

	# 破冰裂罡绕过冰封自带 ICD，保证「冰+水→吃金」二段破盾顺滑打出
	if is_frozen and incoming_elem == "metal" and not loader.shatter_reaction.is_empty():
		var sh: Dictionary = loader.shatter_reaction
		_enemy_auras.erase(enemy_id)
		_set_enemy_icd(enemy_id, now_sec, is_boss, eff_mods)
		var sh_dmg: float = _calc_reaction_damage(base_damage, sh, mastery_bonus, eff_mods, is_boss)
		var sh_aoe: float = float(sh.get("aoe_radius", 85.0)) * (1.0 + float(eff_mods.get("reaction_radius_pct", 0.0)))
		return {
			"reaction_id": String(sh.get("id", "react_shatter")),
			"short_name": String(sh.get("short_name", "破冰")),
			"name": String(sh.get("name", "破冰裂罡")),
			"bonus_damage": sh_dmg,
			"aoe_radius": sh_aoe,
			"chain_count": 0,
			"unfreeze": true,
			"shield_max_pct": float(sh.get("shield_max_pct", 0.18)),
			"shield_flat_min": float(sh.get("shield_flat_min", 90.0)),
			"cc_scale": _boss_cc_scale if is_boss else 1.0,
			"emit_vfx": _consume_vfx_budget(now_sec),
			"vfx_color": String(sh.get("vfx_color", "#9AE6FF")),
			"sfx_cue": String(sh.get("sfx_cue", "sfx_react_shatter")),
			"spec": sh,
		}

	var existing_elem: String = String(aura.get("elem", ""))
	if not existing_elem.is_empty():
		if existing_elem == incoming_elem:
			aura["expires"] = now_sec + _calc_aura_dur(incoming_elem, eff_mods)
			_enemy_auras[enemy_id] = aura
			return {}

		var pair_key: String = V2DataLoader.make_pair_key(existing_elem, incoming_elem)
		if loader.reactions_by_key.has(pair_key):
			var icd_ready: float = float(_enemy_icd.get(enemy_id, 0.0))
			if now_sec < icd_ready:
				return {}

			var rx: Dictionary = loader.reactions_by_key[pair_key]
			var rx_id: String = String(rx.get("id", ""))
			_enemy_auras.erase(enemy_id)
			_set_enemy_icd(enemy_id, now_sec, is_boss, eff_mods)

			var bonus_dmg: float = _calc_reaction_damage(base_damage, rx, mastery_bonus, eff_mods, is_boss)
			var aoe_r: float = float(rx.get("aoe_radius", 0.0)) * (1.0 + float(eff_mods.get("reaction_radius_pct", 0.0)))
			var chain_count: int = int(rx.get("chain_count", 0))
			if chain_count > 0:
				chain_count += int(eff_mods.get("chain_bonus", 0))

			return {
				"reaction_id": rx_id,
				"short_name": String(rx.get("short_name", rx.get("name", ""))),
				"name": String(rx.get("name", "")),
				"bonus_damage": bonus_dmg,
				"aoe_radius": aoe_r,
				"chain_count": chain_count,
				"unfreeze": false,
				"cc_scale": _boss_cc_scale if is_boss else 1.0,
				"emit_vfx": _consume_vfx_budget(now_sec),
				"vfx_color": String(rx.get("vfx_color", "#FFFFFF")),
				"sfx_cue": String(rx.get("sfx_cue", "")),
				"spec": rx,
			}
		else:
			# 不发生反应的异属元素保持先到印记，不互相覆盖吞印记
			return {}

	_enemy_auras[enemy_id] = {
		"elem": incoming_elem,
		"expires": now_sec + _calc_aura_dur(incoming_elem, eff_mods),
	}
	return {}

func _calc_aura_dur(elem: String, eff_mods: Dictionary) -> float:
	var dur: float = _aura_dur
	if elem == "fire":
		dur += float(eff_mods.get("fire_aura_dur_bonus", 0.0))
	return dur

func _set_enemy_icd(enemy_id: int, now_sec: float, is_boss: bool, eff_mods: Dictionary) -> void:
	var base_icd: float = _boss_icd_sec if is_boss else _icd_sec
	var min_icd: float = _min_boss_icd_sec if is_boss else _min_icd_sec
	var icd_red: float = clampf(float(eff_mods.get("reaction_icd_reduction", 0.0)), 0.0, 0.45)
	_enemy_icd[enemy_id] = now_sec + maxf(min_icd, base_icd - icd_red)

func _calc_reaction_damage(
	base_damage: float,
	rx: Dictionary,
	mastery_bonus: float,
	eff_mods: Dictionary,
	is_boss: bool
) -> float:
	var total_mastery: float = clampf(mastery_bonus + float(eff_mods.get("reaction_damage_pct", 0.0)), 0.0, _mastery_cap)
	var base_mult: float = float(rx.get("damage_mult", 0.20))
	var dmg: float = base_damage * base_mult * (1.0 + total_mastery)
	if is_boss:
		dmg *= _boss_damage_scale
	return maxf(1.0, dmg)

func get_aura_elements(enemy_id: int, now_sec: float) -> Array[String]:
	var out: Array[String] = []
	var aura: Dictionary = _enemy_auras.get(enemy_id, {})
	if not aura.is_empty() and float(aura.get("expires", 0.0)) > now_sec:
		out.append(String(aura.get("elem", "")))
	return out

func has_aura(enemy_id: int, elem: String, now_sec: float) -> bool:
	var aura: Dictionary = _enemy_auras.get(enemy_id, {})
	return not aura.is_empty() and String(aura.get("elem", "")) == elem and float(aura.get("expires", 0.0)) > now_sec

func clear_enemy(enemy_id: int) -> void:
	_enemy_auras.erase(enemy_id)
	_enemy_icd.erase(enemy_id)

func prune_stale(now_sec: float) -> void:
	for eid in _enemy_auras.keys():
		var aura: Dictionary = _enemy_auras[eid]
		if float(aura.get("expires", 0.0)) <= now_sec:
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
