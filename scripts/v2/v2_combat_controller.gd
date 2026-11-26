class_name V2CombatController
extends Node2D

signal v2_loadout_changed
signal gold_changed(gold: int)
signal realm_slot_unlocked(new_slots: int, realm_name: String, reason: String)

const DAMAGE_NUMBER_SCENE := "res://scenes/damage_number.tscn"
const SALVO_STAGGER_SEC := 0.035
const MAX_PENDING_SALVOS := 48
const QIANKUN_BAG_MINION_CHANCE := 0.004
const QIANKUN_BAG_ELITE_CHANCE := 0.06
const VENOM_SPIRIT_SCRIPT := preload("res://scripts/v2/venom_spirit.gd")

const DEFAULT_REALM_UNLOCKS := [
	{"slots": 1, "level": 1, "realm": "练气"},
	{"slots": 2, "level": 5, "realm": "筑基"},
	{"slots": 3, "level": 11, "realm": "金丹"},
	{"slots": 4, "level": 18, "realm": "元婴", "alt_elite_kills": 2},
]

const CUE_FALLBACK_PATHS := {
	"sfx_sword_whoosh": "res://assets/audio/sword_cast.wav",
	"sfx_fusion_sword_array": "res://assets/audio/sword_cast.wav",
	"sfx_fire_lob": "res://assets/audio/fire_gourd_burn.wav",
	"sfx_thunder_snap": "res://assets/audio/thunder_arc_snap.wav",
	"sfx_fusion_thunder_ice": "res://assets/audio/thunder.wav",
	"sfx_ice_chime": "res://assets/audio/sword_hit.wav",
	"sfx_water_ripple": "res://assets/audio/water_ripple_splash.wav",
	"sfx_hit": "res://assets/audio/sword_hit.wav",
	"sfx_venom_hiss": "res://assets/audio/jar_break.wav",
	"sfx_bell_gong": "res://assets/audio/cannon_blast.wav",
	"sfx_fusion_zen_bell": "res://assets/audio/cannon_blast.wav",
	"sfx_react_boom": "res://assets/audio/cannon_blast.wav",
	"sfx_react_steam": "res://assets/audio/jar_break.wav",
	"sfx_react_pop": "res://assets/audio/jar_break.wav",
	"sfx_react_zap": "res://assets/audio/thunder.wav",
	"sfx_react_shatter": "res://assets/audio/sword_hit.wav",
	"sfx_react_freeze": "res://assets/audio/sword_hit.wav",
	"sfx_react_slash": "res://assets/audio/sword_cast.wav",
	"sfx_react_forge": "res://assets/audio/cannon_blast.wav",
	"sfx_crit_hit": "res://assets/audio/sword_hit.wav",
	"xp_orb": "res://assets/audio/gem_pickup.wav",
	"ui_event": "res://assets/audio/chest_open.wav",
}

var player: Player = null
var loader: V2DataLoader = null
var orbit_rig: OrbitWeaponRig = null
var reaction_engine: ReactionEngine = null
var audio_mgr: ThrottledAudioManager = null

var run_gold: int = 0
var owned_items: Array[Dictionary] = []
var item_mods: Dictionary = {}
var realm_bonuses: Dictionary = {}
var stat_pick_counts: Dictionary = {}
var unlocked_weapon_slots: int = 1
var active_arcanas: Array[String] = []
var weapon_limit_breaks: Dictionary = {}
var revival_stacks: int = 0
var _void_magnet_timer: float = 0.0
var reaction_count: int = 0
var fusion_count: int = 0
var elite_kills_for_slots: int = 0
var pending_new_weapon_picks: int = 0

var _streams: Dictionary = {}
var _shot_seq: int = 0
var _shot_hit_counts: Dictionary = {}
var _fusion_elem_toggle: Dictionary = {}
var _lifesteal_budget: float = 0.0
var _orb_counter: int = 0
var _prune_timer: float = 0.0
var _reaction_pop_budget: int = 12
var _reaction_pop_timer: float = 0.0
var _pending_salvos: Array[Dictionary] = []
var _gold_frac: float = 0.0
var _drop_wave: int = 1
var _wave_dropped_gold: int = 0
var _bell_resonance_icd: Dictionary = {}
var bell_resonance_counts: Dictionary = {}
var bell_resonance_total: int = 0
var soul_seal_spread_count: int = 0

func setup_for_player(p: Player) -> void:
	player = p
	loader = V2DataLoader.new()
	loader.name = "V2DataLoader"
	add_child(loader)
	loader.load_all("res://data/v2")

	reaction_engine = ReactionEngine.new(loader)

	audio_mgr = ThrottledAudioManager.new()
	audio_mgr.name = "ThrottledAudioManager"
	add_child(audio_mgr)
	_preload_cues()

	orbit_rig = OrbitWeaponRig.new()
	orbit_rig.name = "OrbitWeaponRig"
	orbit_rig.position = Vector2(0.0, -10.0)
	add_child(orbit_rig)
	orbit_rig.setup(loader)
	orbit_rig.weapon_fired.connect(_on_weapon_fired)
	orbit_rig.loadout_changed.connect(_on_orbit_loadout_changed)

	var char_cfg := CharacterData.get_character(str(player.character_id))
	var start_wpn := str(char_cfg.get("v2_start_weapon", "wpn_jade_sword"))
	unlocked_weapon_slots = calc_unlocked_slots(int(player.level), 0)
	orbit_rig.set_unlocked_slots(unlocked_weapon_slots)
	orbit_rig.add_weapon(start_wpn, 1)
	if not player.leveled_up.is_connected(_on_player_leveled_up):
		player.leveled_up.connect(_on_player_leveled_up)
	recompute_player_stats()
	_lifesteal_budget = player.max_health * 0.06
	gold_changed.emit(run_gold)
	v2_loadout_changed.emit()

func get_realm_table() -> Array:
	if loader != null and not loader.realm_slot_unlocks.is_empty():
		return loader.realm_slot_unlocks
	return DEFAULT_REALM_UNLOCKS

func get_realm_info_for_level(lv: int) -> Dictionary:
	var table := get_realm_table()
	var cur: Dictionary = {}
	var next: Dictionary = {}
	for entry in table:
		var req_level := int(entry.get("level", 1))
		if req_level <= lv:
			cur = entry
		elif next.is_empty():
			next = entry
	if cur.is_empty() and not table.is_empty():
		cur = table[0]
	return {
		"slots": int(cur.get("slots", 1)),
		"realm": String(cur.get("realm", "练气")),
		"level": lv,
		"next_level": int(next.get("level", 0)),
		"next_realm": String(next.get("realm", "")),
	}

func get_max_weapon_slots() -> int:
	if loader != null and loader.max_weapon_slots > 0:
		return loader.max_weapon_slots
	return 4

func calc_unlocked_slots(player_level: int, elite_kills: int = -1) -> int:
	var max_s := get_max_weapon_slots()
	var level_slots := 1
	for entry in get_realm_table():
		if int(entry.get("level", 1)) <= player_level:
			level_slots = maxi(level_slots, int(entry.get("slots", 1)))
	var ek := elite_kills if elite_kills >= 0 else elite_kills_for_slots
	if ek >= 2:
		return mini(max_s, maxi(level_slots, max_s))
	return mini(max_s, level_slots)

func get_unlocked_slots() -> int:
	return unlocked_weapon_slots

func get_next_slot_unlock_info() -> Dictionary:
	if unlocked_weapon_slots >= get_max_weapon_slots():
		return {}
	for entry in get_realm_table():
		if int(entry.get("slots", 1)) > unlocked_weapon_slots:
			return {
				"slots": int(entry.get("slots", 1)),
				"level": int(entry.get("level", 1)),
				"realm": String(entry.get("realm", "")),
			}
	return {}

func sync_realm_slots(player_level: int = -1, reason: String = "level") -> int:
	var lv := player_level
	if lv < 0:
		lv = int(player.level) if player != null else 1
	var target := calc_unlocked_slots(lv, elite_kills_for_slots)
	if target <= unlocked_weapon_slots:
		return 0
	var gained := target - unlocked_weapon_slots
	unlocked_weapon_slots = target
	pending_new_weapon_picks += gained
	if orbit_rig != null:
		orbit_rig.set_unlocked_slots(target)
	var info := get_realm_info_for_level(lv)
	realm_slot_unlocked.emit(target, String(info.get("realm", "练气")), reason)
	v2_loadout_changed.emit()
	return gained

func should_offer_breakthrough_pick() -> bool:
	return pending_new_weapon_picks > 0 and orbit_rig != null and orbit_rig.has_free_slot()

func consume_breakthrough_pick() -> void:
	pending_new_weapon_picks = maxi(0, pending_new_weapon_picks - 1)

func notify_elite_killed() -> void:
	elite_kills_for_slots += 1
	var lv := int(player.level) if player != null else 1
	sync_realm_slots(lv, "elite")

func _on_player_leveled_up(new_lv: int) -> void:
	sync_realm_slots(new_lv, "level")

func upgrade_weapon(weapon_id: String, step: int = 1) -> bool:
	if orbit_rig == null:
		return false
	return orbit_rig.upgrade_weapon(weapon_id, step)

func _preload_cues() -> void:
	for cue_id in CUE_FALLBACK_PATHS.keys():
		var path: String = CUE_FALLBACK_PATHS[cue_id]
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				_streams[cue_id] = st

func play_v2_cue(cue_id: String, category: String = "default_hit", pitch: float = 1.0) -> void:
	if audio_mgr == null:
		return
	var st: AudioStream = _streams.get(cue_id, null) as AudioStream
	if st != null:
		audio_mgr.play_cue(cue_id, st, category, pitch)

func _on_orbit_loadout_changed(_slots: Array) -> void:
	v2_loadout_changed.emit()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead or orbit_rig == null:
		_pending_salvos.clear()
		return

	_step_pending_salvos(delta)

	_lifesteal_budget = minf(player.max_health * 0.06, _lifesteal_budget + player.max_health * 0.06 * delta)
	_reaction_pop_timer += delta
	if _reaction_pop_timer >= 1.0:
		_reaction_pop_timer = 0.0
		_reaction_pop_budget = 12

	_prune_timer += delta
	if _prune_timer >= 2.0:
		_prune_timer = 0.0
		var now_sec := float(Time.get_ticks_msec()) * 0.001
		reaction_engine.prune_stale(now_sec)
		for eid in _bell_resonance_icd.keys():
			if float(_bell_resonance_icd[eid]) <= now_sec:
				_bell_resonance_icd.erase(eid)
		if _shot_hit_counts.size() > 64:
			_shot_hit_counts.clear()

	if has_arcana("arcana_void_magnet"):
		_void_magnet_timer += delta
		if _void_magnet_timer >= 90.0:
			_void_magnet_timer = 0.0
			trigger_void_magnet()
	var candidates := CombatGrid.query(player.global_position, 520.0)
	var alive: Array = []
	for e in candidates:
		if e != null and is_instance_valid(e) and not bool(e.get("is_dead")):
			alive.append(e)
	orbit_rig.tick(delta, alive, get_attack_speed_mult())

func _raw_attack_speed_mult() -> float:
	var limit_haste := float(player.limit_haste_bonus) if player != null else 0.0
	var empty_spd := float(get_empty_slot_count()) * 0.06 if has_arcana("arcana_solitary_dao") else 0.0
	return maxf(0.4, 1.0 + float(item_mods.get("attack_speed_pct", 0.0)) + limit_haste * 0.05 + empty_spd)

func get_attack_speed_mult() -> float:
	return minf(2.4, _raw_attack_speed_mult())

func get_damage_mult() -> float:
	var sect_might := float(player.sect_might_mult) if player != null else 1.0
	var limit_might := float(player.limit_might_bonus) if player != null else 0.0
	var spd_overflow := maxf(0.0, _raw_attack_speed_mult() - 2.4) * 0.35
	var empty_dmg := float(get_empty_slot_count()) * 0.14 if has_arcana("arcana_solitary_dao") else 0.0
	var revival_dmg := float(revival_stacks) * 0.08 if has_arcana("arcana_samsara") else 0.0
	var raw := (1.0 + float(item_mods.get("damage_pct", 0.0)) + spd_overflow + empty_dmg + revival_dmg) * sect_might * (1.0 + limit_might)
	var is_endless := false
	if is_inside_tree() and get_tree() != null:
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm != null and ("stage_director" in gm) and gm.stage_director != null and bool(gm.stage_director.get("endless_mode")):
			is_endless = true
	return clampf(raw, 0.25, 5.5 if is_endless else 3.8)

func get_area_mult() -> float:
	return clampf(1.0 + float(item_mods.get("area_pct", 0.0)), 0.6, 2.8)

func get_crit_chance() -> float:
	var base := float(player.base_crit_chance) if player != null else 0.12
	return clampf(base + float(item_mods.get("crit_chance", 0.0)), 0.0, 0.85)

func get_crit_mult() -> float:
	return minf(4.0, 1.75 + float(item_mods.get("crit_mult_bonus", 0.0)))

func get_mastery_bonus() -> float:
	return float(item_mods.get("mastery_pct", 0.0))

func get_dot_mult() -> float:
	return 1.0 + float(item_mods.get("dot_damage_pct", 0.0))

func get_curse_pct() -> float:
	return clampf(float(item_mods.get("curse_pct", 0.0)), 0.0, 2.0)

func get_curse_enemy_hp_mult() -> float:
	return V2SpawnDirector.calc_curse_hp_mult(get_curse_pct())

func get_spawn_rate_mult() -> float:
	return maxf(0.5, 1.0 + float(item_mods.get("enemy_spawn_pct", 0.0)) + get_curse_pct() * 0.5)

func get_luck() -> float:
	return clampf(1.0 + float(item_mods.get("luck", 0.0)), 0.5, 4.0)

static func calc_fourth_card_prob(luck_val: float) -> float:
	return 0.0 if luck_val <= 1.0 else clampf(1.0 - 1.0 / luck_val, 0.0, 0.85)

func roll_level_choice_count(base_count: int = 3) -> int:
	if base_count != 3:
		return base_count
	var prob := calc_fourth_card_prob(get_luck())
	return 4 if prob > 0.0 and randf() < prob else 3

func get_owned_elements() -> Dictionary:
	var out := {}
	if orbit_rig == null or loader == null:
		return out
	for slot in orbit_rig.slots:
		var wid := String(slot["id"])
		if bool(slot.get("is_fusion", false)):
			for r in loader.fusion_recipes:
				if String(r.get("id", "")) == wid:
					for elem in r.get("elements", []):
						out[String(elem)] = true
					break
		elif loader.weapons_by_id.has(wid):
			var el := String(loader.weapons_by_id[wid].get("element", ""))
			if not el.is_empty():
				out[el] = true
	return out

func find_companion_fusion_info(weapon_id: String) -> Dictionary:
	if orbit_rig == null or loader == null:
		return {}
	var fallback := {}
	for recipe in loader.fusion_recipes:
		var fid := String(recipe.get("id", ""))
		if orbit_rig.has_fusion(fid):
			continue
		var ing: Array = recipe.get("ingredients", [])
		if ing.size() < 2:
			continue
		var partner_id := ""
		if String(ing[0]) == weapon_id:
			partner_id = String(ing[1])
		elif String(ing[1]) == weapon_id:
			partner_id = String(ing[0])
		if partner_id.is_empty():
			continue
		var partner_lv := orbit_rig.get_weapon_tier(partner_id)
		if partner_lv <= 0:
			continue
		var partner_name := partner_id
		if loader.weapons_by_id.has(partner_id):
			partner_name = String(loader.weapons_by_id[partner_id].get("name", partner_id))
		var info := {
			"recipe": recipe,
			"partner_id": partner_id,
			"partner_name": partner_name,
			"fusion_name": String(recipe.get("name", fid)),
			"ready_now": partner_lv >= OrbitWeaponRig.MAX_WEAPON_TIER,
		}
		if bool(info["ready_now"]):
			return info
		if fallback.is_empty():
			fallback = info
	return fallback

func get_weapon_offer_weight(weapon_id: String) -> float:
	var w := 10.0
	if orbit_rig == null or loader == null or not loader.weapons_by_id.has(weapon_id):
		return w
	var luck := get_luck()
	var cur_lv := orbit_rig.get_weapon_tier(weapon_id)
	if cur_lv > 0 and cur_lv < OrbitWeaponRig.MAX_WEAPON_TIER:
		w *= (1.0 + 2.2 / clampf(luck, 1.0, 2.5))
	var finfo := find_companion_fusion_info(weapon_id)
	if bool(finfo.get("ready_now", false)):
		w *= 2.40
	elif not finfo.is_empty() and cur_lv == 0:
		w *= 1.25
	if cur_lv == 0:
		var elem := String(loader.weapons_by_id[weapon_id].get("element", ""))
		if not elem.is_empty() and not get_owned_elements().has(elem):
			w *= 1.35
	return maxf(1.0, w)

static func item_has_tradeoff(item_def: Dictionary) -> bool:
	var mods: Variant = item_def.get("mods", {})
	if not (mods is Dictionary):
		return false
	for k in (mods as Dictionary).keys():
		var val := float((mods as Dictionary)[k])
		if val < 0.0:
			return true
		if String(k) == "enemy_spawn_pct" and val > 0.0:
			return true
	return false

func get_temper_price(weapon_id: String, current_tier: int) -> int:
	var base := 20
	if loader != null and loader.weapons_by_id.has(weapon_id):
		base = int(loader.weapons_by_id[weapon_id].get("base_cost", 20))
	return maxi(12, int(round(float(base) * (0.80 + 0.30 * float(clampi(current_tier, 1, 7))))))

func recompute_player_stats() -> void:
	item_mods.clear()
	if player != null and is_instance_valid(player):
		var char_cfg := CharacterData.get_character(str(player.character_id))
		var t_mods = char_cfg.get("trait_mods", {})
		if t_mods is Dictionary:
			for k in t_mods.keys():
				item_mods[k] = float(t_mods[k])
	if Stats != null and Stats.has_method("get_sect_stat_mods"):
		var sect_mods: Dictionary = Stats.get_sect_stat_mods()
		for sk in sect_mods.keys():
			item_mods[sk] = float(item_mods.get(sk, 0.0)) + float(sect_mods[sk])
	for k in realm_bonuses.keys():
		item_mods[k] = float(item_mods.get(k, 0.0)) + float(realm_bonuses[k])
	for it in owned_items:
		var mods: Dictionary = it.get("mods", {})
		for k in mods.keys():
			item_mods[k] = float(item_mods.get(k, 0.0)) + float(mods[k])

	if reaction_engine != null:
		var rx_mods := item_mods.duplicate()
		rx_mods["reaction_icd_reduction"] = minf(0.45, float(rx_mods.get("reaction_icd_reduction", 0.0)))
		reaction_engine.configure_modifiers(rx_mods)

	if player == null or not is_instance_valid(player):
		return

	var revival_hp_mult := 1.0 + (float(revival_stacks) * 0.15 if has_arcana("arcana_samsara") else 0.0)
	var target_max_hp := maxf(40.0, (player.base_max_health + float(item_mods.get("max_hp", 0.0))) * revival_hp_mult)
	if not is_equal_approx(player.max_health, target_max_hp):
		var diff := target_max_hp - player.max_health
		player.max_health = target_max_hp
		if diff > 0.0:
			player.current_health = minf(player.max_health, player.current_health + diff)
		else:
			player.current_health = minf(player.max_health, player.current_health)
		player.emit_signal("health_changed", player.current_health, player.max_health)

	var revival_armor := float(revival_stacks) * 2.0 if has_arcana("arcana_samsara") else 0.0
	player.armor = maxf(0.0, float(item_mods.get("armor", 0.0)) + revival_armor)
	player.dodge_chance = clampf(float(item_mods.get("dodge_pct", 0.0)), 0.0, 0.55)
	player.speed = player.base_speed * player.stage_speed_mult * maxf(0.5, 1.0 + float(item_mods.get("move_speed_pct", 0.0)))
	player.magnet_radius = player.base_magnet_radius * maxf(0.5, 1.0 + float(item_mods.get("pickup_radius_pct", 0.0)))
	player.dash_cooldown = maxf(0.75, player.base_dash_cooldown * maxf(0.4, 1.0 + float(item_mods.get("dash_cooldown_pct", 0.0))))
	player.regen_per_second = maxf(0.0, float(item_mods.get("hp_regen", 0.0)))

func add_weapon(weapon_id: String, tier: int = 1) -> bool:
	if orbit_rig == null:
		return false
	return orbit_rig.add_weapon(weapon_id, tier)

func can_add_weapon(weapon_id: String, tier: int = 1) -> bool:
	if orbit_rig == null:
		return false
	return orbit_rig.can_add_weapon(weapon_id, tier)

func sell_weapon(slot_index: int) -> int:
	if orbit_rig == null or slot_index < 0 or slot_index >= orbit_rig.slots.size():
		return 0
	var slot: Dictionary = orbit_rig.slots[slot_index]
	var price := get_weapon_price(String(slot["id"]), int(slot["tier"]), bool(slot["is_fusion"]))
	var ratio := float(loader.shop_economy.get("sell_refund_ratio", 0.55))
	var refund := maxi(5, int(round(float(price) * ratio)))
	var removed := orbit_rig.sell_weapon(slot_index)
	if removed.is_empty():
		return 0
	add_run_gold(refund)
	play_v2_cue("ui_event", "ui_event")
	return refund

func get_weapon_price(weapon_id: String, tier: int = 1, is_fusion: bool = false) -> int:
	if is_fusion:
		return 280
	var base := 20
	if loader != null and loader.weapons_by_id.has(weapon_id):
		base = int(loader.weapons_by_id[weapon_id].get("base_cost", 20))
	match clampi(tier, 1, 8):
		1: return base
		2: return int(round(float(base) * 1.4))
		3: return int(round(float(base) * 1.9))
		4: return int(round(float(base) * 2.5))
		5: return int(round(float(base) * 3.2))
		6: return int(round(float(base) * 4.0))
		7: return int(round(float(base) * 5.0))
		8: return int(round(float(base) * 6.2))
	return base

func get_item_count(item_id: String) -> int:
	var cnt := 0
	for it in owned_items:
		if String(it.get("id", "")) == item_id:
			cnt += 1
	return cnt

func can_add_item(item_id: String) -> bool:
	if loader == null or not loader.items_by_id.has(item_id):
		return false
	var it: Dictionary = loader.items_by_id[item_id]
	var cap := int(it.get("max_stacks", 0))
	if cap > 0 and get_item_count(item_id) >= cap:
		return false
	return true

func add_item(item_id: String) -> bool:
	if not can_add_item(item_id):
		return false
	owned_items.append(loader.items_by_id[item_id])
	recompute_player_stats()
	v2_loadout_changed.emit()
	return true

func remove_item(item_id: String) -> bool:
	for i in range(owned_items.size() - 1, -1, -1):
		if String(owned_items[i].get("id", "")) == item_id:
			owned_items.remove_at(i)
			recompute_player_stats()
			v2_loadout_changed.emit()
			return true
	return false

func clear_items() -> void:
	if owned_items.is_empty():
		return
	owned_items.clear()
	recompute_player_stats()
	v2_loadout_changed.emit()

func add_realm_bonus(key: String, delta_val: float) -> void:
	realm_bonuses[key] = float(realm_bonuses.get(key, 0.0)) + delta_val
	recompute_player_stats()

func record_stat_pick(choice_id: String) -> void:
	stat_pick_counts[choice_id] = int(stat_pick_counts.get(choice_id, 0)) + 1

func get_stat_pick_count(choice_id: String) -> int:
	return int(stat_pick_counts.get(choice_id, 0))

static func wave_stone_soft_cap(wave: int) -> int:
	return 22 + maxi(0, wave - 1) * 6

func set_current_wave(wave_num: int) -> void:
	var next_w := maxi(1, wave_num)
	if next_w != _drop_wave:
		_drop_wave = next_w
		_wave_dropped_gold = 0

func add_run_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	var mult := 1.0 + float(item_mods.get("gold_gain_pct", 0.0)) + get_curse_pct() * 0.5
	var raw := float(amount) * mult + _gold_frac
	var gained := int(floor(raw))
	_gold_frac = raw - float(gained)
	if gained <= 0:
		return 0
	run_gold += gained
	gold_changed.emit(run_gold)
	return gained

func try_spawn_spirit_stone_drop(world_pos: Vector2, enemy_type: int, raw_gold_value: int) -> int:
	if player == null or not is_instance_valid(player) or player.get_parent() == null:
		return 0
	var parent_world := player.get_parent()
	var pickup_scene := load("res://scenes/world_pickup.tscn") as PackedScene
	if pickup_scene == null:
		return 0

	if enemy_type == Enemy.Type.BOSS:
		var total_b := 0
		for i in range(3):
			total_b += _spawn_spirit_stone_node(pickup_scene, parent_world, world_pos, 5, (float(i) / 3.0) * TAU + randf_range(-0.3, 0.3))
		return total_b

	if enemy_type == Enemy.Type.ELITE:
		var per_stone := 3 if _drop_wave < 5 else 4
		var total_e := 0
		for i in range(2):
			total_e += _spawn_spirit_stone_node(pickup_scene, parent_world, world_pos, per_stone, float(i) * PI + randf_range(-0.4, 0.4))
		return total_e

	var base_prob := 0.22
	var drop_amount := 1
	if raw_gold_value >= 6:
		base_prob = 0.75
		drop_amount = 4
	elif raw_gold_value >= 4:
		base_prob = 0.48
		drop_amount = 3
	elif raw_gold_value == 3:
		base_prob = 0.36
		drop_amount = 2
	elif raw_gold_value == 2:
		base_prob = 0.30
		drop_amount = 2

	var soft_cap := wave_stone_soft_cap(_drop_wave)
	var hard_cap := int(round(float(soft_cap) * 1.25))
	var pace_mult := 1.0
	if _wave_dropped_gold >= hard_cap:
		pace_mult = 0.0
	elif _wave_dropped_gold >= soft_cap:
		pace_mult = 0.25

	if pace_mult <= 0.0 or randf() >= base_prob * pace_mult:
		return 0

	var spawned_amt := _spawn_spirit_stone_node(pickup_scene, parent_world, world_pos, drop_amount, randf() * TAU)
	_wave_dropped_gold += spawned_amt
	return spawned_amt

func _spawn_spirit_stone_node(scene: PackedScene, parent_world: Node, world_pos: Vector2, amount: int, ang: float) -> int:
	var p := scene.instantiate()
	if p == null:
		return 0
	p.global_position = world_pos
	parent_world.call_deferred("add_child", p)
	if p.has_method("setup"):
		p.setup("spirit_stone", amount)
	if p.has_method("pop_out"):
		p.pop_out(Vector2.from_angle(ang))
	return amount

static func qiankun_bag_drop_chance(enemy_type: int) -> float:
	if enemy_type == Enemy.Type.ELITE:
		return QIANKUN_BAG_ELITE_CHANCE
	if enemy_type == Enemy.Type.MINION:
		return QIANKUN_BAG_MINION_CHANCE
	return 0.0

func try_spawn_qiankun_bag_drop(world_pos: Vector2, enemy_type: int) -> bool:
	var chance := qiankun_bag_drop_chance(enemy_type)
	if chance <= 0.0 or randf() >= chance:
		return false
	return spawn_qiankun_bag_at(world_pos) != null

func spawn_qiankun_bag_at(world_pos: Vector2) -> WorldPickup:
	if player == null or not is_instance_valid(player) or player.get_parent() == null:
		return null
	var scene := load("res://scenes/world_pickup.tscn") as PackedScene
	if scene == null:
		return null
	var bag := scene.instantiate() as WorldPickup
	if bag == null:
		return null
	bag.global_position = world_pos
	player.get_parent().call_deferred("add_child", bag)
	bag.setup("qiankun_bag")
	bag.pop_out(Vector2.from_angle(randf() * TAU))
	return bag

func spend_run_gold(cost: int) -> bool:
	if cost < 0 or run_gold < cost:
		return false
	run_gold -= cost
	gold_changed.emit(run_gold)
	return true

func has_item(item_id: String) -> bool:
	for it in owned_items:
		if String(it.get("id", "")) == item_id:
			return true
	return false

func on_xp_orb_collected() -> void:
	play_v2_cue("xp_orb", "xp_orb")
	Sfx.play_count += 1
	if has_item("item_magnet_gourd"):
		_orb_counter += 1
		if _orb_counter >= 25:
			_orb_counter = 0
			_clear_enemy_bullets(player.global_position, 260.0)
			_spawn_pulse_visual(player.global_position, 260.0, Color(0.66, 0.48, 0.96, 0.36), "default", get_area_mult())
			_spawn_text_popup(player.global_position + Vector2(0, -34), "紫葫芦清弹!", Color(0.84, 0.68, 1.0))

func on_player_dash(_dash_dir: Vector2) -> void:
	return

func _on_weapon_fired(slot_idx: int, w_def: Dictionary, stats: Dictionary, origin: Vector2, target_pos: Vector2) -> void:
	if player == null or player.get_parent() == null:
		return
	var vis := player.get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("trigger_attack_anim"):
		var aim := target_pos - origin
		vis.trigger_attack_anim(aim.normalized() if aim.length_squared() > 0.001 else Vector2.ZERO)
	play_v2_cue(String(w_def.get("sfx_cue", "")), "default_hit")

	var elem := String(w_def.get("element", ""))
	if elem.is_empty():
		var elems: Array = w_def.get("elements", [])
		if not elems.is_empty():
			var tog := int(_fusion_elem_toggle.get(slot_idx, 0))
			elem = String(elems[tog % elems.size()])
			_fusion_elem_toggle[slot_idx] = tog + 1

	var pattern := String(w_def.get("attack_pattern", "pierce_boomerang"))
	var fired_wid := String(w_def.get("id", ""))
	var lb_mods := get_weapon_limit_break_mods(fired_wid)
	var base_dmg := float(stats.get("damage", 15.0)) * (1.0 + float(lb_mods.get("damage_pct", 0.0))) * get_arcana_weapon_damage_mult(fired_wid)
	var profile: Dictionary = w_def.get("vfx_profile", {})
	var parent_world := player.get_parent()
	var area_m := get_area_mult()
	var perk := String(stats.get("max_tier_perk", ""))
	var is_max_tier := not perk.is_empty()
	var max_col_hex := String(profile.get("max_tier_color", ""))
	var is_fusion_shot := orbit_rig != null and slot_idx >= 0 and slot_idx < orbit_rig.slots.size() and bool(orbit_rig.slots[slot_idx].get("is_fusion", false))
	var awakened_fx := is_max_tier or V2AttackFx.is_awakened_tier(int(stats.get("tier", 0)), is_fusion_shot)

	match pattern:
		"pierce_boomerang":
			var dir := (target_pos - origin).normalized()
			var col_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("trail_color", "#2DD4BF"))
			var col := Color.from_string(col_hex, Color(0.18, 0.83, 0.75))
			var pierce := int(stats.get("pierce", 2)) + int(item_mods.get("pierce_flat", 0))
			var sword_cnt := maxi(1, int(stats.get("projectile_count", 1)))
			var base_ang := dir.angle()
			var proj_spd := float(stats.get("proj_speed", 640.0))
			var rng := float(stats.get("range", 350.0))
			for k in range(sword_cnt):
				var spread_off := 0.0 if sword_cnt <= 1 else (float(k) / float(sword_cnt - 1) - 0.5) * minf(0.56, 0.13 * float(sword_cnt - 1))
				var s_dir := Vector2.from_angle(base_ang + spread_off)
				if k == 0:
					var fx := V2AttackFx.new()
					parent_world.add_child(fx)
					fx.setup_boomerang(self, player, origin, s_dir, base_dmg, proj_spd, rng, pierce, elem, col, false, false, awakened_fx)
				else:
					_enqueue_salvo({
						"kind": "afterimage_boomerang",
						"delay": float(k) * SALVO_STAGGER_SEC,
						"slot_idx": slot_idx,
						"origin": origin,
						"dir": s_dir,
						"damage": base_dmg,
						"proj_speed": proj_spd,
						"range": rng,
						"pierce": pierce,
						"elem": elem,
						"color": col,
						"awakened": false,
					})
			if has_arcana("arcana_mirror_blade") and is_arcana_applicable_to_weapon("arcana_mirror_blade", fired_wid):
				_enqueue_salvo({
					"kind": "afterimage_boomerang",
					"delay": SALVO_STAGGER_SEC,
					"slot_idx": slot_idx,
					"origin": origin,
					"dir": dir.rotated(-0.14),
					"damage": base_dmg * 0.45,
					"proj_speed": proj_spd,
					"range": rng,
					"pierce": pierce,
					"elem": elem,
					"color": col,
					"awakened": false,
				})
			if perk == "afterimage_double_slash":
				_enqueue_salvo({
					"kind": "afterimage_boomerang",
					"delay": float(sword_cnt) * SALVO_STAGGER_SEC,
					"slot_idx": slot_idx,
					"origin": origin,
					"dir": dir.rotated(0.18),
					"damage": base_dmg * 0.40,
					"proj_speed": proj_spd * 0.94,
					"range": rng * 0.92,
					"pierce": pierce,
					"elem": elem,
					"color": col,
				})

		"lob_burn_zone":
			var z_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("zone_color", "#EA580C"))
			var col := Color.from_string(z_hex, Color(0.92, 0.35, 0.05))
			col.a = float(profile.get("zone_alpha", 0.34))
			var b_dur := float(stats.get("burn_dur", 1.6))
			var fx := V2AttackFx.new()
			parent_world.add_child(fx)
			fx.setup_burn_zone(self, origin, target_pos, base_dmg, float(stats.get("aoe_radius", 72.0)) * area_m, float(stats.get("zone_duration", 3.0)), float(stats.get("tick_dps", 10.0)), col, perk == "lotus_implosion", area_m, awakened_fx, b_dur)

		"instant_chain_bolt":
			var b_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("bolt_color", "#818CF8"))
			var col := Color.from_string(b_hex, Color(0.51, 0.55, 0.97))
			var chains := int(stats.get("chain_count", 2)) + int(item_mods.get("chain_bonus", 0))
			var ch_range := float(stats.get("chain_range", 135.0)) * area_m
			var first := _find_closest_enemy_to(target_pos, 90.0)
			if first != null:
				_fire_chain_lightning(origin, first, base_dmg, elem, chains, ch_range, col, true, perk == "five_thunder_arc", awakened_fx)

		"cone_shards":
			_shot_seq += 1
			var s_id := _shot_seq
			var cnt := int(stats.get("projectile_count", 3))
			var sh_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("shard_color", "#38BDF8"))
			var col := Color.from_string(sh_hex, Color(0.22, 0.74, 0.97))
			var base_ang := (target_pos - origin).angle()
			var spread := 0.76
			var pierce := 1 + int(item_mods.get("pierce_flat", 0))
			var rng := float(stats.get("range", 310.0))
			var sl_pct := float(stats.get("slow_pct", 0.25))
			var sl_dur := float(stats.get("slow_dur", 2.0))
			for k in range(cnt):
				var offset := 0.0 if cnt <= 1 else (float(k) / float(cnt - 1) - 0.5) * spread
				var shot_dir := Vector2.from_angle(base_ang + offset)
				var is_wheel := perk == "bagua_frost_wheel" and k == cnt / 2
				if k == 0:
					var fx := V2AttackFx.new()
					parent_world.add_child(fx)
					fx.setup_ice_shard(self, origin, shot_dir, base_dmg, rng, s_id, sl_pct, sl_dur, col, is_wheel, pierce, awakened_fx)
				else:
					_enqueue_salvo({
						"kind": "ice_shard",
						"delay": float(k) * SALVO_STAGGER_SEC,
						"slot_idx": slot_idx,
						"origin": origin,
						"dir": shot_dir,
						"damage": base_dmg,
						"range": rng,
						"shot_id": s_id,
						"slow_pct": sl_pct,
						"slow_dur": sl_dur,
						"color": col,
						"split_perk": is_wheel,
						"pierce": pierce,
						"awakened": awakened_fx and is_wheel,
					})

		"water_dew_splash":
			var w_tier := maxi(1, int(stats.get("tier", 1)))
			var w_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("wave_color", "#22D3EE"))
			var col := Color.from_string(w_hex, Color(0.13, 0.83, 0.93))
			col.a = float(profile.get("wave_alpha", 0.48))
			var launch_r := (22.0 + float(w_tier - 1) * 2.8) * area_m
			_spawn_pulse_visual(origin, launch_r, col, "water_mirror", area_m)
			var fx := V2AttackFx.new()
			parent_world.add_child(fx)
			fx.setup_water_splash(self, origin, target_pos, base_dmg, float(stats.get("aoe_radius", 76.0)) * area_m, float(stats.get("slow_pct", 0.28)), float(stats.get("slow_dur", 2.2)), elem, col, perk == "sweet_dew_tide", awakened_fx, w_tier)

		"homing_soul_seal_spirits":
			var sp_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("spirit_color", "#34D399"))
			var sp_col := Color.from_string(sp_hex, Color(0.20, 0.83, 0.60))
			sp_col.a = float(profile.get("spirit_alpha", 0.82))
			var halo_col := Color.from_string(String(profile.get("spirit_halo", "#A78BFA")), Color(0.65, 0.55, 0.98))
			var spirit_cnt := maxi(1, int(stats.get("projectile_count", 2)))
			var spirit_spd := float(stats.get("spirit_speed", 380.0))
			var spirit_rng := float(stats.get("range", 400.0))
			var seal_dps := float(stats.get("dot_dps", 10.0)) * get_dot_mult()
			var seal_dur := float(stats.get("dot_dur", 4.2))
			var spread_r := float(stats.get("spread_radius", 110.0)) * area_m
			if perk == "soul_seal_pandemic":
				spread_r *= 1.25
			var spread_n := mini(3, int(stats.get("spread_targets", 3)))
			var cast_dir := target_pos - origin
			if cast_dir.length_squared() <= 0.001:
				cast_dir = target_pos - player.global_position
			cast_dir = cast_dir.normalized() if cast_dir.length_squared() > 0.001 else Vector2.RIGHT
			var cast_perp := Vector2(-cast_dir.y, cast_dir.x)
			for k in range(spirit_cnt):
				var spirit := VENOM_SPIRIT_SCRIPT.new()
				parent_world.add_child(spirit)
				var side := float(k) - (float(spirit_cnt) - 1.0) * 0.5
				var s_origin := origin + cast_perp * side * 17.0
				var s_dir := cast_dir.rotated(side * 0.11)
				spirit.setup(self, s_origin, s_dir, target_pos, base_dmg, spirit_spd, spirit_rng, seal_dps, seal_dur, sp_col, halo_col, spread_r, spread_n, is_max_tier or awakened_fx)

		"vine_lash_leech":
			var r := float(stats.get("aoe_radius", 74.0)) * area_m
			var v_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("vine_color", "#22C55E"))
			var col := Color.from_string(v_hex, Color(0.13, 0.77, 0.37))
			col.a = float(profile.get("vine_alpha", 0.42))
			_spawn_pulse_visual(target_pos, r, col, "venom_dual" if perk == "ancient_vine_bloom" else "venom", area_m, 0.35, awakened_fx)
			var dot_dps := float(stats.get("dot_dps", 10.0)) * get_dot_mult()
			var dot_dur := float(stats.get("dot_dur", 4.5))
			var sl_pct := float(stats.get("slow_pct", 0.28))
			var sl_dur := float(stats.get("slow_dur", 2.2))
			var leech_hp := float(stats.get("leech_hp", 1.2))
			var hit_any := false
			for e in CombatGrid.query(target_pos, r):
				if e == null or not is_instance_valid(e) or e.is_dead:
					continue
				if target_pos.distance_squared_to(e.global_position) <= r * r:
					hit_any = true
					if e.has_method("apply_slow"):
						e.apply_slow(sl_pct, sl_dur)
					if perk == "ancient_vine_bloom" and e.has_method("apply_stun"):
						e.apply_stun(0.30 if bool(e.get("is_boss")) else 0.65)
					if e.has_method("apply_dot"):
						e.apply_dot(dot_dps, dot_dur, perk == "ancient_vine_bloom", elem)
					deal_v2_damage(e, base_dmg, elem, {})
			if hit_any and leech_hp > 0.0 and player != null and is_instance_valid(player):
				var heal_amt := leech_hp * (1.35 if perk == "ancient_vine_bloom" else 1.0)
				if player.current_health < player.max_health:
					player.heal(heal_amt)

		"radial_knockback_wave":
			var r := float(stats.get("aoe_radius", 135.0)) * area_m
			var rb_hex := max_col_hex if (is_max_tier and not max_col_hex.is_empty()) else String(profile.get("wave_color", "#F59E0B"))
			var col := Color.from_string(rb_hex, Color(0.96, 0.62, 0.04))
			col.a = float(profile.get("wave_alpha", 0.38))
			_spawn_pulse_visual(player.global_position, r, col, "bell_tide", area_m, 0.62, awakened_fx)
			if bool(stats.get("clear_enemy_bullets", false)):
				_clear_enemy_bullets(player.global_position, r)
			var kb := float(stats.get("knockback", 220.0))
			var sl_pct := float(stats.get("slow_pct", 0.25))
			var sl_dur := float(stats.get("slow_dur", 1.2))
			var resonance: Dictionary = w_def.get("resonance_profile", {})
			for e in CombatGrid.query(player.global_position, r):
				if e == null or not is_instance_valid(e) or e.is_dead:
					continue
				if player.global_position.distance_squared_to(e.global_position) > r * r:
					continue
				var resonance_kind := _bell_resonance_kind(e, resonance)
				var away: Vector2 = (e as Node2D).global_position - player.global_position
				if away.length_squared() < 0.001:
					away = Vector2.from_angle(randf() * TAU)
				if e.has_method("apply_slow") and sl_pct > 0.0:
					e.apply_slow(sl_pct, sl_dur)
				if perk == "echo_armor_shred" and e.has_method("apply_armor_shred"):
					e.apply_armor_shred(0.20, 3.0)
				deal_v2_damage(e, base_dmg, elem, {
					"knockback_dir": away.normalized(),
					"knockback": kb,
				})
				if not resonance_kind.is_empty():
					_trigger_bell_resonance(e, resonance_kind, base_dmg, resonance)

		"orbit_burst_array":
			var col := Color.from_string(String(profile.get("trail_color", "#F97316")), Color(0.98, 0.45, 0.09))
			var cnt := int(stats.get("projectile_count", 6))
			var base_ang := (target_pos - origin).angle()
			var pierce := 5 + int(item_mods.get("pierce_flat", 0))
			for k in range(cnt):
				var ang := base_ang + (float(k) - float(cnt - 1) * 0.5) * 0.20
				var shot_dir := Vector2.from_angle(ang)
				if k == 0:
					var fx := V2AttackFx.new()
					parent_world.add_child(fx)
					fx.setup_boomerang(self, player, origin, shot_dir, base_dmg * 0.58, 860.0, 460.0, pierce, elem, col, false, true, true)
				else:
					_enqueue_salvo({
						"kind": "flame_boomerang",
						"delay": float(k) * SALVO_STAGGER_SEC,
						"slot_idx": slot_idx,
						"origin": origin,
						"dir": shot_dir,
						"damage": base_dmg * 0.58,
						"proj_speed": 860.0,
						"range": 460.0,
						"pierce": pierce,
						"elem": elem,
						"color": col,
						"afterimage": k % 2 == 1,
						"awakened": true,
					})
			var dom := V2AttackFx.new()
			parent_world.add_child(dom)
			col.a = float(profile.get("array_alpha", 0.28))
			dom.setup_fusion_domain(self, player, target_pos, "orbit_burst_array", float(stats.get("aoe_radius", 110.0)) * area_m, base_dmg, 1.5, col, 0, area_m)

		"frost_wheel_auto_lightning":
			var col := Color.from_string(String(profile.get("bolt_color", "#60A5FA")), Color(0.38, 0.65, 0.98))
			var chains := int(stats.get("chain_count", 7)) + int(item_mods.get("chain_bonus", 0))
			var first := _find_closest_enemy_to(target_pos, 120.0)
			if first != null:
				_fire_chain_lightning(origin, first, base_dmg, elem, chains, 185.0 * area_m, col, true, true, true)
			var dom := V2AttackFx.new()
			parent_world.add_child(dom)
			col.a = float(profile.get("domain_alpha", 0.30))
			dom.setup_fusion_domain(self, player, player.global_position, "frost_wheel_auto_lightning", float(stats.get("aoe_radius", 140.0)) * area_m, base_dmg, 1.7, col, chains, area_m)

		"radial_dot_detonate":
			var r := float(stats.get("aoe_radius", 230.0)) * area_m
			var col := Color.from_string(String(profile.get("wave_color", "#34D399")), Color(0.20, 0.83, 0.60))
			col.a = float(profile.get("wave_alpha", 0.35))
			_spawn_pulse_visual(player.global_position, r, col, "fusion_zen_bell", area_m, 0.35, true)
			_clear_enemy_bullets(player.global_position, r)
			var det_pct := float(stats.get("detonate_remaining_dot_pct", 0.45))
			var dot_dps := 36.0 * get_dot_mult()
			var det_pops := 0
			for e in CombatGrid.query(player.global_position, r):
				if e == null or not is_instance_valid(e) or e.is_dead:
					continue
				if player.global_position.distance_squared_to(e.global_position) <= r * r:
					var extra := 0.0
					if e.has_method("detonate_remaining_dot"):
						extra = float(e.detonate_remaining_dot(det_pct))
					if extra > 0.0 and det_pops < 6 and V2VfxFactory.can_spawn_transient(parent_world):
						det_pops += 1
						var det_fx := V2ReactionFx.new()
						parent_world.add_child(det_fx)
						det_fx.setup_weapon_burst("dot_detonate", (e as Node2D).global_position, Vector2.UP, 34.0, col)
					if e.has_method("apply_dot"):
						e.apply_dot(dot_dps, 5.0, true, elem)
					deal_v2_damage(e, base_dmg + extra, elem, {
						"knockback_dir": (e.global_position - player.global_position).normalized(),
						"knockback": 310.0,
					})

func spawn_chain_from_targets(targets: Array, dmg: float, elem: String, chains: int, ch_range: float, col: Color) -> void:
	if targets.is_empty():
		return
	var first := targets[0] as Node2D
	if first == null or not is_instance_valid(first):
		return
	_fire_chain_lightning(first.global_position, first, dmg, elem, chains, ch_range, col, false, true)

func _bell_resonance_kind(enemy: Node, profile: Dictionary) -> String:
	if profile.is_empty():
		return ""
	var eid := enemy.get_instance_id()
	var now_sec := float(Time.get_ticks_msec()) * 0.001
	if now_sec < float(_bell_resonance_icd.get(eid, 0.0)):
		return ""
	if enemy.has_method("is_frozen") and bool(enemy.call("is_frozen")):
		return "shatter"
	if reaction_engine != null:
		if reaction_engine.has_aura(eid, "ice", now_sec) or reaction_engine.has_aura(eid, "water", now_sec):
			return "shatter"
		if reaction_engine.has_aura(eid, "thunder", now_sec):
			return "thunder_echo"
	if enemy.has_method("is_burning") and bool(enemy.call("is_burning")):
		return "shock_spread"
	if enemy.has_method("is_poisoned") and bool(enemy.call("is_poisoned")):
		return "shock_spread"
	if reaction_engine != null:
		if reaction_engine.has_aura(eid, "fire", now_sec) or reaction_engine.has_aura(eid, "wood", now_sec) or reaction_engine.has_aura(eid, "venom", now_sec):
			return "shock_spread"
	return ""

func _trigger_bell_resonance(primary_enemy: Node, kind: String, base_dmg: float, profile: Dictionary) -> void:
	if primary_enemy == null or not is_instance_valid(primary_enemy):
		return
	var center: Vector2 = (primary_enemy as Node2D).global_position
	var now_sec := float(Time.get_ticks_msec()) * 0.001
	_bell_resonance_icd[primary_enemy.get_instance_id()] = now_sec + maxf(0.4, float(profile.get("icd_sec", 1.6)))
	bell_resonance_total += 1
	bell_resonance_counts[kind] = int(bell_resonance_counts.get(kind, 0)) + 1
	var label := "洪钟共鸣"
	var col := Color(1.0, 0.88, 0.42)
	var cfg: Dictionary = {}
	match kind:
		"shatter":
			label = "金声碎冰"
			cfg = profile.get("shatter", {})
			col = Color.from_string(String(cfg.get("vfx_color", "#9AE6FF")), Color(0.60, 0.90, 1.0))
			_bell_shatter_resonance(primary_enemy, center, base_dmg, cfg, col)
		"thunder_echo":
			label = "钟鸣引雷"
			cfg = profile.get("thunder_echo", {})
			col = Color.from_string(String(cfg.get("vfx_color", "#FDE047")), Color(1.0, 0.88, 0.42))
			_bell_thunder_resonance(primary_enemy, center, base_dmg, cfg, col)
		"shock_spread":
			label = "震荡扬波"
			cfg = profile.get("shock_spread", {})
			col = Color.from_string(String(cfg.get("vfx_color", "#6EE7B7")), Color(0.43, 0.90, 0.72))
			_bell_shock_spread(primary_enemy, center, base_dmg, cfg, col)
		_:
			return
	_spawn_text_popup(center + Vector2(0.0, -42.0), label, col)
	if player != null and is_instance_valid(player) and player.has_method("shake_camera") and player.shake_amount < 3.0:
		player.shake_camera(1.4)

func _bell_shatter_resonance(primary_enemy: Node, center: Vector2, base_dmg: float, cfg: Dictionary, col: Color) -> void:
	var aoe := maxf(30.0, float(cfg.get("aoe_radius", 95.0)) * get_area_mult())
	var dmg := base_dmg * float(cfg.get("damage_mult", 0.85))
	var splash := dmg * float(cfg.get("splash_mult", 0.55))
	var is_true := bool(cfg.get("true_damage", true))
	if primary_enemy != null and is_instance_valid(primary_enemy) and not bool(primary_enemy.get("is_dead")) and primary_enemy.has_method("take_damage_v2"):
		primary_enemy.take_damage_v2(dmg, false, is_true, "ice", col)
	for e in CombatGrid.query(center, aoe):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")) or e == primary_enemy:
			continue
		if center.distance_squared_to((e as Node2D).global_position) > aoe * aoe:
			continue
		if e.has_method("apply_slow"):
			e.apply_slow(0.30, 1.5)
		var away: Vector2 = (e as Node2D).global_position - center
		if away.length_squared() < 0.001:
			away = Vector2.UP
		deal_v2_damage(e, splash, "ice", {"knockback_dir": away.normalized(), "knockback": 55.0})
	_spawn_bell_resonance_visual("shatter", center, aoe, col, {})
	play_v2_cue("sfx_react_shatter", "reaction")

func _bell_thunder_resonance(primary_enemy: Node, center: Vector2, base_dmg: float, cfg: Dictionary, col: Color) -> void:
	var chains := maxi(1, int(cfg.get("chain_count", 2)))
	var ch_range := maxf(60.0, float(cfg.get("chain_range", 155.0)) * get_area_mult())
	var dmg := base_dmg * float(cfg.get("damage_mult", 0.55))
	var stun_dur := float(cfg.get("stun_dur", 0.35))
	var first: Node2D = null
	if primary_enemy != null and is_instance_valid(primary_enemy) and not bool(primary_enemy.get("is_dead")):
		first = primary_enemy as Node2D
	if first == null:
		first = _find_closest_enemy_to(center, ch_range)
	if first != null:
		if first.has_method("apply_stun"):
			first.apply_stun(stun_dur)
		var visited := {first.get_instance_id(): true}
		var cursor: Node2D = first
		for _i in range(chains):
			var nxt := _find_next_chain_target(cursor.global_position, ch_range, visited)
			if nxt == null:
				break
			visited[nxt.get_instance_id()] = true
			if nxt.has_method("apply_stun"):
				nxt.apply_stun(stun_dur)
			cursor = nxt
		_fire_chain_lightning(center, first, dmg, "thunder", chains, ch_range, col, true, true)
	_spawn_bell_resonance_visual("thunder_echo", center, ch_range * 0.72, col, {})
	play_v2_cue("sfx_react_zap", "reaction")

func _bell_shock_spread(primary_enemy: Node, center: Vector2, base_dmg: float, cfg: Dictionary, col: Color) -> void:
	var aoe := maxf(40.0, float(cfg.get("aoe_radius", 118.0)) * get_area_mult())
	var max_targets := clampi(int(cfg.get("max_targets", 4)), 1, 4)
	var dot_info: Dictionary = {}
	if primary_enemy != null and is_instance_valid(primary_enemy) and primary_enemy.has_method("get_dot_info"):
		dot_info = primary_enemy.call("get_dot_info")
	var dot_dps := maxf(float(dot_info.get("dps", 0.0)), base_dmg * 0.35)
	var dot_dur := maxf(float(dot_info.get("remaining", 0.0)), 3.0)
	var elem := String(dot_info.get("elem", ""))
	var poison := true
	if elem.is_empty() and reaction_engine != null and primary_enemy != null and is_instance_valid(primary_enemy):
		var eid := primary_enemy.get_instance_id()
		var now_sec := float(Time.get_ticks_msec()) * 0.001
		if reaction_engine.has_aura(eid, "fire", now_sec):
			elem = "fire"
		elif reaction_engine.has_aura(eid, "wood", now_sec):
			elem = "wood"
		else:
			elem = "venom"
	elif elem.is_empty():
		elem = "venom"
	if elem == "fire":
		poison = false
	var dmg := base_dmg * float(cfg.get("damage_mult", 0.45))
	var candidates: Array = []
	for e in CombatGrid.query(center, aoe):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")) or e == primary_enemy:
			continue
		if center.distance_squared_to((e as Node2D).global_position) <= aoe * aoe:
			candidates.append(e)
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		return center.distance_squared_to((a as Node2D).global_position) < center.distance_squared_to((b as Node2D).global_position)
	)
	var spread := 0
	for e in candidates:
		if spread >= max_targets:
			break
		if e.has_method("apply_dot"):
			e.apply_dot(dot_dps * 0.80, dot_dur * 0.80, false, elem)
		deal_v2_damage(e, dmg, elem, {"allow_reaction": false})
		spread += 1
	_spawn_bell_resonance_visual("shock_spread", center, aoe, col, {"poison": poison})
	play_v2_cue("sfx_react_pop", "reaction")

func _spawn_bell_resonance_visual(kind: String, center: Vector2, radius: float, col: Color, extra: Dictionary) -> void:
	if player == null or not is_instance_valid(player) or player.get_parent() == null:
		return
	var world := player.get_parent()
	if not V2VfxFactory.can_spawn_transient(world):
		return
	var merged: Dictionary = extra.duplicate()
	merged["kind"] = kind
	merged["accent_color"] = "#FDE047"
	var fx := V2ReactionFx.new()
	world.add_child(fx)
	fx.setup_weapon_burst("bell_resonance", center, Vector2.UP, radius, col, merged)

func spread_soul_seal_venom(center: Vector2, dps: float, radius: float = 110.0, max_targets: int = 3) -> int:
	soul_seal_spread_count += 1
	var r := maxf(45.0, radius * get_area_mult())
	var spread_n := clampi(max_targets, 1, 3)
	play_v2_cue("sfx_venom_hiss", "reaction")
	var candidates: Array = []
	for e in CombatGrid.query(center, r):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		if center.distance_squared_to((e as Node2D).global_position) <= r * r:
			candidates.append(e)
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		return center.distance_squared_to((a as Node2D).global_position) < center.distance_squared_to((b as Node2D).global_position)
	)
	if player != null and is_instance_valid(player) and player.get_parent() != null and V2VfxFactory.can_spawn_transient(player.get_parent()):
		var links: Array = []
		for li in range(mini(4, candidates.size())):
			links.append((candidates[li] as Node2D).global_position - center)
		var burst := V2ReactionFx.new()
		player.get_parent().add_child(burst)
		burst.setup_weapon_burst("soul_seal_burst", center, Vector2.UP, r, Color(0.20, 0.88, 0.60, 0.92), {"links": links})
	var seal_dps := maxf(6.0, dps * 0.80)
	var spread := 0
	for e in candidates:
		if spread >= spread_n:
			break
		if e.has_method("apply_soul_seal"):
			e.apply_soul_seal(seal_dps, 4.0, radius, 3)
		elif e.has_method("apply_dot"):
			e.apply_dot(seal_dps, 4.0, false, "venom")
		deal_v2_damage(e, seal_dps, "wood", {"allow_reaction": false})
		spread += 1
	return spread

func deal_v2_damage(enemy: Node, base_dmg: float, element: String, opts: Dictionary = {}) -> void:
	if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
		return

	var dmg := base_dmg
	var s_id := int(opts.get("shot_id", 0))
	if s_id > 0:
		var key := "%d_%d" % [s_id, enemy.get_instance_id()]
		var hits := int(_shot_hit_counts.get(key, 0))
		_shot_hit_counts[key] = hits + 1
		if hits >= 1:
			dmg *= 0.35

	var affinity_mult := 1.0
	if player != null and is_instance_valid(player) and element != "" and CharacterData.get_element_affinity(str(player.character_id)) == element:
		affinity_mult = 1.0 + CharacterData.get_affinity_bonus(str(player.character_id))
	var dmg_mult := get_damage_mult() * affinity_mult
	if bool(opts.get("is_dot", false)):
		dmg_mult *= get_dot_mult()
	var scaled_base := dmg * dmg_mult

	var force_crit := bool(opts.get("force_crit", false))
	var allow_crit := not bool(opts.get("is_dot", false))
	var is_crit := force_crit or (allow_crit and randf() < get_crit_chance())
	var final_dmg := scaled_base * (get_crit_mult() if is_crit else 1.0)
	var is_true := bool(opts.get("true_damage", false))
	var is_dot := bool(opts.get("is_dot", false))

	if enemy.has_method("take_damage_v2"):
		enemy.take_damage_v2(final_dmg, is_crit, is_true, element, Color(0.0, 0.0, 0.0, 0.0), is_dot)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(final_dmg)

	if not is_dot and not bool(enemy.get("is_visual_culled")):
		var tier := 0
		if bool(enemy.get("is_boss")):
			tier = 2
		elif int(enemy.get("enemy_type")) == 1:
			tier = 1
		var pitch := 1.0
		if tier == 1:
			pitch = 0.88
		elif tier == 2:
			pitch = 0.76
		if is_crit:
			pitch *= 1.07
			play_v2_cue("sfx_crit_hit", "crit_hit", pitch)
		else:
			play_v2_cue("sfx_hit", "hit", pitch)

	var kb := float(opts.get("knockback", 0.0)) * (1.35 if is_crit else 1.0)
	if kb > 0.0 and not bool(enemy.get("is_dead")) and enemy.has_method("apply_knockback"):
		var kb_dir: Vector2 = opts.get("knockback_dir", Vector2.ZERO)
		if kb_dir.length_squared() > 0.001:
			enemy.apply_knockback(kb_dir.normalized() * kb)

	var ls_pct := float(item_mods.get("lifesteal_pct", 0.0))
	if ls_pct > 0.0 and _lifesteal_budget > 0.5 and player != null and player.current_health < player.max_health:
		var heal_val := minf(_lifesteal_budget, final_dmg * ls_pct)
		if heal_val > 0.2:
			_lifesteal_budget -= heal_val
			player.heal(heal_val)

	if not bool(opts.get("allow_reaction", true)) or element.is_empty() or reaction_engine == null:
		return

	var now_sec := float(Time.get_ticks_msec()) * 0.001
	var eid := enemy.get_instance_id()
	var rx := reaction_engine.apply_element_hit(eid, element, now_sec, scaled_base, get_mastery_bonus(), {}, bool(enemy.get("is_boss")))
	if rx.is_empty():
		if not bool(enemy.get("is_dead")) and enemy.has_method("set_active_element"):
			enemy.set_active_element(element, 3.5 + (float(item_mods.get("fire_aura_dur_bonus", 0.0)) if element == "fire" else 0.0))
		return

	if not bool(enemy.get("is_dead")) and enemy.has_method("set_active_element"):
		enemy.set_active_element("", 0.0)
	_execute_reaction(enemy, rx, scaled_base)

func _execute_reaction(primary_enemy: Node, rx: Dictionary, trigger_scaled_base: float) -> void:
	reaction_count += 1
	var rx_id := String(rx.get("reaction_id", ""))
	var rx_name := String(rx.get("name", ""))
	var bonus_dmg := float(rx.get("bonus_damage", 0.0))
	var aoe_r := float(rx.get("aoe_radius", 0.0))
	var chains := int(rx.get("chain_count", 0))
	var rx_col := Color.from_string(String(rx.get("vfx_color", "#FFFFFF")), Color.WHITE)
	var spec: Dictionary = rx.get("spec", {})
	var emit_vfx := bool(rx.get("emit_vfx", true))
	var center: Vector2 = (primary_enemy as Node2D).global_position

	var is_guaranteed_crit := bool(spec.get("guaranteed_crit", false))
	var is_true := bool(spec.get("true_damage", false))
	if is_guaranteed_crit:
		bonus_dmg *= 1.20

	play_v2_cue(String(rx.get("sfx_cue", "sfx_react_boom")), "reaction")
	var executed_target := false
	if rx_id == "react_corrode_execute" and is_instance_valid(primary_enemy) and not bool(primary_enemy.get("is_dead")):
		if bool(primary_enemy.get("is_boss")):
			var missing := maxf(0.0, float(primary_enemy.get("max_health")) - float(primary_enemy.get("current_health")))
			bonus_dmg += minf(600.0, missing * 0.06)
			is_true = true
		elif float(primary_enemy.get("current_health")) / maxf(1.0, float(primary_enemy.get("max_health"))) <= float(spec.get("execute_hp_pct", 0.18)):
			bonus_dmg = maxf(bonus_dmg, float(primary_enemy.get("current_health")) + 999.0)
			is_true = true
			executed_target = true

	if emit_vfx and _reaction_pop_budget > 0:
		_reaction_pop_budget -= 1
		_spawn_text_popup(center + Vector2(0.0, -34.0), "%s %d" % [rx_name, roundi(bonus_dmg)], rx_col)
		_spawn_reaction_visual(rx_id, center, aoe_r if aoe_r > 0.0 else 65.0, rx_col, {"executed": executed_target})
		if player != null and is_instance_valid(player) and player.has_method("shake_camera") and player.shake_amount < 3.5:
			player.shake_camera(1.8)

	if rx_id == "react_miasma_arc" and is_instance_valid(primary_enemy) and primary_enemy.has_method("detonate_remaining_dot"):
		bonus_dmg += float(primary_enemy.detonate_remaining_dot(float(spec.get("detonate_dot_pct", 0.35))))

	var targets: Array = []
	if aoe_r > 0.0:
		for e in CombatGrid.query(center, aoe_r):
			if e != null and is_instance_valid(e) and not bool(e.get("is_dead")):
				if center.distance_squared_to((e as Node2D).global_position) <= aoe_r * aoe_r:
					targets.append(e)
	elif is_instance_valid(primary_enemy) and not bool(primary_enemy.get("is_dead")):
		targets.append(primary_enemy)

	var shred := float(spec.get("armor_shred_pct", 0.0))
	var debuff_dur := float(spec.get("debuff_dur", 3.5))
	var root_dur := float(spec.get("root_dur", 0.0))
	var kb_val := float(spec.get("knockback", 0.0))
	var burn_mult := float(spec.get("burn_dps_mult", 0.0))
	var spread_elem := String(spec.get("spread_element", ""))
	var heal_player_val := float(spec.get("heal_player", 0.0))
	if heal_player_val > 0.0 and player != null and is_instance_valid(player) and player.current_health < player.max_health:
		player.heal(heal_player_val)

	for e in targets:
		if not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		if shred > 0.0 and e.has_method("apply_armor_shred"):
			e.apply_armor_shred(shred, debuff_dur)
		if root_dur > 0.0 and e.has_method("apply_stun"):
			e.apply_stun(0.35 if bool(e.get("is_boss")) else root_dur)
		if burn_mult > 0.0 and e.has_method("apply_dot"):
			e.apply_dot(trigger_scaled_base * burn_mult * get_dot_mult(), debuff_dur, false, "fire")
		if not spread_elem.is_empty() and e != primary_enemy:
			_apply_non_reactive_aura(e, spread_elem)
		if e.has_method("take_damage_v2"):
			e.take_damage_v2(bonus_dmg, is_guaranteed_crit, is_true, "", rx_col)
		if kb_val > 0.0 and not bool(e.get("is_dead")) and e.has_method("apply_knockback"):
			e.apply_knockback(((e as Node2D).global_position - center).normalized() * kb_val)

	if chains > 0 and is_instance_valid(primary_enemy):
		var ch_range := float(spec.get("chain_range", 145.0)) * get_area_mult()
		_fire_chain_lightning(center, primary_enemy as Node2D, bonus_dmg, "", chains, ch_range, rx_col, false, true)

func _apply_non_reactive_aura(enemy: Node, elem: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
		return
	var eid := enemy.get_instance_id()
	var existing: Dictionary = reaction_engine._enemy_auras.get(eid, {})
	if existing.is_empty():
		var now_sec := float(Time.get_ticks_msec()) * 0.001
		reaction_engine._enemy_auras[eid] = {elem: now_sec + 3.5}
		if enemy.has_method("set_active_element"):
			enemy.set_active_element(elem, 3.5)
		if (elem == "venom" or elem == "wood") and enemy.has_method("apply_dot"):
			enemy.apply_dot(9.0 * get_dot_mult(), 3.5, false, elem)

func spread_corpse_venom(center: Vector2, dps: float) -> void:
	var r := 125.0 * get_area_mult()
	if player != null and player.get_parent() != null and V2VfxFactory.can_spawn_transient(player.get_parent()):
		var pop := V2ReactionFx.new()
		player.get_parent().add_child(pop)
		pop.setup_weapon_burst("corpse_miasma_pop", center, Vector2.UP, r, Color(0.06, 0.72, 0.51, 0.34))
	else:
		_spawn_pulse_visual(center, r, Color(0.06, 0.72, 0.51, 0.30), "venom", get_area_mult())
	for e in CombatGrid.query(center, r):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		if center.distance_squared_to((e as Node2D).global_position) <= r * r:
			if e.has_method("apply_dot"):
				e.apply_dot(maxf(8.0, dps * 0.8), 3.5, false, "venom")
			_apply_non_reactive_aura(e, "venom")

func _fire_chain_lightning(
	origin: Vector2,
	first: Node2D,
	base_dmg: float,
	elem: String,
	max_hops: int,
	hop_range: float,
	col: Color,
	allow_reaction: bool,
	no_decay: bool,
	awakened_vfx: bool = false
) -> void:
	var pts := PackedVector2Array([origin])
	var visited := {}
	var cur := first
	var dmg := base_dmg
	for _i in range(maxi(1, max_hops)):
		if cur == null or not is_instance_valid(cur) or bool(cur.get("is_dead")):
			break
		visited[cur.get_instance_id()] = true
		var mid := pts[pts.size() - 1].lerp(cur.global_position, 0.5) + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		pts.append(mid)
		pts.append(cur.global_position)
		if allow_reaction:
			deal_v2_damage(cur, dmg, elem, {})
		elif cur.has_method("take_damage_v2"):
			cur.take_damage_v2(dmg, false, false, elem, col if elem.is_empty() else Color(0.0, 0.0, 0.0, 0.0))
		if not no_decay:
			dmg *= 0.85
		cur = _find_next_chain_target(cur.global_position, hop_range, visited)

	if pts.size() >= 2 and player != null and player.get_parent() != null:
		var fx := V2AttackFx.new()
		player.get_parent().add_child(fx)
		fx.setup_chain_bolt(pts, col, no_decay, awakened_vfx)

func _find_closest_enemy_to(pos: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_d2 := radius * radius
	for e in CombatGrid.query(pos, radius):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		var d2 := pos.distance_squared_to((e as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e as Node2D
	return best

func _find_next_chain_target(from_pos: Vector2, radius: float, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d2 := radius * radius
	for e in CombatGrid.query(from_pos, radius):
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		if visited.has(e.get_instance_id()):
			continue
		var d2 := from_pos.distance_squared_to((e as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e as Node2D
	return best

func _clear_enemy_bullets(center: Vector2, radius: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var r2 := radius * radius
	for atk in tree.get_nodes_in_group("boss_attacks"):
		if atk == null or not is_instance_valid(atk):
			continue
		if int(atk.get("kind")) == BossAttack.Kind.PROJECTILE:
			if center.distance_squared_to((atk as Node2D).global_position) <= r2:
				ObjectPools.release_script(atk)

func _enqueue_salvo(item: Dictionary) -> void:
	if _pending_salvos.size() >= MAX_PENDING_SALVOS:
		return
	_pending_salvos.append(item)

func _step_pending_salvos(delta: float) -> void:
	if _pending_salvos.is_empty():
		return
	var parent_world := player.get_parent() if (player != null and is_instance_valid(player)) else null
	if parent_world == null:
		_pending_salvos.clear()
		return
	var i := _pending_salvos.size() - 1
	while i >= 0:
		var item: Dictionary = _pending_salvos[i]
		var left := float(item.get("delay", 0.0)) - delta
		if left <= 0.0:
			_pending_salvos.remove_at(i)
			_spawn_staggered_projectile(parent_world, item)
		else:
			item["delay"] = left
		i -= 1

func _spawn_staggered_projectile(parent_world: Node, item: Dictionary) -> void:
	var kind := String(item.get("kind", ""))
	var dir_v: Vector2 = item.get("dir", Vector2.RIGHT)
	var origin: Vector2 = item.get("origin", Vector2.ZERO)
	if player != null and is_instance_valid(player):
		origin = player.global_position + Vector2(0.0, -24.0) + dir_v.normalized() * 24.0
	var slot_idx := int(item.get("slot_idx", -1))
	if orbit_rig != null and slot_idx >= 0:
		orbit_rig.trigger_slot_recoil(slot_idx, dir_v, 0.45)
	match kind:
		"ice_shard":
			var fx := V2AttackFx.new()
			parent_world.add_child(fx)
			fx.setup_ice_shard(
				self,
				origin,
				dir_v,
				float(item.get("damage", 10.0)),
				float(item.get("range", 310.0)),
				int(item.get("shot_id", 0)),
				float(item.get("slow_pct", 0.25)),
				float(item.get("slow_dur", 2.0)),
				item.get("color", Color(0.22, 0.74, 0.97)) as Color,
				bool(item.get("split_perk", false)),
				int(item.get("pierce", 1)),
				bool(item.get("awakened", false))
			)
		"flame_boomerang":
			var fx := V2AttackFx.new()
			parent_world.add_child(fx)
			fx.setup_boomerang(
				self,
				player,
				origin,
				dir_v,
				float(item.get("damage", 20.0)),
				float(item.get("proj_speed", 860.0)),
				float(item.get("range", 460.0)),
				int(item.get("pierce", 5)),
				String(item.get("elem", "fire")),
				item.get("color", Color(0.98, 0.45, 0.09)) as Color,
				bool(item.get("afterimage", false)),
				true,
				bool(item.get("awakened", false))
			)
		"afterimage_boomerang":
			var fx := V2AttackFx.new()
			parent_world.add_child(fx)
			fx.setup_boomerang(
				self,
				player,
				origin,
				dir_v,
				float(item.get("damage", 15.0)),
				float(item.get("proj_speed", 750.0)),
				float(item.get("range", 390.0)),
				int(item.get("pierce", 4)),
				String(item.get("elem", "metal")),
				item.get("color", Color(0.18, 0.83, 0.75)) as Color,
				true,
				false,
				bool(item.get("awakened", false))
			)

func _spawn_pulse_visual(center: Vector2, radius: float, col: Color, style: String = "default", area_mult: float = 1.0, dur: float = 0.35, awakened_vfx: bool = false) -> void:
	if player == null or player.get_parent() == null:
		return
	var fx := V2AttackFx.new()
	player.get_parent().add_child(fx)
	fx.setup_pulse_ring(center, radius, col, dur, true, style, area_mult, awakened_vfx)

func _spawn_reaction_visual(rx_id: String, center: Vector2, radius: float, col: Color, extra: Dictionary = {}) -> void:
	if player == null or player.get_parent() == null:
		return
	var parent_world := player.get_parent()
	if not V2VfxFactory.can_spawn_transient(parent_world):
		return
	var fx := V2ReactionFx.new()
	parent_world.add_child(fx)
	fx.setup_reaction(rx_id, center, radius, col, extra)

func _spawn_text_popup(world_pos: Vector2, label_text: String, col: Color) -> void:
	if player == null or player.get_parent() == null:
		return
	if ObjectPools.active_count(DAMAGE_NUMBER_SCENE) >= 48:
		return
	var num = ObjectPools.acquire(DAMAGE_NUMBER_SCENE, player.get_parent())
	if num == null:
		return
	num.global_position = world_pos
	if num.has_method("setup_reaction"):
		num.setup_reaction(label_text, col)

func get_hud_weapons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if orbit_rig == null or loader == null:
		return out
	for slot in orbit_rig.slots:
		var wid := String(slot["id"])
		var is_f := bool(slot["is_fusion"])
		var tier := int(slot["tier"])
		var w_def := {}
		if is_f:
			for r in loader.fusion_recipes:
				if String(r["id"]) == wid:
					w_def = r
					break
		else:
			w_def = loader.weapons_by_id.get(wid, {})
		out.append({
			"id": wid,
			"name": String(w_def.get("name", wid)),
			"icon": String(w_def.get("icon", "")),
			"tier": tier,
			"is_fusion": is_f,
			"element": String(w_def.get("element", "fusion")),
		})
	return out

func get_hud_items() -> Array[Dictionary]:
	var counts := {}
	var order: Array[String] = []
	var defs := {}
	for it in owned_items:
		var iid := String(it.get("id", ""))
		if not counts.has(iid):
			counts[iid] = 0
			order.append(iid)
			defs[iid] = it
		counts[iid] = int(counts[iid]) + 1
	var out: Array[Dictionary] = []
	for iid in order:
		var d: Dictionary = defs[iid]
		out.append({
			"id": iid,
			"name": String(d.get("name", iid)),
			"desc": String(d.get("desc", "")),
			"count": int(counts[iid]),
		})
	return out

func has_arcana(arcana_id: String) -> bool:
	return active_arcanas.has(arcana_id)

func add_arcana(arcana_id: String) -> bool:
	if arcana_id.is_empty() or active_arcanas.has(arcana_id):
		return false
	if loader != null and not loader.arcanas_by_id.is_empty() and not loader.arcanas_by_id.has(arcana_id):
		return false
	active_arcanas.append(arcana_id)
	if arcana_id == "arcana_samsara" and player != null and is_instance_valid(player):
		player.revivals_left += 1
	recompute_player_stats()
	v2_loadout_changed.emit()
	return true

func remove_arcana(arcana_id: String) -> bool:
	if not active_arcanas.has(arcana_id):
		return false
	active_arcanas.erase(arcana_id)
	recompute_player_stats()
	v2_loadout_changed.emit()
	return true

func get_arcana_choices(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if loader == null:
		return pool
	for arc in loader.arcanas:
		var aid := String(arc.get("id", ""))
		if aid.is_empty() or active_arcanas.has(aid):
			continue
		var unlocked := bool(arc.get("default_unlocked", true))
		if not unlocked and Stats != null and Stats.has_method("is_arcana_unlocked"):
			unlocked = Stats.is_arcana_unlocked(aid)
		if unlocked:
			pool.append((arc as Dictionary).duplicate(true))
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func get_starter_weapon_id() -> String:
	if player != null and is_instance_valid(player):
		return CharacterData.get_v2_start_weapon(str(player.character_id))
	return "wpn_jade_sword"

func is_arcana_applicable_to_weapon(arcana_id: String, weapon_id: String) -> bool:
	if loader == null or not loader.arcanas_by_id.has(arcana_id):
		return false
	var arc: Dictionary = loader.arcanas_by_id[arcana_id]
	var scope := String(arc.get("whitelist_scope", "weapons"))
	if scope == "starter_and_fusion":
		var starter := get_starter_weapon_id()
		if weapon_id == starter:
			return true
		for rec in loader.fusion_recipes:
			if String(rec.get("id", "")) == weapon_id:
				var reqs: Array = rec.get("requires", rec.get("inputs", []))
				if reqs.has(starter):
					return true
		return false
	var wl: Array = arc.get("whitelist_weapons", [])
	return wl.has(weapon_id)

func get_empty_slot_count() -> int:
	var used := orbit_rig.slots.size() if orbit_rig != null else 0
	return maxi(0, get_unlocked_slots() - used)

func get_arcana_weapon_damage_mult(weapon_id: String) -> float:
	var mult := 1.0
	if has_arcana("arcana_calamity_ember") and is_arcana_applicable_to_weapon("arcana_calamity_ember", weapon_id):
		mult += 0.15 + get_curse_pct()
	if has_arcana("arcana_glacial_shatter") and is_arcana_applicable_to_weapon("arcana_glacial_shatter", weapon_id):
		mult += 0.35
	if has_arcana("arcana_thunder_venom") and is_arcana_applicable_to_weapon("arcana_thunder_venom", weapon_id):
		mult += 0.35
	return mult

func on_player_revived() -> void:
	if has_arcana("arcana_samsara"):
		revival_stacks += 1
		recompute_player_stats()

func trigger_void_magnet() -> void:
	if player == null or not is_instance_valid(player) or not is_inside_tree() or get_tree() == null:
		return
	for g in get_tree().get_nodes_in_group("exp_gems"):
		if is_instance_valid(g) and g.has_method("attract_to"):
			g.attract_to(player)
	for st in get_tree().get_nodes_in_group("spirit_stones"):
		if is_instance_valid(st) and st.has_method("attract_to"):
			st.attract_to(player)

func get_weapon_limit_break_stacks(weapon_id: String, stat_key: String) -> int:
	var entry: Dictionary = weapon_limit_breaks.get(weapon_id, {})
	var stacks: Dictionary = entry.get("stacks", {})
	return int(stacks.get(stat_key, 0))

func get_weapon_limit_break_mods(weapon_id: String) -> Dictionary:
	var entry: Dictionary = weapon_limit_breaks.get(weapon_id, {})
	var mods: Dictionary = entry.get("mods", {})
	return mods

func apply_weapon_limit_break(weapon_id: String, stat_key: String, delta_val: float, max_stacks: int = 5) -> bool:
	if weapon_id.is_empty() or stat_key.is_empty():
		return false
	var entry: Dictionary = weapon_limit_breaks.get(weapon_id, {"stacks": {}, "mods": {}})
	var stacks: Dictionary = entry["stacks"]
	var mods: Dictionary = entry["mods"]
	var cur := int(stacks.get(stat_key, 0))
	if cur >= max_stacks:
		return false
	stacks[stat_key] = cur + 1
	mods[stat_key] = float(mods.get(stat_key, 0.0)) + delta_val
	weapon_limit_breaks[weapon_id] = entry
	return true

func count_fusions_owned() -> int:
	if orbit_rig == null:
		return 0
	var c := 0
	for s in orbit_rig.slots:
		if bool(s.get("is_fusion", false)):
			c += 1
	return c

func get_stats_summary() -> Dictionary:
	return {
		"gold": run_gold,
		"dmg_pct": roundi((get_damage_mult() - 1.0) * 100.0),
		"spd_pct": roundi((get_attack_speed_mult() - 1.0) * 100.0),
		"crit_pct": roundi(get_crit_chance() * 100.0),
		"mastery_pct": roundi((get_mastery_bonus() + float(item_mods.get("reaction_damage_pct", 0.0))) * 100.0),
		"armor": int(round(player.armor)) if player != null else 0,
		"dodge_pct": roundi(player.dodge_chance * 100.0) if player != null else 0,
		"luck_pct": roundi(get_luck() * 100.0),
		"curse_pct": roundi(get_curse_pct() * 100.0),
	}
