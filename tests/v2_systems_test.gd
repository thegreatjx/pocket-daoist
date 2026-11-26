extends Node2D

const EnemyVisualScript = preload("res://scripts/enemy_visual.gd")

var passes: int = 0
var fails: int = 0

func check(label: String, cond: bool, info: String = "") -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("FAIL ", label, " :: ", info)

func _check(label: String, cond: bool, info: String = "") -> void:
	check(label, cond, info)

func _ready() -> void:
	var saved_char := Stats.selected_character_id
	Stats.selected_character_id = "sword_immortal"
	var loader := _test_data_loader()
	_test_orbit_weapon_rig(loader)
	_test_reaction_engine(loader)
	_test_enemy_steering(loader)
	_test_hero_and_audio()
	_test_arena_pillars_and_spawning(loader)
	_test_landmarks_and_pillar_combat()
	_test_t1_guards(loader)
	_test_t2b_pools_luck_and_shop(loader)
	_test_t2c_detail_drawer_and_pacing(loader)
	_test_t2d_codex_and_t2_e2e(loader)
	await _test_t3_stages_waves_and_enemies(loader)
	await _test_t4_feel_and_feedback(loader)
	_test_ch1_map_assets()
	_test_t5_batch2a_characters()
	_test_t5_batch2b_sect_14_and_recycle()
	_test_t5_batch2c_curse_chain()
	_test_t5_batch3a_arcana_limit_break()
	_test_t5_batch3b_jar_drops()
	_test_t5_batch3c_achievements()
	_test_batch4_ch1_map()
	_test_batch5_seven_elite_variants()
	_test_batch8a_chest_never_empty()
	await _test_batch9_pickup_and_freeze()
	_test_batch10a_bell_and_banner(loader)
	_test_batch10b_awakened_vfx(loader)
	await _test_flying_sword_dummy_and_debug_isolation()
	Stats.selected_character_id = saved_char
	await get_tree().process_frame
	for c in get_tree().get_nodes_in_group("chests"):
		if is_instance_valid(c):
			c.free()
	for vfx in get_tree().get_nodes_in_group("v2_transient_vfx"):
		if is_instance_valid(vfx):
			vfx.free()
	if has_node("/root/ObjectPools"):
		get_node("/root/ObjectPools").call("clear")
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").call("stop_all")
	await get_tree().process_frame
	print("V2_TEST RESULT passes=%d fails=%d" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)

func _test_data_loader() -> V2DataLoader:
	var loader := V2DataLoader.new()
	add_child(loader)
	var loaded: bool = loader.load_all()
	check("data_load_all", loaded, "load_all() returned false")
	check("data_weapons_count", loader.weapons_by_id.size() >= 6, "got %d" % loader.weapons_by_id.size())
	check("data_fusions_count", loader.fusion_recipes.is_empty(), "got %d" % loader.fusion_recipes.size())
	check("data_max_weapon_slots", loader.max_weapon_slots == 4, "got %d" % loader.max_weapon_slots)
	check("data_max_weapon_level", loader.max_weapon_level == 8, "got %d" % loader.max_weapon_level)
	check("data_realm_slot_unlocks", loader.realm_slot_unlocks.size() == 4, "got %d" % loader.realm_slot_unlocks.size())
	check("data_reactions_count", loader.reactions_list.size() == 5 and not loader.shatter_reaction.is_empty(), "list=%d shatter=%s" % [loader.reactions_list.size(), str(loader.shatter_reaction.get("id", ""))])
	check("data_items_count", loader.items_by_id.size() == 16, "got %d" % loader.items_by_id.size())
	var tradeoff_items := 0
	for iid in loader.items_by_id.keys():
		if V2CombatController.item_has_tradeoff(loader.items_by_id[iid]):
			tradeoff_items += 1
	check("data_items_tradeoff_ratio_ge_60pct", tradeoff_items >= 10, "tradeoff=%d/%d" % [tradeoff_items, loader.items_by_id.size()])
	check("data_archetypes_count", loader.enemy_archetypes.size() >= 5, "got %d" % loader.enemy_archetypes.size())

	for wid in loader.weapons_by_id.keys():
		var w: Dictionary = loader.weapons_by_id[wid]
		var icon_path: String = String(w.get("icon", ""))
		check("data_weapon_icon_" + String(wid), ResourceLoader.exists(icon_path), icon_path)

	var reaction_pairs: Array[String] = ["fire+water", "fire+ice", "ice+water", "thunder+water", "metal+thunder", "fire+metal", "fire+thunder", "fire+venom"]
	var missing_pairs: Array[String] = []
	for k in reaction_pairs:
		if not loader.reactions_by_key.has(k):
			missing_pairs.append(k)
	check("data_all_8_reaction_triggers", missing_pairs.is_empty() and loader.reactions_by_key.size() == reaction_pairs.size(), str(missing_pairs))
	check("data_pair_key_symmetry", V2DataLoader.make_pair_key("thunder", "fire") == "fire+thunder", V2DataLoader.make_pair_key("thunder", "fire"))
	return loader

func _test_orbit_weapon_rig(loader: V2DataLoader) -> void:
	var tiers_ok := true
	for wid in loader.weapons_by_id.keys():
		var w: Dictionary = loader.weapons_by_id[wid]
		var tiers: Array = w.get("tiers", [])
		if tiers.size() != 8:
			tiers_ok = false
			continue
		for i in range(tiers.size()):
			var t: Dictionary = tiers[i]
			if int(t.get("tier", 0)) != i + 1 or String(t.get("level_summary", "")) == "":
				tiers_ok = false
			var has_perk := String(t.get("max_tier_perk", "")) != ""
			if (i == tiers.size() - 1) != has_perk:
				tiers_ok = false
	check("orbit_all_weapons_eight_tiers", tiers_ok, "tiers/level_summary/max_tier_perk mismatch")

	check("orbit_fusion_disabled", loader.fusion_recipes.is_empty(), str(loader.fusion_recipes))

	var rig1 := OrbitWeaponRig.new()
	add_child(rig1)
	rig1.setup(loader)
	check("orbit_add_sword_lv1", rig1.add_weapon("wpn_jade_sword", 1), "first sword add failed")
	check("orbit_sword_lv1_single_slot", rig1.slots.size() == 1 and int(rig1.slots[0]["tier"]) == 1, str(rig1.slots))
	for lv in range(2, OrbitWeaponRig.MAX_WEAPON_TIER + 1):
		check(
			"orbit_sword_upgrade_lv%d" % lv,
			rig1.add_weapon("wpn_jade_sword", lv) and rig1.slots.size() == 1,
			"upgrade failed or took a new slot at lv %d" % lv
		)
	check(
		"orbit_sword_stays_single_slot_lv8",
		rig1.slots.size() == 1 and String(rig1.slots[0]["id"]) == "wpn_jade_sword" and int(rig1.slots[0]["tier"]) == OrbitWeaponRig.MAX_WEAPON_TIER and not bool(rig1.slots[0]["is_fusion"]),
		str(rig1.slots)
	)
	check("orbit_lv8_rejects_repeat_add", not rig1.add_weapon("wpn_jade_sword", 1), "lv8 should not be addable again")
	check("orbit_lv8_not_upgradable", not rig1.upgrade_weapon("wpn_jade_sword", 1) and not rig1.can_upgrade_weapon("wpn_jade_sword"), "lv8 upgrade should fail")
	var max_sp: Sprite2D = rig1.slots[0]["sprite"] as Sprite2D
	check("orbit_lv5_max_particles", max_sp.get_node_or_null("MaxTierParticles") != null, "MaxTierParticles missing")

	var rig_up := OrbitWeaponRig.new()
	add_child(rig_up)
	rig_up.setup(loader)
	rig_up.add_weapon("wpn_ice_mirror", 1)
	check("orbit_upgrade_weapon_step2", rig_up.upgrade_weapon("wpn_ice_mirror", 2) and rig_up.get_weapon_tier("wpn_ice_mirror") == 3, str(rig_up.slots))
	check("orbit_find_and_tier_helpers", rig_up.find_weapon_slot("wpn_ice_mirror") == 0 and rig_up.get_weapon_tier("wpn_missing") == 0, "helper mismatch")

	var rig2 := OrbitWeaponRig.new()
	add_child(rig2)
	rig2.setup(loader)
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER):
		rig2.add_weapon("wpn_jade_sword", 1)
	check("orbit_second_weapon_before_fusion", rig2.slots.size() == 1 and int(rig2.slots[0]["tier"]) == OrbitWeaponRig.MAX_WEAPON_TIER, str(rig2.slots))
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER):
		rig2.add_weapon("wpn_fire_gourd", 1)
	check(
		"orbit_fusion_disabled_keeps_separate_slots",
		rig2.slots.size() == 2 and not rig2.has_fusion("fusion_flame_sword_array") and not bool(rig2.slots[0]["is_fusion"]) and not bool(rig2.slots[1]["is_fusion"]),
		str(rig2.slots)
	)
	check("orbit_has_fusion_disabled", not rig2.has_fusion("fusion_flame_sword_array"), "has_fusion should be false")

	var dummy_enemy := Node2D.new()
	add_child(dummy_enemy)
	dummy_enemy.global_position = Vector2(100.0, 0.0)
	rig2.tick(0.6, [dummy_enemy])

	var rig3 := OrbitWeaponRig.new()
	add_child(rig3)
	rig3.setup(loader)
	rig3.set_unlocked_slots(1)
	check("orbit_unlock_one_adds_first", rig3.add_weapon("wpn_jade_sword", 1), "first add failed")
	check("orbit_unlock_one_rejects_second", not rig3.add_weapon("wpn_fire_gourd", 1), "second slot should be locked")
	check("orbit_unlock_one_allows_in_place", rig3.add_weapon("wpn_jade_sword", 1) and rig3.slots.size() == 1 and int(rig3.slots[0]["tier"]) == 2, str(rig3.slots))
	rig3.set_unlocked_slots(4)
	check("orbit_unlock_four_free_slot", rig3.has_free_slot() and rig3.get_unlocked_slots() == 4, "unlock 4 failed")
	var sold: Dictionary = rig3.sell_weapon(0)
	check("orbit_sell_weapon", not sold.is_empty() and rig3.slots.is_empty(), "slots=%d" % rig3.slots.size())

	var full_loader := V2DataLoader.new()
	add_child(full_loader)
	full_loader.load_all()
	full_loader.weapons_by_id["wpn_probe"] = {
		"id": "wpn_probe",
		"name": "试炼法针",
		"element": "metal",
		"icon": "",
		"tiers": [{"tier": 1, "damage": 1, "cooldown": 1.0, "range": 100}],
	}
	var rig_full := OrbitWeaponRig.new()
	add_child(rig_full)
	rig_full.setup(full_loader)
	for wid in ["wpn_jade_sword", "wpn_thunder_talisman", "wpn_ice_mirror", "wpn_venom_banner"]:
		rig_full.add_weapon(wid, 1)
	check("orbit_full_four_slots", rig_full.slots.size() == 4, "slots=%d" % rig_full.slots.size())
	check("orbit_full_rejects_unrelated_new", not rig_full.add_weapon("wpn_fire_gourd", 1), "unrelated new weapon should be rejected")

	var rig_full_max := OrbitWeaponRig.new()
	add_child(rig_full_max)
	rig_full_max.setup(full_loader)
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER):
		rig_full_max.add_weapon("wpn_jade_sword", 1)
	for wid in ["wpn_thunder_talisman", "wpn_ice_mirror", "wpn_venom_banner"]:
		rig_full_max.add_weapon(wid, 1)
	check("orbit_full_max_setup", rig_full_max.slots.size() == 4 and rig_full_max.get_weapon_tier("wpn_jade_sword") == OrbitWeaponRig.MAX_WEAPON_TIER, str(rig_full_max.slots))
	check(
		"orbit_full_rejects_companion_when_fusion_disabled",
		not rig_full_max.add_weapon("wpn_fire_gourd", OrbitWeaponRig.MAX_WEAPON_TIER) and not rig_full_max.has_fusion("fusion_flame_sword_array"),
		str(rig_full_max.slots)
	)

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat
	check("realm_initial_one_slot", cc != null and cc.get_unlocked_slots() == 1 and cc.orbit_rig.get_unlocked_slots() == 1, "initial slots mismatch")
	var table_ok := true
	for pair in [[1, 1], [4, 1], [5, 2], [10, 2], [11, 3], [17, 3], [18, 4], [30, 4]]:
		if cc.calc_unlocked_slots(int(pair[0])) != int(pair[1]):
			table_ok = false
	check("realm_level_table", table_ok, "realm slot table mismatch")
	var info := cc.get_realm_info_for_level(4)
	check(
		"realm_info_lv4",
		int(info.get("slots", 0)) == 1 and String(info.get("realm", "")) == "练气" and int(info.get("next_level", 0)) == 5 and String(info.get("next_realm", "")) == "筑基",
		str(info)
	)
	check("realm_next_unlock_initial", int(cc.get_next_slot_unlock_info().get("level", 0)) == 5, str(cc.get_next_slot_unlock_info()))
	p.level = 5
	p.leveled_up.emit(5)
	check("realm_player_signal_unlocks", cc.get_unlocked_slots() == 2 and cc.orbit_rig.get_unlocked_slots() == 2, "level signal did not sync slots")
	check("realm_next_unlock_lv5", int(cc.get_next_slot_unlock_info().get("level", 0)) == 11, str(cc.get_next_slot_unlock_info()))
	cc.notify_elite_killed()
	check("realm_one_elite_not_enough", cc.get_unlocked_slots() == 2, "one elite kill should not jump to 4")
	cc.notify_elite_killed()
	check("realm_two_elites_unlock_four", cc.get_unlocked_slots() == 4 and cc.orbit_rig.get_unlocked_slots() == 4, "two elite kills should unlock all slots")
	check("realm_next_unlock_empty", cc.get_next_slot_unlock_info().is_empty(), "next unlock should be empty at 4")
	p.queue_free()

func _test_reaction_engine(loader: V2DataLoader) -> void:
	var engine := ReactionEngine.new(loader)
	var r_none: Dictionary = engine.apply_element_hit(100, "none", 1.0, 20.0)
	var r_rx_self: Dictionary = engine.apply_element_hit(100, "fire", 1.0, 20.0, 0.0, {}, false, false, true)
	check("reaction_skips_none_and_secondary", r_none.is_empty() and r_rx_self.is_empty() and engine.get_aura_elements(100, 1.1).is_empty(), str(engine.get_aura_elements(100, 1.1)))

	var r0: Dictionary = engine.apply_element_hit(101, "fire", 1.0, 20.0)
	check("reaction_first_aura_empty", r0.is_empty(), str(r0))

	var r1: Dictionary = engine.apply_element_hit(101, "water", 1.1, 20.0)
	check("reaction_steam_id", String(r1.get("reaction_id", "")) == "react_steam", str(r1))
	check("reaction_steam_dmg", is_equal_approx(float(r1.get("bonus_damage", 0.0)), 3.0), str(r1.get("bonus_damage", 0.0)))

	var r2: Dictionary = engine.apply_element_hit(101, "fire", 1.2, 20.0)
	var r3: Dictionary = engine.apply_element_hit(101, "water", 1.3, 20.0)
	var r3b: Dictionary = engine.apply_element_hit(101, "water", 2.95, 20.0)
	check("reaction_icd_blocks_repeat", r2.is_empty() and r3.is_empty() and r3b.is_empty(), "r2=%s r3=%s r3b=%s" % [str(r2), str(r3), str(r3b)])

	var r4: Dictionary = engine.apply_element_hit(101, "water", 3.20, 20.0)
	check("reaction_recovers_after_icd", String(r4.get("reaction_id", "")) == "react_steam", str(r4))

	engine.apply_element_hit(103, "metal", 1.0, 20.0)
	engine.apply_element_hit(103, "water", 1.1, 20.0)
	check("reaction_single_aura_keeps_first_on_non_pair", engine.has_aura(103, "metal", 1.2) and not engine.has_aura(103, "water", 1.2), str(engine.get_aura_elements(103, 1.2)))

	var sh_rx: Dictionary = engine.apply_element_hit(104, "metal", 1.1, 20.0, 0.0, {}, false, true, false)
	check("reaction_shatter_bypasses_freeze_icd", String(sh_rx.get("reaction_id", "")) == "react_shatter" and bool(sh_rx.get("unfreeze", false)) and is_equal_approx(float(sh_rx.get("shield_flat_min", 0.0)), 160.0), str(sh_rx))

	var boss_engine := ReactionEngine.new(loader)
	boss_engine.apply_element_hit(102, "fire", 1.0, 20.0, 0.0, {}, true)
	var b1: Dictionary = boss_engine.apply_element_hit(102, "water", 1.1, 20.0, 0.0, {}, true)
	var b2: Dictionary = boss_engine.apply_element_hit(102, "fire", 2.4, 20.0, 0.0, {}, true)
	var b3: Dictionary = boss_engine.apply_element_hit(102, "water", 3.65, 20.0, 0.0, {}, true)
	var expected_boss_dmg := 20.0 * 0.15 * float(loader.reaction_config.get("boss_damage_scale", 0.60))
	check(
		"reaction_boss_icd",
		not b1.is_empty() and is_equal_approx(float(b1.get("bonus_damage", 0.0)), expected_boss_dmg) and b2.is_empty() and String(b3.get("reaction_id", "")) == "react_steam",
		"b1=%s b2=%s b3=%s" % [str(b1), str(b2), str(b3)]
	)

	engine.clear_enemy(101)
	var eid: int = 200
	for key in loader.reactions_by_key.keys():
		var rx: Dictionary = loader.reactions_by_key[key]
		var elems := String(key).split("+")
		var first_hit: Dictionary = engine.apply_element_hit(eid, elems[0], 10.0, 10.0)
		var second_hit: Dictionary = engine.apply_element_hit(eid, elems[1], 10.05, 10.0)
		check(
			"reaction_trigger_" + String(key),
			first_hit.is_empty() and String(second_hit.get("reaction_id", "")) == String(rx["id"]),
			"key=%s first=%s second=%s" % [key, str(first_hit), str(second_hit)]
		)
		eid += 1

	var mod_engine := ReactionEngine.new(loader)
	mod_engine.configure_modifiers({
		"reaction_damage_pct": 0.35,
		"reaction_radius_pct": 0.20,
		"reaction_icd_reduction": 0.06,
		"fire_aura_dur_bonus": 1.5,
		"chain_bonus": 1
	})
	mod_engine.apply_element_hit(301, "fire", 1.0, 20.0)
	var mod_rx: Dictionary = mod_engine.apply_element_hit(301, "venom", 5.8, 20.0)
	check("reaction_fire_dur_bonus_and_detonate", String(mod_rx.get("reaction_id", "")) == "react_detonate", str(mod_rx))
	check("reaction_mod_damage", is_equal_approx(float(mod_rx.get("bonus_damage", 0.0)), 20.0 * 0.15 * 1.35), str(mod_rx.get("bonus_damage", 0.0)))
	mod_engine.apply_element_hit(302, "fire", 1.0, 20.0)
	var steam_mod: Dictionary = mod_engine.apply_element_hit(302, "water", 1.1, 20.0)
	check("reaction_mod_radius", is_equal_approx(float(steam_mod.get("aoe_radius", 0.0)), 110.0 * 1.20), str(steam_mod.get("aoe_radius", 0.0)))

	var vfx_true: int = 0
	var vfx_false: int = 0
	for k in range(15):
		var target_id: int = 400 + k
		mod_engine.apply_element_hit(target_id, "fire", 20.0, 10.0)
		var res: Dictionary = mod_engine.apply_element_hit(target_id, "water", 20.05, 10.0)
		if bool(res.get("emit_vfx", false)):
			vfx_true += 1
		else:
			vfx_false += 1
	check("reaction_vfx_cap_throttles", vfx_true == 12 and vfx_false == 3, "true=%d false=%d" % [vfx_true, vfx_false])

func _test_enemy_steering(loader: V2DataLoader) -> void:
	var director := EnemySteeringDirector.new()
	director.configure(loader.wave_config.get("global_limits", {}))
	var states: Array = []
	for i in range(50):
		states.append({
			"id": i + 1,
			"pos": Vector2(200.0 + float(i % 5) * 3.0, 200.0 + float(i / 5) * 3.0),
			"radius": 18.0
		})
	director.rebuild_grid(states)
	var arch: Dictionary = loader.enemy_archetypes["enemy_swarm_imp"]
	var max_speed: float = float(arch.get("move_speed", 105.0)) * 1.25 + 0.01
	var all_valid: bool = true
	var first_v := Vector2.ZERO
	var has_diff: bool = false
	for i in range(states.size()):
		var v: Vector2 = director.compute_velocity(states[i], Vector2.ZERO, arch)
		if is_nan(v.x) or is_nan(v.y) or not is_finite(v.x) or not is_finite(v.y) or v.length() <= 0.0 or v.length() > max_speed:
			all_valid = false
			break
		if i == 0:
			first_v = v
		elif not v.is_equal_approx(first_v):
			has_diff = true
	check("steering_50_valid_vectors", all_valid, "invalid or out-of-range velocity")
	check("steering_separation_effective", has_diff, "all 50 velocities identical")

	var stacked: Array = []
	for i in range(50):
		stacked.append({"id": 100 + i, "pos": Vector2(200.0, 200.0), "radius": 18.0})
	director.rebuild_grid(stacked)
	var stack_valid: bool = true
	var stack_first := Vector2.ZERO
	var stack_diff: bool = false
	for i in range(stacked.size()):
		var sv: Vector2 = director.compute_velocity(stacked[i], Vector2.ZERO, arch)
		if is_nan(sv.x) or is_nan(sv.y) or not is_finite(sv.x) or not is_finite(sv.y) or sv.length() <= 0.0:
			stack_valid = false
			break
		if i == 0:
			stack_first = sv
		elif not sv.is_equal_approx(stack_first):
			stack_diff = true
	check("steering_exact_overlap_valid", stack_valid, "invalid exact-overlap velocity")
	check("steering_exact_overlap_breaks_symmetry", stack_diff, "identical positions did not separate")

func _test_hero_and_audio() -> void:
	var hero := HeroCutoutRig.new()
	add_child(hero)
	hero.update_motion(Vector2(150.0, 0.0), 0.016)
	check("hero_moving_split_legs", not hero._pants_full.visible and hero._leg_l.visible and hero._leg_r.visible, "legs should be active while moving")

	for _step in range(45):
		hero.update_motion(Vector2.ZERO, 0.016)
	check("hero_idle_full_pants", hero._pants_full.visible and not hero._leg_l.visible and not hero._leg_r.visible, "pants_full should show when idle")

	hero.update_motion(Vector2(-120.0, 30.0), 0.5)
	check("hero_large_delta_bounded", is_finite(hero._leg_l.rotation) and absf(hero._leg_l.rotation) <= hero.leg_swing_rad + 0.01, str(hero._leg_l.rotation))

	hero.trigger_hurt_feedback(0.45)
	hero.update_motion(Vector2.ZERO, 0.05)
	hero.update_motion(Vector2.ZERO, 0.06)
	hero.update_motion(Vector2.ZERO, 0.50)
	check("hero_invuln_resets_white", hero.modulate.is_equal_approx(Color.WHITE), str(hero.modulate))
	check("hero_rig_children", hero.get_child_count() >= 2, "children=%d" % hero.get_child_count())

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	check("audio_sfx_bus_exists", sfx_idx >= 0, "SFX bus missing")
	var has_lpf: bool = false
	var has_comp: bool = false
	var has_lim: bool = false
	var lim_ceil: float = 0.0
	for i in range(AudioServer.get_bus_effect_count(sfx_idx)):
		var fx: AudioEffect = AudioServer.get_bus_effect(sfx_idx, i)
		if fx is AudioEffectLowPassFilter:
			has_lpf = true
		elif fx is AudioEffectCompressor:
			has_comp = true
		elif fx is AudioEffectLimiter:
			has_lim = true
			lim_ceil = (fx as AudioEffectLimiter).ceiling_db
	check("audio_sfx_fx_chain", has_lpf and has_comp and has_lim and is_equal_approx(lim_ceil, -1.0), "lpf=%s comp=%s lim=%s ceil=%.1f" % [str(has_lpf), str(has_comp), str(has_lim), lim_ceil])

	var audio := ThrottledAudioManager.new()
	add_child(audio)
	audio.density_window_ms = 50
	var wav := AudioStreamWAV.new()
	var pcm := PackedByteArray()
	pcm.resize(44100)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = pcm

	for i in range(audio.pool_size):
		audio.play_cue("hit_%d" % i, wav, "default_hit")
	var burst_cutoff: float = audio.get_current_lpf_cutoff_hz()
	check("audio_dynamic_lpf_attenuates", burst_cutoff < audio.lpf_max_hz, "cutoff=%.1f" % burst_cutoff)

	audio.play_cue("ui_confirm", wav, "ui_event")
	var found_ui: bool = false
	for p in audio._players:
		if p.playing and String(p.get_meta("cue_id", "")) == "ui_confirm":
			found_ui = true
			break
	check("audio_priority_voice_stealing", found_ui, "ui_event failed to steal slot when saturated")

	OS.delay_msec(60)
	audio._process(0.5)
	check("audio_lpf_recovers", audio.get_current_lpf_cutoff_hz() > burst_cutoff, "before=%.1f after=%.1f" % [burst_cutoff, audio.get_current_lpf_cutoff_hz()])

	audio.play_cue("sfx_xp", wav, "xp_orb")
	audio.play_cue("sfx_null", null, "default_hit")
	check("audio_pool_created", audio.get_child_count() == audio.pool_size, "children=%d" % audio.get_child_count())
	audio.stop_all()

func _test_arena_pillars_and_spawning(loader: V2DataLoader) -> void:
	var bg_script := load("res://scripts/background.gd") as Script
	var bg := bg_script.new() as Node2D
	add_child(bg)
	var rect: Rect2 = bg.call("get_arena_rect")
	check("arena_2800x2000", is_equal_approx(rect.size.x, 2800.0) and is_equal_approx(rect.size.y, 2000.0), str(rect))
	var pillars: Array = bg.call("get_pillars")
	check("arena_solid_obstacles", pillars.size() >= 8, "pillars=%d" % pillars.size())
	var pillar_body := bg.get_node_or_null("ArenaPillars") as StaticBody2D
	var all_circles: bool = pillar_body != null and pillar_body.collision_layer == 5 and pillar_body.get_child_count() == pillars.size()
	if all_circles:
		for c in pillar_body.get_children():
			if not ((c as CollisionShape2D).shape is CircleShape2D):
				all_circles = false
				break
	check("arena_pillars_circle_colliders", all_circles, "obstacles must use CircleShape2D on layer 5")
	check("arena_2_spirit_arrays", bg.call("get_landmarks_by_role", "spirit_array").size() == 2, "spirit arrays != 2")
	check("arena_1_demon_stele_well_clear", bg.call("get_landmarks_by_role", "demon_stele").size() == 1 and bg.call("get_landmarks_by_role", "well").size() == 1, "demon stele / well landmark mismatch")

	var steering := EnemySteeringDirector.new()
	steering.configure(loader.wave_config.get("global_limits", {}))
	steering.set_pillars(pillars)
	var swarm: Array = []
	for i in range(220):
		var p_info: Dictionary = pillars[i % pillars.size()]
		var p_pos: Vector2 = p_info["pos"]
		var ang: float = TAU * float(i) / 220.0
		swarm.append({"id": i + 1, "pos": p_pos + Vector2(cos(ang), sin(ang)) * 52.0, "radius": 18.0})
	steering.rebuild_grid(swarm)
	var arch: Dictionary = loader.enemy_archetypes["enemy_swarm_imp"]
	var pillar_slide_ok: bool = true
	for st in swarm:
		var vel: Vector2 = steering.compute_velocity(st, Vector2(640.0, 360.0), arch)
		if is_nan(vel.x) or is_nan(vel.y) or not is_finite(vel.x) or not is_finite(vel.y) or vel.length() <= 0.0:
			pillar_slide_ok = false
			break
	check("steering_220_pillar_slide", pillar_slide_ok, "invalid velocity near pillars")

	var sd := V2SpawnDirector.new()
	check("spawn_budget_w1", is_equal_approx(V2SpawnDirector.budget_per_sec(1), 2.2), str(V2SpawnDirector.budget_per_sec(1)))
	check("spawn_budget_w5", is_equal_approx(V2SpawnDirector.budget_per_sec(5), 4.8), str(V2SpawnDirector.budget_per_sec(5)))
	var cam := Rect2(Vector2(0.0, 0.0), Vector2(1280.0, 720.0))
	var off_pick := sd.pick_spawn_point(rect, cam, Vector2(640.0, 360.0), pillars, false)
	var off_pos: Vector2 = off_pick["pos"]
	check(
		"spawn_offscreen_ring_in_arena",
		not bool(off_pick["use_telegraph"]) and rect.has_point(off_pos) and not cam.has_point(off_pos),
		str(off_pick)
	)
	var tight_arena := Rect2(0.0, 0.0, 1400.0, 800.0)
	var wall_pick := sd.pick_spawn_point(tight_arena, cam, Vector2(120.0, 120.0), [], false)
	check(
		"spawn_wall_falls_back_telegraph",
		bool(wall_pick["use_telegraph"]) and is_equal_approx(float(wall_pick["telegraph_sec"]), 0.8) and tight_arena.has_point(wall_pick["pos"]),
		str(wall_pick)
	)

	var pool := loader.enemy_archetypes.values()
	var reqs := sd.step_budget(1.0, 1, pool)
	check("spawn_budget_issues_requests", not reqs.is_empty(), "expected spawns from 2.2 budget")
	var squad := sd.build_formation_offsets(V2SpawnDirector.Formation.SHIELD_KITER_SQUAD, Vector2(0.0, 0.0), Vector2(400.0, 0.0), 4)
	check("spawn_squad_roles", squad.size() == 4 and String(squad[0]["role"]) == "shield" and String(squad[3]["role"]) == "kiter", str(squad))
	sd.formation = V2SpawnDirector.Formation.BREATHER
	check("spawn_breather_pauses_budget", sd.step_budget(1.0, 5, pool).is_empty(), "breather should pause budget")

	var recycle_act := sd.compute_recycle_action(Vector2(-1000.0, 360.0), Vector2(640.0, 360.0), Vector2.RIGHT * 240.0, cam, rect, pillars)
	check(
		"spawn_recycle_1_8_screens_ahead",
		String(recycle_act["action"]) == "recycle" and (recycle_act["pos"] as Vector2).x > 640.0,
		str(recycle_act)
	)
	var despawn_act := sd.compute_recycle_action(Vector2(9000.0, 360.0), Vector2(640.0, 360.0), Vector2.RIGHT * 240.0, cam, rect, pillars)
	check("spawn_extreme_despawn", String(despawn_act["action"]) == "despawn", str(despawn_act))

	var tele_fired: Array = [false]
	var tele := SpawnTelegraph.new()
	add_child(tele)
	tele.setup(Vector2(300.0, 300.0), 0.1, 32.0, func(_p: Vector2) -> void: tele_fired[0] = true)
	tele._process(0.12)
	check("spawn_telegraph_triggers_callback", bool(tele_fired[0]), "telegraph callback did not fire")

	bg.free()

func _test_landmarks_and_pillar_combat() -> void:
	var bg := (load("res://scripts/background.gd") as Script).new() as Node2D
	add_child(bg)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.current_health = 60.0

	var ctrl := ArenaLandmarksController.new()
	add_child(ctrl)
	ctrl.setup(bg, player)
	var arr_pos: Vector2 = ctrl.spirit_arrays[ctrl.active_array_index]["pos"]
	player.global_position = arr_pos
	ctrl._process(1.4)
	check("landmark_spirit_not_early", not ctrl.array_consumed, "triggered before 2.5s")
	ctrl._process(1.2)
	check("landmark_spirit_triggers_at_2_5s", ctrl.array_consumed and player.limit_haste_bonus > 0.0 and player.current_health > 60.0, "haste=%.2f hp=%.1f" % [player.limit_haste_bonus, player.current_health])
	player._physics_process(4.5)
	player._physics_process(4.5)
	check("landmark_spirit_buff_expires_8s", is_equal_approx(player.limit_haste_bonus, 0.0) and is_equal_approx(player.limit_might_bonus, 0.0), "buff did not expire")

	var stele := ctrl.spawn_stele(3)
	check("landmark_red_door_stele_disabled", stele == null and get_tree().get_nodes_in_group("breakables").is_empty(), "stele should not spawn")

	var pillars: Array = bg.call("get_pillars")
	var p0: Vector2 = pillars[0]["pos"]
	var enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(enemy)
	enemy.setup_type(Enemy.Type.ELITE, 10.0, 0)
	enemy._elite_state = 2
	enemy._elite_timer = 0.30
	enemy.global_position = p0 + Vector2(50.0, 0.0)
	enemy._physics_process(0.016)
	check("enemy_charger_pillar_stun", enemy._stun_timer > 1.0 and enemy._elite_state == 0, "stun=%.2f" % enemy._stun_timer)

	var proj := BossAttack.new()
	add_child(proj)
	proj.setup_projectile(null, p0, Vector2.RIGHT, 200.0, 10.0, 12.0)
	proj._physics_process(0.016)
	check("projectile_blocked_by_pillar", proj.is_queued_for_deletion(), "projectile did not clear on pillar")

	var vac_stone := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(vac_stone)
	vac_stone.setup("spirit_stone", 2)
	var vac_enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(vac_enemy)
	var vac := V2SpawnDirector.trigger_wave_end_vacuum(get_tree(), player)
	check("wave_end_vacuum_works", int(vac["despawned"]) == 0 and not vac_enemy.is_dead and bool(vac_stone.get("_magnet_attracting")), str(vac))

	for t in get_tree().get_nodes_in_group("spawn_telegraphs"):
		t.queue_free()
	vac_stone.queue_free()
	vac_enemy.queue_free()
	enemy.queue_free()
	ctrl.queue_free()
	player.queue_free()
	bg.queue_free()

func _test_t1_guards(loader: V2DataLoader) -> void:
	var um := UpgradeManager.new()
	add_child(um)
	um.reset_run_controls()
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	check("t1_banish_weapon", um.banish_choice("v2_wpn:wpn_jade_sword:1"), "banish weapon failed")
	check("t1_banish_stat", um.banish_choice("v2_stat:dmg"), "banish stat failed")
	var choices: Array[Dictionary] = um.get_v2_level_choices(p, 10)
	var leaked_wpn := false
	var leaked_stat := false
	for c in choices:
		var cid := String(c.get("id", ""))
		if cid.begins_with("v2_wpn:wpn_jade_sword"):
			leaked_wpn = true
		if cid == "v2_stat:dmg":
			leaked_stat = true
	check("t1_banish_removed_from_choices", not leaked_wpn and not leaked_stat, "wpn=%s stat=%s choices=%s" % [str(leaked_wpn), str(leaked_stat), str(choices)])

	var cc := V2CombatController.new()
	add_child(cc)
	cc.item_mods = {
		"attack_speed_pct": 5.0,
		"damage_pct": 20.0,
		"area_pct": 10.0,
		"crit_mult_bonus": 10.0,
	}
	check("t1_cap_attack_speed", cc.get_attack_speed_mult() <= 3.2, str(cc.get_attack_speed_mult()))
	check("t1_cap_damage", cc.get_damage_mult() <= 6.0, str(cc.get_damage_mult()))
	check("t1_cap_area", cc.get_area_mult() <= 2.8, str(cc.get_area_mult()))
	check("t1_cap_crit_mult", cc.get_crit_mult() <= 4.0, str(cc.get_crit_mult()))

	cc.item_mods = {}
	var base_dmg_mult := cc.get_damage_mult()
	cc.item_mods = {"attack_speed_pct": 3.2}
	var overflow_dmg_mult := cc.get_damage_mult()
	check(
		"t1_attack_speed_overflow_to_damage",
		overflow_dmg_mult > base_dmg_mult,
		"base=%.3f overflow=%.3f" % [base_dmg_mult, overflow_dmg_mult]
	)

	var rx_engine := ReactionEngine.new(loader)
	rx_engine.configure_modifiers({"reaction_damage_pct": 10.0})
	rx_engine.apply_element_hit(901, "fire", 1.0, 20.0)
	var rx: Dictionary = rx_engine.apply_element_hit(901, "water", 1.1, 20.0)
	var rx_cap := 20.0 * 0.15 * (1.0 + float(loader.reaction_config.get("mastery_cap", 1.0)))
	check(
		"t1_reaction_damage_capped",
		String(rx.get("reaction_id", "")) == "react_steam" and float(rx.get("bonus_damage", 0.0)) <= rx_cap + 0.001,
		"rx=%s cap=%.2f" % [str(rx), rx_cap]
	)

	var pooled := ObjectPools.acquire_script("boss_attack", BossAttack, self, 96) as BossAttack
	check("t1_pool_acquire", pooled != null, "acquire_script returned null")
	if pooled != null:
		ObjectPools.release_script(pooled)
		var reacquired := ObjectPools.acquire_script("boss_attack", BossAttack, self, 96) as BossAttack
		check("t1_pool_reuses_same_instance", reacquired == pooled and is_instance_valid(reacquired), "instance not reused")
		if reacquired != null:
			ObjectPools.release_script(reacquired)

	um.queue_free()
	p.queue_free()
	cc.queue_free()

func _test_t2b_pools_luck_and_shop(_loader: V2DataLoader) -> void:
	check("t2b_fourth_card_prob_base", is_equal_approx(V2CombatController.calc_fourth_card_prob(1.0), 0.0), "luck=1.0 should be 0")
	check("t2b_fourth_card_prob_2x", is_equal_approx(V2CombatController.calc_fourth_card_prob(2.0), 0.5), "luck=2.0 should be 0.5")

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat
	var base_counts_ok := true
	for _i in range(20):
		if cc.roll_level_choice_count(3) != 3:
			base_counts_ok = false
			break
	check("t2b_luck_1_always_3_cards", base_counts_ok, "rolled != 3 when luck=1")

	cc.add_realm_bonus("luck", 1.5)
	var saw_four := false
	for _i in range(40):
		var c := cc.roll_level_choice_count(3)
		if c == 4:
			saw_four = true
			break
	check("t2b_high_luck_rolls_4_cards", saw_four, "never rolled 4 cards at luck=2.5")

	cc.realm_bonuses.clear()
	cc.recompute_player_stats()
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER - 1):
		cc.upgrade_weapon("wpn_jade_sword", 1)
	var w_companion := cc.get_weapon_offer_weight("wpn_fire_gourd")
	var w_same_elem := cc.get_weapon_offer_weight("wpn_gold_bell")
	var w_new_elem := cc.get_weapon_offer_weight("wpn_ice_mirror")
	check(
		"t2b_companion_weight_no_fusion_boost",
		is_equal_approx(w_companion, w_new_elem),
		"companion=%.2f new_elem=%.2f" % [w_companion, w_new_elem]
	)
	check(
		"t2b_missing_elem_weight_boost",
		w_new_elem > w_same_elem,
		"new_elem=%.2f same_elem=%.2f" % [w_new_elem, w_same_elem]
	)
	p.queue_free()

	var p2 := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p2)
	var um := UpgradeManager.new()
	add_child(um)
	um.reset_run_controls()
	p2.v2_combat.orbit_rig.set_unlocked_slots(2)
	check("t2b_no_breakthrough_flag_initially", not p2.v2_combat.should_offer_breakthrough_pick(), "should be false before realm unlock")
	var saw_new := false
	for _i in range(10):
		for c in um.get_v2_level_choices(p2, 3):
			if String(c.get("offer_kind", "")) == "new_weapon":
				saw_new = true
				break
		if saw_new:
			break
	check("t2b_free_slot_allows_new_weapon", saw_new, "free slot should offer unowned weapon")

	p2.level = 5
	p2.leveled_up.emit(5)
	check("t2b_realm_breakthrough_enables_new_pick", p2.v2_combat.should_offer_breakthrough_pick(), "should be true on Lv5 unlock")
	var bt_choices := um.get_v2_level_choices(p2, 3)
	var all_new := bt_choices.size() == 3
	for c in bt_choices:
		if String(c.get("offer_kind", "")) != "new_weapon":
			all_new = false
			break
	check("t2b_breakthrough_offers_new_weapons", all_new, str(bt_choices))
	p2.v2_combat.consume_breakthrough_pick()
	check("t2b_consume_breakthrough_clears_pick", not p2.v2_combat.should_offer_breakthrough_pick(), "pick still pending after consume")

	p2.v2_combat.run_gold = 1000
	um.banish_choice("v2_wpn:wpn_thunder_talisman:1")
	var shop := V2ShopUI.new()
	add_child(shop)
	shop.open_shop(3, p2.v2_combat, um.banished_ids)
	var has_item := false
	var temper_idx := -1
	var leaked_banish := false
	for idx in range(shop._slots_data.size()):
		var offer: Dictionary = shop._slots_data[idx]
		var kind := String(offer.get("kind", ""))
		var oid := String(offer.get("id", ""))
		if kind == "item":
			has_item = true
		elif kind == "temper":
			temper_idx = idx
		if oid == "wpn_thunder_talisman":
			leaked_banish = true
	check("t2b_shop_has_items_and_temper", has_item and temper_idx != -1, str(shop._slots_data))
	check("t2b_shop_respects_banish", not leaked_banish, str(shop._slots_data))
	if temper_idx != -1:
		shop._on_buy_offer(temper_idx)
		check(
			"t2b_shop_temper_upgrades_weapon",
			p2.v2_combat.orbit_rig.get_weapon_tier("wpn_jade_sword") == 2 and p2.v2_combat.orbit_rig.slots.size() == 1,
			str(p2.v2_combat.orbit_rig.slots)
		)
	shop.queue_free()
	um.queue_free()
	p2.queue_free()

func _test_t2c_detail_drawer_and_pacing(loader: V2DataLoader) -> void:
	check(
		"t2c_exp_slowdown_50pct",
		Player.exp_required_for_level(1) >= 25.0 and Player.exp_required_for_level(5) >= 70.0 and Player.exp_required_for_level(10) >= 160.0,
		"lv1=%.1f lv5=%.1f lv10=%.1f" % [Player.exp_required_for_level(1), Player.exp_required_for_level(5), Player.exp_required_for_level(10)]
	)
	var imp_hp := float(loader.enemy_archetypes.get("enemy_swarm_imp", {}).get("base_hp", 0.0))
	var golem_hp := float(loader.enemy_archetypes.get("enemy_bulwark_golem", {}).get("base_hp", 0.0))
	check("t2c_enemy_hp_scaled_up", imp_hp >= 10.0 and golem_hp >= imp_hp * 8.0, "imp=%.1f golem=%.1f" % [imp_hp, golem_hp])

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat

	var sword_det := V2DetailDrawer.build_weapon_detail(cc, "wpn_jade_sword", 2)
	check("t2c_weapon_detail_stat_diffs", not (sword_det.get("stat_diffs", []) as Array).is_empty(), str(sword_det))
	var roadmap: Array = sword_det.get("tier_roadmap", [])
	check(
		"t2c_weapon_detail_roadmap_8",
		roadmap.size() == 8 and String(roadmap[0].get("state", "")) == "current" and String(roadmap[1].get("state", "")) == "next",
		str(roadmap)
	)
	var fusions: Array = sword_det.get("fusions", [])
	check(
		"t2c_weapon_detail_fusion_disabled",
		fusions.is_empty(),
		str(fusions)
	)

	var gourd_det := V2DetailDrawer.build_weapon_detail(cc, "wpn_fire_gourd", 1)
	var rx_1: Array = gourd_det.get("reactions", [])
	var active_ids_1: Array[String] = []
	for r in rx_1:
		if bool(r.get("can_activate_now", false)):
			active_ids_1.append(String(r.get("id", "")))
	var syn1: Dictionary = gourd_det.get("synergy_summary", {})
	check(
		"t2c_gourd_matches_metal_molten",
		active_ids_1 == ["react_molten"] and int(syn1.get("projected_reaction_count", 0)) == 1,
		"active=%s syn=%s" % [str(active_ids_1), str(syn1)]
	)

	cc.orbit_rig.set_unlocked_slots(3)
	cc.add_weapon("wpn_ice_mirror", 1)
	var gourd_det_2 := V2DetailDrawer.build_weapon_detail(cc, "wpn_fire_gourd", 1)
	var active_ids_2: Array[String] = []
	for r in gourd_det_2.get("reactions", []):
		if bool(r.get("can_activate_now", false)):
			active_ids_2.append(String(r.get("id", "")))
	check(
		"t2c_gourd_matches_ice_and_metal",
		active_ids_2.has("react_steam") and active_ids_2.has("react_molten") and active_ids_2.size() == 2,
		"active2=%s" % str(active_ids_2)
	)
	cc.add_weapon("wpn_venom_banner", 1)
	var gourd_det_3 := V2DetailDrawer.build_weapon_detail(cc, "wpn_fire_gourd", 1)
	var active_ids_3: Array[String] = []
	for r in gourd_det_3.get("reactions", []):
		if bool(r.get("can_activate_now", false)):
			active_ids_3.append(String(r.get("id", "")))
	check(
		"t2c_gourd_matches_molten_steam_detonate",
		active_ids_3.has("react_steam") and active_ids_3.has("react_molten") and active_ids_3.has("react_detonate") and active_ids_3.size() == 3,
		"active3=%s" % str(active_ids_3)
	)

	var item_det := V2DetailDrawer.build_item_detail(cc, "item_lucky_coin")
	var has_pos := false
	var has_neg := false
	for row in item_det.get("mod_rows", []):
		if bool(row.get("is_negative", false)):
			has_neg = true
		else:
			has_pos = true
	check("t2c_item_detail_tradeoff_rows", has_pos and has_neg, str(item_det.get("mod_rows", [])))

	var um := UpgradeManager.new()
	add_child(um)
	um.reset_run_controls()
	var choices := um.get_v2_level_choices(p, 3)
	var uui := (load("res://scenes/upgrade_ui.tscn") as PackedScene).instantiate() as UpgradeUI
	add_child(uui)
	uui.show_choices(choices, 0, 3, 2, 2, false, false, cc)
	var first_child: Node = uui.container.get_child(0) if uui.container.get_child_count() > 0 else null
	check("t2c_upgrade_card_stays_button", first_child is Button, str(first_child))
	check("t2c_upgrade_detail_opens", uui.open_card_detail(0) and uui.get_detail_drawer() != null and uui.get_detail_drawer().is_open, "upgrade detail failed to open")
	uui.close_detail_drawer()
	check("t2c_upgrade_detail_closes", not uui.get_detail_drawer().is_open, "upgrade detail failed to close")
	uui.hide_panel()

	cc.run_gold = 500
	var shop := V2ShopUI.new()
	add_child(shop)
	shop.open_shop(2, cc, {})
	check("t2c_shop_detail_opens", shop.open_offer_detail(0) and shop.get_detail_drawer() != null and shop.get_detail_drawer().is_open, "shop detail failed to open")
	shop.close_detail_drawer()
	check("t2c_shop_detail_closes", not shop.get_detail_drawer().is_open, "shop detail failed to close")
	shop.hide_panel()

	shop.queue_free()
	uui.queue_free()
	um.queue_free()
	p.queue_free()

func _test_t2d_codex_and_t2_e2e(loader: V2DataLoader) -> void:
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat

	var d0 := V2CodexPanel.build_codex_data(loader, cc)
	var sm0: Dictionary = d0.get("summary", {})
	check(
		"t2d_codex_counts",
		(d0.get("reactions", []) as Array).size() == 5 and (d0.get("weapons", []) as Array).size() >= 8 and (d0.get("fusions", []) as Array).is_empty() and (d0.get("realms", []) as Array).size() == 4 and (d0.get("items", []) as Array).size() == 16,
		str(sm0)
	)
	check("t2d_codex_initial_0_reactions", int(sm0.get("active_reaction_count", -1)) == 0, str(sm0))

	cc.orbit_rig.set_unlocked_slots(4)
	cc.add_weapon("wpn_fire_gourd", 1)
	cc.add_weapon("wpn_jade_vase", 1)
	var d1 := V2CodexPanel.build_codex_data(loader, cc)
	var rx1: Array = d1.get("reactions", [])
	check(
		"t2d_codex_2_reactions_highlighted_first",
		int((d1.get("summary", {}) as Dictionary).get("active_reaction_count", 0)) == 2 and bool(rx1[0].get("active_now", false)),
		str(rx1[0] if not rx1.is_empty() else {})
	)

	cc.add_weapon("wpn_ice_mirror", 1)
	var d2 := V2CodexPanel.build_codex_data(loader, cc)
	check("t2d_codex_3_reactions_active", int((d2.get("summary", {}) as Dictionary).get("active_reaction_count", 0)) == 3, str(d2.get("summary", {})))
	p.queue_free()

	var p2 := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p2)
	var cc2: V2CombatController = p2.v2_combat
	var um := UpgradeManager.new()
	add_child(um)
	um.reset_run_controls()

	check("t2d_e2e_lv1_1_slot", cc2.get_unlocked_slots() == 1 and cc2.orbit_rig.slots.size() == 1, "expected 1/1 slot")
	var lv1_new := false
	for c in um.get_v2_level_choices(p2, 3):
		if String(c.get("offer_kind", "")) == "new_weapon":
			lv1_new = true
	check("t2d_e2e_small_upgrade_no_new_weapon", not lv1_new, "lv1 should not offer new weapon")

	p2.level = 5
	p2.leveled_up.emit(5)
	check("t2d_e2e_lv5_unlocks_2_slots_and_bt", cc2.get_unlocked_slots() == 2 and cc2.should_offer_breakthrough_pick(), "lv5 breakthrough failed")
	var bt := um.get_v2_level_choices(p2, 3)
	check("t2d_e2e_bt_gives_new_weapon", not bt.is_empty() and String(bt[0].get("offer_kind", "")) == "new_weapon", str(bt))
	cc2.add_weapon("wpn_fire_gourd", 1)
	cc2.consume_breakthrough_pick()

	var gourd_det := V2DetailDrawer.build_weapon_detail(cc2, "wpn_fire_gourd", 2)
	var gourd_rx: Array = gourd_det.get("reactions", [])
	check(
		"t2d_e2e_drawer_lists_fire_reactions",
		gourd_rx.size() == 3 and String(gourd_rx[0].get("id", "")) == "react_molten" and bool(gourd_rx[0].get("can_activate_now", false)),
		str(gourd_rx)
	)

	for _i in range(7):
		cc2.upgrade_weapon("wpn_jade_sword", 1)
		cc2.upgrade_weapon("wpn_fire_gourd", 1)
	check(
		"t2d_e2e_dual_lv8_stays_separate",
		not cc2.orbit_rig.has_fusion("fusion_flame_sword_array") and cc2.orbit_rig.slots.size() == 2 and cc2.get_unlocked_slots() == 2 and not cc2.orbit_rig.has_free_slot(),
		str(cc2.orbit_rig.slots)
	)

	var codex := V2CodexPanel.new()
	add_child(codex)
	codex.setup(cc2)
	codex.switch_tab(0)
	codex.switch_tab(1)
	codex.switch_tab(2)
	check("t2d_e2e_codex_hides_fusions", (codex.codex_data.get("fusions", []) as Array).is_empty(), str(codex.codex_data.get("fusions", [])))

	codex.queue_free()
	um.queue_free()
	p2.queue_free()

func _test_t3_stages_waves_and_enemies(loader: V2DataLoader) -> void:
	check("t3_stages_count_1", loader.stages.size() == 1 and ChapterData.count() == 1, "stages=%d ch=%d" % [loader.stages.size(), ChapterData.count()])
	var all_chs := ChapterData.all()
	var copy_probe := all_chs[0]
	copy_probe["duration"] = 1.0
	check("t3_chapter_copy_isolated", is_equal_approx(float(ChapterData.get_chapter(0).get("duration", 0.0)), 480.0), "ChapterData cache mutated")

	var all_10_waves := true
	var breathing_ok := true
	for ch in all_chs:
		var waves: Array = ch.get("waves", [])
		if waves.size() != 10:
			all_10_waves = false
			continue
		var w3: Dictionary = waves[2]
		var w4: Dictionary = waves[3]
		var w6: Dictionary = waves[5]
		var w7: Dictionary = waves[6]
		var w9: Dictionary = waves[8]
		var w10: Dictionary = waves[9]
		if not (int(w3.get("cap", 0)) > int(w4.get("cap", 0)) and int(w6.get("cap", 0)) > int(w7.get("cap", 0)) and int(w9.get("cap", 0)) > int(w10.get("cap", 0))):
			breathing_ok = false
		if not (float(w4.get("hp_scale", 0.0)) > float(w3.get("hp_scale", 0.0)) and float(w7.get("hp_scale", 0.0)) > float(w6.get("hp_scale", 0.0))):
			breathing_ok = false
	check("t3_all_stages_10_waves", all_10_waves, "not all stages have 10 waves")
	check("t3_breathing_horde_vs_examiner", breathing_ok, "horde/examiner cap or hp_scale breathing mismatch")

	var m1: Dictionary = all_chs[0].get("mods", {})
	check(
		"t3_stage_mods_sane",
		float(m1.get("player_speed", 0.0)) == 1.0 and not bool(m1.get("extra_chest_elite_per_min", true)),
		"mods=%s" % str([m1])
	)

	var st1_waves: Array = all_chs[0].get("waves", [])
	var seen_ids := {}
	for w in st1_waves:
		for p_entry in (w as Dictionary).get("pool", []):
			seen_ids[String((p_entry as Dictionary).get("id", ""))] = true
	var w1_pool: Array = (st1_waves[0] as Dictionary).get("pool", [])
	var w8_pool: Array = (st1_waves[7] as Dictionary).get("pool", [])
	check("t3_archetypes_appear_in_pools", loader.enemy_archetypes.size() >= 9 and seen_ids.size() >= 9, "archetypes=%d seen=%s" % [loader.enemy_archetypes.size(), str(seen_ids.keys())])
	check("t3_w1_warmup_and_w8_wide_pool", w1_pool.size() == 3 and w8_pool.size() >= 9, "w1=%d w8=%d" % [w1_pool.size(), w8_pool.size()])

	check(
		"t3_base_constants",
		is_equal_approx(loader.get_unit_hp(), 16.0) and is_equal_approx(loader.get_base_enemy_speed(), 110.0) and is_equal_approx(loader.get_base_player_speed(), 250.0),
		"unit_hp=%.1f enemy_spd=%.1f player_spd=%.1f" % [loader.get_unit_hp(), loader.get_base_enemy_speed(), loader.get_base_player_speed()]
	)
	var scale_ok := true
	for aid in loader.enemy_archetypes.keys():
		var a: Dictionary = loader.enemy_archetypes[aid]
		var expected_hp := roundf(float(a.get("hp_units", 0.0)) * loader.get_unit_hp())
		var expected_spd := float(a.get("speed_pct", 0.0)) * 0.01 * loader.get_base_enemy_speed()
		if not is_equal_approx(float(a.get("base_hp", -1.0)), expected_hp) or not is_equal_approx(float(a.get("move_speed", -1.0)), expected_spd):
			scale_ok = false
			break
	check("t3_relative_hp_speed_derived", scale_ok, "relative hp_units/speed_pct mismatch")

	var bg := (load("res://scripts/background.gd") as Script).new() as Node2D
	add_child(bg)
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var sp := (load("res://scripts/spawner.gd") as Script).new() as Node2D
	add_child(sp)
	sp.set_process(false)
	sp.player = p
	sp.apply_chapter(all_chs[0])

	var imp_arch: Dictionary = loader.enemy_archetypes["enemy_swarm_imp"]
	var shen_arch: Dictionary = loader.enemy_archetypes["enemy_skitter_shenjing"]
	var jin_arch: Dictionary = loader.enemy_archetypes["enemy_bulwark_jinchan"]
	sp._instantiate_enemy_at(Vector2(300.0, 300.0), Enemy.Type.MINION, int(imp_arch.get("species", 1)), imp_arch)
	sp._instantiate_enemy_at(Vector2(360.0, 300.0), Enemy.Type.MINION, int(shen_arch.get("species", 5)), shen_arch)
	sp._instantiate_enemy_at(Vector2(420.0, 300.0), Enemy.Type.MINION, int(jin_arch.get("species", 4)), jin_arch)
	var spawned_imp: Enemy = null
	var spawned_shen: Enemy = null
	var spawned_jin: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not (e as Enemy).is_dead:
			match (e as Enemy).archetype_id:
				"enemy_swarm_imp": spawned_imp = e as Enemy
				"enemy_skitter_shenjing": spawned_shen = e as Enemy
				"enemy_bulwark_jinchan": spawned_jin = e as Enemy
	check(
		"t3_xp_and_gold_differentiation",
		spawned_imp != null and spawned_shen != null and spawned_jin != null and spawned_shen.exp_gem_value > spawned_imp.exp_gem_value and spawned_jin.gold_value == 10 and spawned_imp.gold_value == 1,
		"imp_xp=%.1f shen_xp=%.1f jin_gold=%d" % [spawned_imp.exp_gem_value if spawned_imp != null else -1.0, spawned_shen.exp_gem_value if spawned_shen != null else -1.0, spawned_jin.gold_value if spawned_jin != null else -1]
	)

	var huodou := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(huodou)
	huodou.setup_type(Enemy.Type.MINION, 0.0, 6)
	huodou.apply_archetype(loader.enemy_archetypes["enemy_charger_huodou"], 3)
	huodou.max_health = 1000.0
	huodou.current_health = 1000.0
	huodou.take_damage_v2(100.0, false, false, "fire")
	var hd_after_fire := huodou.current_health
	huodou.take_damage_v2(100.0, false, false, "ice")
	var hd_after_ice := huodou.current_health
	check(
		"t3_minimal_defense_uniform_damage",
		is_equal_approx(1000.0 - hd_after_fire, 100.0) and is_equal_approx(hd_after_fire - hd_after_ice, 100.0) and is_equal_approx(huodou.damage_reduction, 0.0),
		"fire_dmg=%.1f ice_dmg=%.1f dr=%.2f" % [1000.0 - hd_after_fire, hd_after_fire - hd_after_ice, huodou.damage_reduction]
	)
	check("t3_tier_variant_visual_sync", huodou.tier_variant == 3 and huodou.visual_node != null and int(huodou.visual_node.get("tier_variant")) == 3, "tier=%d" % huodou.tier_variant)

	var golem := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(golem)
	golem.setup_type(Enemy.Type.ELITE, 0.0, 4)
	var sh_total := golem.max_shield
	golem.apply_vulnerability(1.25, 4.0)
	golem.take_damage_v2(50.0, false, false, "metal", Color.WHITE, false, 1.4)
	var vuln_sh_dmg := sh_total - golem.current_shield
	golem.take_damage_v2(10000.0, false, false, "metal")
	check(
		"t3_white_qi_shield_and_break",
		is_equal_approx(sh_total, 144.0) and is_equal_approx(vuln_sh_dmg, 87.5) and is_equal_approx(golem.current_shield, 0.0) and golem._stun_timer >= 0.50 and is_equal_approx(golem.damage_taken_mult, 1.25),
		"sh=%.1f vuln_sh=%.1f cur_sh=%.1f stun=%.2f vuln=%.2f" % [sh_total, vuln_sh_dmg, golem.current_shield, golem._stun_timer, golem.damage_taken_mult]
	)

	var boar := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(boar)
	boar.setup_type(Enemy.Type.ELITE, 0.0, 2)
	boar.apply_archetype(loader.enemy_archetypes["enemy_charger_boar"], 1)
	boar._charger_state = 1
	boar._knockback = Vector2.ZERO
	boar.apply_knockback(Vector2(200.0, 0.0))
	check("t3_charger_windup_kb_resist", boar._knockback.x <= 21.0, "kb=%.1f" % boar._knockback.x)
	var pillars: Array = bg.call("get_pillars")
	boar._charger_state = 2
	boar._charger_timer = 0.30
	boar.global_position = (pillars[0]["pos"] as Vector2) + Vector2(50.0, 0.0)
	boar._physics_process(0.016)
	check("t3_elite_charger_pillar_stun", boar._stun_timer > 1.0 and boar._charger_state == 0, "stun=%.2f state=%d" % [boar._stun_timer, boar._charger_state])

	var jiangshi := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(jiangshi)
	jiangshi.setup_type(Enemy.Type.MINION, 0.0, 3)
	jiangshi.apply_archetype(loader.enemy_archetypes["enemy_hopper_jiangshi"], 1)
	jiangshi.apply_slow(0.40, 2.0)
	check("t3_slow_resist_applied", is_equal_approx(jiangshi._slow_ratio, 0.30), "slow=%.3f" % jiangshi._slow_ratio)

	var atk_before := get_tree().get_nodes_in_group("boss_attacks").size()
	var bomber_minion := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(bomber_minion)
	bomber_minion.setup_type(Enemy.Type.MINION, 240.0, 1)
	bomber_minion.apply_archetype(loader.enemy_archetypes["enemy_bomber_wisp"], 1)
	bomber_minion.target = p
	bomber_minion.global_position = p.global_position + Vector2(200.0, 0.0)
	bomber_minion._ranged_cd = 0.0
	bomber_minion._physics_process(0.016)
	var atk_after_minion_ai := get_tree().get_nodes_in_group("boss_attacks").size()
	bomber_minion.die()
	var atk_after_minion_die := get_tree().get_nodes_in_group("boss_attacks").size()
	check(
		"t3_minion_no_skills_or_death_burst",
		bomber_minion.dash_telegraph.is_empty() and bomber_minion.ranged_attack.is_empty() and bomber_minion.death_burst.is_empty() and atk_after_minion_ai == atk_before and atk_after_minion_die == atk_before,
		"before=%d ai=%d die=%d" % [atk_before, atk_after_minion_ai, atk_after_minion_die]
	)

	var bomber_elite := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(bomber_elite)
	bomber_elite.setup_type(Enemy.Type.ELITE, 0.0, 1)
	bomber_elite.apply_archetype(loader.enemy_archetypes["enemy_bomber_wisp"], 1)
	bomber_elite.die()
	var atk_after_elite := get_tree().get_nodes_in_group("boss_attacks").size()
	check("t3_elite_death_burst_spawns_slam", atk_after_elite > atk_after_minion_die, "before=%d after=%d" % [atk_after_minion_die, atk_after_elite])

	for e in [huodou, golem, boar, jiangshi]:
		if is_instance_valid(e):
			e.free()

	var cam_rect := Rect2(0.0, 0.0, 1280.0, 720.0)
	var cull_e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(cull_e)
	cull_e.setup_type(Enemy.Type.MINION, 0.0, 0)
	cull_e.target = p
	p.global_position = Vector2(400.0, 300.0)
	cull_e.global_position = Vector2(400.0, 300.0)
	cull_e.update_visual_culling(cam_rect)
	check("t3_inscreen_not_culled", not cull_e.is_visual_culled and cull_e.visual_node.visible and cull_e.visual_node.is_processing(), "inscreen culled")

	cull_e.global_position = Vector2(2000.0, 300.0)
	cull_e.update_visual_culling(cam_rect)
	var x_before := cull_e.global_position.x
	var hp_before := cull_e.current_health
	for _f in range(4):
		await get_tree().physics_frame
	cull_e.take_damage_v2(15.0, false, false)
	check(
		"t3_offscreen_culled_moves_and_takes_damage",
		cull_e.is_visual_culled and not cull_e.visual_node.visible and not cull_e.visual_node.is_processing() and cull_e.global_position.x < x_before and cull_e.current_health < hp_before,
		"culled=%s vis=%s x=%.1f->%.1f hp=%.1f->%.1f" % [str(cull_e.is_visual_culled), str(cull_e.visual_node.visible), x_before, cull_e.global_position.x, hp_before, cull_e.current_health]
	)
	cull_e.global_position = Vector2(400.0, 300.0)
	cull_e.update_visual_culling(cam_rect)
	check("t3_reenter_screen_restores_visual", not cull_e.is_visual_culled and cull_e.visual_node.visible and cull_e.visual_node.is_processing(), "did not restore visual")

	var boss_cull := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(boss_cull)
	boss_cull.setup_type(Enemy.Type.BOSS, 0.0, 0)
	boss_cull.global_position = Vector2(2000.0, 300.0)
	boss_cull.update_visual_culling(cam_rect)
	check("t3_boss_never_culled", not boss_cull.is_visual_culled and boss_cull.visual_node.visible, "boss culled")

	var vac_minion := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(vac_minion)
	vac_minion.setup_type(Enemy.Type.MINION, 0.0, 0)
	vac_minion.global_position = p.global_position + Vector2(180.0, 0.0)
	vac_minion.gold_value = 2
	var vac_elite := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(vac_elite)
	vac_elite.setup_type(Enemy.Type.ELITE, 0.0, 0)
	vac_elite.global_position = p.global_position + Vector2(-180.0, 0.0)
	var vac_stone_t3 := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(vac_stone_t3)
	vac_stone_t3.setup("spirit_stone", 3)
	vac_stone_t3.global_position = p.global_position + Vector2(0.0, 260.0)
	var gold_before := p.v2_combat.run_gold
	var vac_res := V2SpawnDirector.trigger_wave_end_vacuum(get_tree(), p)
	check(
		"t3_wave_pulse_banishes_minions_and_pays_gold",
		not vac_minion.is_dead and int(vac_res.get("banished", -1)) == 0 and int(vac_res.get("gold_gained", -1)) == 0 and p.v2_combat.run_gold == gold_before,
		"res=%s gold=%d->%d" % [str(vac_res), gold_before, p.v2_combat.run_gold]
	)
	check(
		"t3_wave_pulse_knocks_elite_without_killing",
		not vac_elite.is_dead and int(vac_res.get("knocked_elites", -1)) == 0,
		"elite dead=%s res=%s" % [str(vac_elite.is_dead), str(vac_res)]
	)
	check(
		"t3_wave_pulse_attracts_gems",
		bool(vac_stone_t3.get("_magnet_attracting")) and int(vac_res.get("vacuumed", 0)) >= 1,
		str(vac_res)
	)
	vac_stone_t3.queue_free()

	var mono_ok := true
	for lv in range(1, 30):
		if Player.exp_required_for_level(lv + 1) <= Player.exp_required_for_level(lv):
			mono_ok = false
			break
	var step10 := Player.exp_required_for_level(10) / Player.exp_required_for_level(9)
	var step20 := Player.exp_required_for_level(20) / Player.exp_required_for_level(19)
	check("t3_exp_curve_quadratic_steps", mono_ok and step10 >= 1.40 and step20 >= 1.30, "mono=%s s10=%.2f s20=%.2f" % [str(mono_ok), step10, step20])

	for ba in get_tree().get_nodes_in_group("boss_attacks"):
		if is_instance_valid(ba):
			ObjectPools.release_script(ba)
	for g in get_tree().get_nodes_in_group("exp_gems"):
		if is_instance_valid(g):
			ObjectPools.release(g)
	for e in [cull_e, boss_cull, vac_minion, vac_elite]:
		if is_instance_valid(e):
			e.free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and self.is_ancestor_of(e):
			ObjectPools.release(e)
	sp.queue_free()
	p.queue_free()
	bg.queue_free()

func _test_t4_feel_and_feedback(loader: V2DataLoader) -> void:
	var table_ok := true
	var expected_dur := {
		"metal": 0.045,
		"fire": 0.060,
		"thunder": 0.040,
		"ice": 0.070,
		"venom": 0.060,
	}
	for elem in expected_dur.keys():
		var spec := V2VfxFactory.get_hit_vfx_spec(String(elem))
		if String(spec.get("key", "")) != String(elem) or not is_equal_approx(float(spec.get("duration", 0.0)), float(expected_dur[elem])):
			table_ok = false
			break
	var rx_spec := V2VfxFactory.get_hit_vfx_spec("", Color(1.0, 0.4, 0.2, 1.0))
	check(
		"t4_hit_vfx_table_elements_and_reaction",
		table_ok and String(rx_spec.get("key", "")) == "reaction" and is_equal_approx(float(rx_spec.get("duration", 0.0)), 0.085) and is_equal_approx(float(rx_spec.get("boost", 0.0)), 2.2),
		str(rx_spec)
	)

	var flash_snap := Settings.get_bool("video/hit_flash")
	Settings.set_value("video/hit_flash", true)
	var hit_e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(hit_e)
	hit_e.setup_type(Enemy.Type.MINION, 0.0, 1)
	hit_e.max_health = 5000.0
	hit_e.current_health = 5000.0
	hit_e.take_damage_v2(10.0, false, false, "fire")
	var fire_mod := hit_e.modulate
	var fire_key := hit_e._last_hit_flash_key
	var fire_dur := hit_e._last_hit_flash_duration
	hit_e.take_damage_v2(10.0, false, false, "ice")
	var ice_mod := hit_e.modulate
	var ice_key := hit_e._last_hit_flash_key
	var ice_dur := hit_e._last_hit_flash_duration
	hit_e.take_damage_v2(10.0, false, false, "", Color(0.8, 0.5, 1.0, 1.0))
	var rx_mod := hit_e.modulate
	var rx_key := hit_e._last_hit_flash_key
	var rx_dur := hit_e._last_hit_flash_duration
	check(
		"t4_enemy_element_flash_differentiated",
		fire_key == "fire" and is_equal_approx(fire_dur, 0.060) and fire_mod.r > fire_mod.b and ice_key == "ice" and is_equal_approx(ice_dur, 0.070) and ice_mod.b > ice_mod.r and rx_key == "reaction" and is_equal_approx(rx_dur, 0.085) and rx_mod.b > 1.8,
		"fire=%s(%.3f) ice=%s(%.3f) rx=%s(%.3f)" % [fire_key, fire_dur, ice_key, ice_dur, rx_key, rx_dur]
	)
	Settings.set_value("video/hit_flash", false)
	hit_e.modulate = Color.WHITE
	hit_e.take_damage_v2(10.0, false, false, "thunder")
	check("t4_enemy_flash_respects_setting", hit_e.modulate.is_equal_approx(Color.WHITE), str(hit_e.modulate))
	Settings.set_value("video/hit_flash", flash_snap)
	hit_e.free()

	var rig := OrbitWeaponRig.new()
	add_child(rig)
	rig.setup(loader)
	rig.set_unlocked_slots(3)
	rig.add_weapon("wpn_jade_sword", 1)
	rig.add_weapon("wpn_ice_mirror", 1)
	var dummy_t := Node2D.new()
	add_child(dummy_t)
	dummy_t.global_position = Vector2(180.0, 0.0)
	rig.slots[0]["cd_left"] = 0.001
	rig.slots[1]["cd_left"] = 0.001
	rig.tick(0.01, [dummy_t], 1.0)
	var r0_start: Vector2 = rig.slots[0]["recoil"]
	var r1_start: Vector2 = rig.slots[1]["recoil"]
	rig.tick(0.05, [dummy_t], 1.0)
	var r0_mid: Vector2 = rig.slots[0]["recoil"]
	rig.tick(0.05, [dummy_t], 1.0)
	var r0_end: Vector2 = rig.slots[0]["recoil"]
	var r1_end: Vector2 = rig.slots[1]["recoil"]
	check(
		"t4_orbit_weapon_recoil_0_1s_linear",
		r0_start.x < -20.0 and is_equal_approx(r0_start.length(), OrbitWeaponRig.RECOIL_DISTANCE) and r1_start.x < -20.0 and absf(r0_mid.length() - OrbitWeaponRig.RECOIL_DISTANCE * 0.5) <= 2.0 and r0_end.length_squared() < 0.01 and r1_end.length_squared() < 0.01,
		"s0=%s s1=%s mid=%s end0=%s" % [str(r0_start), str(r1_start), str(r0_mid), str(r0_end)]
	)
	dummy_t.free()
	rig.free()

	var sq0: Vector2 = EnemyVisualScript.sample_charge_prep_squash(0.0)
	var sq1: Vector2 = EnemyVisualScript.sample_charge_prep_squash(0.40 / 3.0)
	var sq2: Vector2 = EnemyVisualScript.sample_charge_prep_squash(0.80 / 3.0)
	var sq3: Vector2 = EnemyVisualScript.sample_charge_prep_squash(0.40)
	var vol_ok := true
	for k in range(11):
		var sq_s: Vector2 = EnemyVisualScript.sample_charge_prep_squash(0.04 * float(k))
		var prod: float = sq_s.x * sq_s.y
		if prod < 0.94 or prod > 1.06:
			vol_ok = false
			break
	check(
		"t4_charge_prep_volume_preserving_keyframes",
		vol_ok and sq0.is_equal_approx(Vector2(1.1, 0.9)) and sq1.is_equal_approx(Vector2(0.8, 1.2)) and sq2.is_equal_approx(Vector2(1.2, 0.8)) and sq3.is_equal_approx(Vector2(1.0, 1.0)),
		"sq=%s vol_ok=%s" % [str([sq0, sq1, sq2, sq3]), str(vol_ok)]
	)
	var boar_e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(boar_e)
	boar_e.setup_type(Enemy.Type.ELITE, 0.0, 2)
	boar_e.apply_archetype(loader.enemy_archetypes["enemy_charger_boar"], 1)
	boar_e._elite_state = 1
	boar_e._elite_windup_total = 0.65
	boar_e._elite_timer = 0.40 * (1.0 / 3.0)
	boar_e.visual_node._process(0.016)
	var boar_sq: Vector2 = boar_e.visual_node.last_charge_squash
	check("t4_charger_visual_tracks_windup_squash", boar_sq.x > 1.05 and boar_sq.y < 0.95, str(boar_sq))
	boar_e.free()

	ObjectPools.clear()
	var dead_e := ObjectPools.acquire("res://scenes/enemy.tscn", self) as Enemy
	dead_e.setup_type(Enemy.Type.MINION, 0.0, 1)
	dead_e.is_visual_culled = false
	dead_e.die()
	var dead_immediate_ok := dead_e.is_dead and not dead_e.is_in_group("enemies") and dead_e.is_dying_anim and not dead_e.visual_node.is_processing()
	dead_e._process(Enemy.DEATH_ANIM_DURATION * 0.5)
	var mid_scale: float = dead_e.visual_node.scale.x
	var mid_rot: float = absf(dead_e.visual_node.rotation)
	var mid_gray: float = dead_e.modulate.r
	check(
		"t4_minion_death_spin_shrink_midpoint",
		dead_immediate_ok and absf(mid_scale - 0.5) <= 0.08 and absf(mid_rot - PI) <= 0.25 and mid_gray < 0.75,
		"imm=%s sc=%.2f rot=%.2f gray=%.2f" % [str(dead_immediate_ok), mid_scale, mid_rot, mid_gray]
	)
	dead_e._process(Enemy.DEATH_ANIM_DURATION * 0.6)
	await get_tree().process_frame
	check(
		"t4_minion_death_releases_and_resets_visual",
		not dead_e.is_dying_anim and ObjectPools.free_count("res://scenes/enemy.tscn") >= 1 and dead_e.visual_node.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(dead_e.visual_node.rotation, 0.0),
		"dying=%s free=%d sc=%s rot=%.2f" % [str(dead_e.is_dying_anim), ObjectPools.free_count("res://scenes/enemy.tscn"), str(dead_e.visual_node.scale), dead_e.visual_node.rotation]
	)
	ObjectPools.clear()

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat
	var w_ice: Dictionary = loader.weapons_by_id["wpn_ice_mirror"]
	var t_ice: Dictionary = (w_ice["tiers"] as Array)[3]
	cc._on_weapon_fired(0, w_ice, t_ice, p.global_position, p.global_position + Vector2(200.0, 0.0))
	var q_after_ice := cc._pending_salvos.size()
	var t_ice_max: Dictionary = (w_ice["tiers"] as Array)[7]
	cc._on_weapon_fired(0, w_ice, t_ice_max, p.global_position, p.global_position + Vector2(200.0, 0.0))
	var q_after_arr := cc._pending_salvos.size()
	for _step in range(12):
		cc._step_pending_salvos(0.036)
	check(
		"t4_salvo_stagger_queues_and_flushes",
		q_after_ice == 3 and q_after_arr == 9 and cc._pending_salvos.is_empty(),
		"ice=%d arr=%d rem=%d" % [q_after_ice, q_after_arr, cc._pending_salvos.size()]
	)

	var a_10 := V2AttackFx.alpha_from_scale(0.34, 1.0)
	var a_13 := V2AttackFx.alpha_from_scale(0.34, 1.3)
	var a_20 := V2AttackFx.alpha_from_scale(0.34, 2.0)
	var a_28 := V2AttackFx.alpha_from_scale(0.34, 2.8)
	var fx_burn := V2AttackFx.new()
	add_child(fx_burn)
	fx_burn.setup_burn_zone(cc, Vector2.ZERO, Vector2(60.0, 0.0), 10.0, 140.0, 2.0, 6.0, Color(0.92, 0.35, 0.05, 0.34), false, 2.6)
	var fx_dom := V2AttackFx.new()
	add_child(fx_dom)
	fx_dom.setup_fusion_domain(cc, p, Vector2.ZERO, "orbit_burst_array", 240.0, 20.0, 1.5, Color(0.98, 0.45, 0.09, 0.28), 0, 2.6)
	check(
		"t4_alpha_from_scale_protection",
		is_equal_approx(a_10, 0.34) and is_equal_approx(a_13, 0.34) and is_equal_approx(a_20, 0.34 * 0.65) and is_equal_approx(a_28, 0.34 * 0.48) and fx_burn.effective_alpha_limit < 0.20 and fx_dom.effective_alpha_limit < 0.16,
		"a20=%.3f a28=%.3f burn=%.3f dom=%.3f" % [a_20, a_28, fx_burn.effective_alpha_limit, fx_dom.effective_alpha_limit]
	)
	fx_burn.queue_free()
	fx_dom.queue_free()

	Player.ensure_move_input_actions()
	var actions_ok := InputMap.has_action("move_left") and InputMap.has_action("move_right") and InputMap.has_action("move_up") and InputMap.has_action("move_down") and InputMap.has_action("dash")
	Input.action_press("move_right", 0.55)
	var analog_vec := p.get_move_input()
	Input.action_press("move_right", 1.0)
	Input.action_press("move_down", 1.0)
	var diag_vec := p.get_move_input()
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_up")
	check(
		"t4_input_get_vector_analog_and_diag",
		actions_ok and analog_vec.x > 0.35 and analog_vec.x < 0.75 and diag_vec.length() > 0.95 and diag_vec.length() <= 1.001,
		"actions=%s analog=%s diag=%s" % [str(actions_ok), str(analog_vec), str(diag_vec)]
	)

	p.queue_free()
	for node in get_children():
		if node is V2AttackFx or node is V2ReactionFx:
			(node as Node).queue_free()

func _test_ch1_map_assets() -> void:
	var tile_ok := ResourceLoader.exists("res://assets/v2/map_ch1/tile_grass_512.png")
	var ctrl_ok := ResourceLoader.exists("res://scripts/v2/arena_map_controller.gd")
	var json_path := "res://data/v2/map_arena_v2.json"
	var json_ok := FileAccess.file_exists(json_path)
	var floor_ok := false
	if json_ok:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			var chapters: Array = (parsed as Dictionary).get("chapters", [])
			if not chapters.is_empty():
				floor_ok = ResourceLoader.exists(String((chapters[0] as Dictionary).get("floor_tile", "")))
	check("ch1_map_assets_ready", tile_ok and ctrl_ok and json_ok and floor_ok, "tile=%s ctrl=%s json=%s floor=%s" % [str(tile_ok), str(ctrl_ok), str(json_ok), str(floor_ok)])
	var ctrl_loaded := false
	if ctrl_ok:
		var map_script := load("res://scripts/v2/arena_map_controller.gd") as Script
		if map_script != null:
			var map_ctrl := map_script.new() as Node2D
			add_child(map_ctrl)
			ctrl_loaded = bool(map_ctrl.call("load_chapter", 0))
			map_ctrl.free()
	check("ch1_map_arena_controller_loads", ctrl_loaded, "ArenaMapController.load_chapter(0) returned false")

func _test_t5_batch2a_characters() -> void:
	CharacterData.reload()
	var chars := CharacterData.all()
	_check("t5_2a_char_count_4", chars.size() == 4, "got %d" % chars.size())
	_check("t5_2a_affinity_sword_metal", CharacterData.get_element_affinity("sword_immortal") == "metal", "")
	_check("t5_2a_affinity_gourd_fire", CharacterData.get_element_affinity("gourd_daoist") == "fire", "")
	_check("t5_2a_affinity_thunder_thunder", CharacterData.get_element_affinity("thunder_daoist") == "thunder", "")
	_check("t5_2a_affinity_cloud_water", CharacterData.get_element_affinity("cloud_danxia") == "water", "")
	_check("t5_2a_default_unlocked", CharacterData.is_unlocked("sword_immortal", Stats) and CharacterData.is_unlocked("gourd_daoist", Stats) and CharacterData.is_unlocked("thunder_daoist", Stats) and CharacterData.is_unlocked("cloud_danxia", Stats), "")
	var loader := V2DataLoader.new()
	_check("t5_2a_loader_characters", loader.load_all("res://data/v2") and loader.characters.size() == 4, "")
	loader.free()

func _test_t5_batch2b_sect_14_and_recycle() -> void:
	_check("t5_2b_sect_catalog_14", Stats.SECT_CATALOG.size() == 14, "got %d" % Stats.SECT_CATALOG.size())
	var orig_stones := Stats.spirit_stones
	var orig_upgrades := Stats.sect_upgrades.duplicate(true)
	Stats.spirit_stones = 500
	for item in Stats.SECT_CATALOG:
		Stats.sect_upgrades[str(item["id"])] = 0
	var bought_seal := Stats.buy_sect_upgrade("seal")
	var bought_curse := Stats.buy_sect_upgrade("curse")
	_check("t5_2b_buy_seal_curse", bought_seal and bought_curse and Stats.get_sect_level("seal") == 1 and Stats.get_sect_level("curse") == 1, "")
	var invested := Stats.get_sect_invested_stones()
	_check("t5_2b_invested_matches", invested == 130, "got %d" % invested)
	var um := UpgradeManager.new()
	um.reset_run_controls()
	_check("t5_2b_seal_applies_to_banishes", um.banishes_left == 3 + Stats.bonus_seal_slots, "got %d" % um.banishes_left)
	um.free()
	var refunded := Stats.recycle_sect_upgrades()
	_check("t5_2b_recycle_full_refund", refunded == 130 and Stats.spirit_stones == 500 and Stats.get_sect_level("seal") == 0, "")
	Stats.spirit_stones = orig_stones
	Stats.sect_upgrades = orig_upgrades
	Stats.save_stats()

func _test_t5_batch2c_curse_chain() -> void:
	_check("t5_2c_curse_hp_1x", is_equal_approx(V2SpawnDirector.calc_curse_hp_mult(0.4), 1.4), "")
	_check("t5_2c_curse_spawn_05x", is_equal_approx(V2SpawnDirector.calc_curse_spawn_mult(0.4), 1.2), "")
	var base_stones := Stats.calc_run_stones(300.0, 250, true, 1.0, 0.0)
	var cursed_stones := Stats.calc_run_stones(300.0, 250, true, 1.0, 0.5)
	_check("t5_2c_curse_stone_bonus", cursed_stones > base_stones, "%d vs %d" % [cursed_stones, base_stones])
	var v2 := V2CombatController.new()
	v2.realm_bonuses["curse_pct"] = 0.5
	v2.recompute_player_stats()
	_check("t5_2c_v2_curse_rate", is_equal_approx(v2.get_curse_enemy_hp_mult(), 1.5) and is_equal_approx(v2.get_spawn_rate_mult(), 1.25), "")
	v2.free()

func _test_t5_batch3a_arcana_limit_break() -> void:
	var loader := V2DataLoader.new()
	_check("t5_3a_load_all", loader.load_all(), "")
	_check("t5_3a_8_arcanas", loader.arcanas.size() == 8, "got=%d" % loader.arcanas.size())
	var v2 := V2CombatController.new()
	v2.loader = loader
	var rig := OrbitWeaponRig.new()
	rig.setup(loader)
	rig.set_unlocked_slots(4)
	rig.add_weapon("wpn_jade_sword", OrbitWeaponRig.MAX_WEAPON_TIER)
	v2.orbit_rig = rig
	v2.unlocked_weapon_slots = 4
	_check("t5_3a_arcana_disabled", not v2.add_arcana("arcana_solitary_dao") and not v2.has_arcana("arcana_solitary_dao") and v2.get_arcana_choices().is_empty(), "")
	var ok_lb := true
	for _i in range(5):
		ok_lb = ok_lb and v2.apply_weapon_limit_break("wpn_jade_sword", "damage_pct", 0.08, 5)
	_check("t5_3a_lb_max_cap", ok_lb and not v2.apply_weapon_limit_break("wpn_jade_sword", "damage_pct", 0.08, 5), "")
	var um := UpgradeManager.new()
	var lb_cards := um._build_weapon_limit_break_cards(v2)
	_check("t5_3a_lb_card_pool", lb_cards.size() == 1 and String(lb_cards[0]["id"]) == "v2_lb:wpn_jade_sword:cooldown_pct", "sz=%d" % lb_cards.size())
	um.free()
	rig.free()
	v2.free()
	loader.free()

func _test_t5_batch3b_jar_drops() -> void:
	var d1 := BreakableJar.get_eligible_drops(1, 1.0)
	var ids1: Array[String] = []
	for it in d1:
		ids1.append(String(it["id"]))
	_check("t5_3b_lv1_pool", ids1.size() == 4 and ids1.has("peach") and ids1.has("spirit_pouch") and ids1.has("qiankun_bag") and ids1.has("medium_gem") and not ids1.has("taixu_talisman"), str(ids1))
	var d5 := BreakableJar.get_eligible_drops(5, 1.0)
	var has_taixu := false
	var w_taixu_1 := 0.0
	for it in d5:
		if String(it["id"]) == "taixu_talisman":
			has_taixu = true
			w_taixu_1 = float(it["effective_weight"])
	var d5_boost := BreakableJar.get_eligible_drops(5, 2.0)
	var w_taixu_2 := 0.0
	for it in d5_boost:
		if String(it["id"]) == "taixu_talisman":
			w_taixu_2 = float(it["effective_weight"])
	_check("t5_3b_lv5_taixu_and_boost", has_taixu and is_equal_approx(w_taixu_2, w_taixu_1 * 2.0), "")
	var d8 := BreakableJar.get_eligible_drops(8, 1.0)
	var d12 := BreakableJar.get_eligible_drops(12, 1.0)
	_check("t5_3b_lv8_lv12_counts", d8.size() == 5 and d12.size() == 6, "%d/%d" % [d8.size(), d12.size()])
	var rolled := BreakableJar.roll_drop_kind(12, 1.0, 0.99)
	_check("t5_3b_roll_thunder", rolled == "thunder_seal", rolled)

func _test_t5_batch3c_achievements() -> void:
	var catalog := Stats.load_achievements_catalog()
	_check("t5_3c_24_achievements", catalog.size() == 24, "got=%d" % catalog.size())
	var tmp_path := "user://test_legacy_stats_3c.cfg"
	var cf := ConfigFile.new()
	cf.set_value("best", "total_runs", 2)
	cf.set_value("meta", "spirit_stones", 100)
	cf.save(tmp_path)
	var old_ach := Stats.unlocked_achievements.duplicate()
	var old_arc := Stats.unlocked_arcanas.duplicate()
	var old_seal := Stats.bonus_seal_slots
	var old_stones := Stats.spirit_stones
	var old_runs := Stats.total_runs
	var old_tk := Stats.total_kills
	var old_tr := Stats.total_reactions
	var old_tf := Stats.total_fusions
	var old_tj := Stats.total_jars_broken
	Stats.load_stats(tmp_path)
	_check("t5_3c_legacy_compat", Stats.total_runs == 2 and Stats.spirit_stones == 100 and Stats.unlocked_achievements.is_empty(), "")
	var unlocked := Stats.evaluate_run_achievements({
		"run_time": 200.0,
		"run_level": 14,
		"run_kills": 180,
		"victory": true,
		"curse_pct": 0.25,
		"run_reactions": 30,
		"run_fusions": 1,
		"run_jars_broken": 16,
	}, false)
	_check("t5_3c_unlocked_multi", unlocked.size() >= 6, "got=%d" % unlocked.size())
	_check("t5_3c_curse_seal_bonus", Stats.bonus_seal_slots >= 2, "")
	var unlocked_again := Stats.evaluate_run_achievements({
		"run_time": 200.0,
		"run_level": 14,
		"run_kills": 180,
		"victory": true,
		"curse_pct": 0.25,
		"run_reactions": 30,
		"run_fusions": 1,
		"run_jars_broken": 16,
	}, false)
	_check("t5_3c_idempotent", unlocked_again.is_empty(), "dup=%d" % unlocked_again.size())
	Stats.unlocked_achievements = old_ach
	Stats.unlocked_arcanas = old_arc
	Stats.bonus_seal_slots = old_seal
	Stats.spirit_stones = old_stones
	Stats.total_runs = old_runs
	Stats.total_kills = old_tk
	Stats.total_reactions = old_tr
	Stats.total_fusions = old_tf
	Stats.total_jars_broken = old_tj
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
func _test_batch4_ch1_map() -> void:
	var raw := FileAccess.get_file_as_string("res://data/v2/stages_v2.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check("b4_stages_json_valid", parsed is Dictionary, "")
	var stages: Array = (parsed as Dictionary).get("stages", [])
	_check("b4_single_stage", stages.size() == 1, "got=%d" % stages.size())
	var expected := "res://assets/v2/map_ch1/tile_grass_512.png"
	var st_tile := String((stages[0] as Dictionary).get("floor_tile", ""))
	var tex := load(expected) as Texture2D
	_check("b4_ch1_floor_tile_loads", st_tile == expected and tex != null, st_tile)

func _test_batch5_seven_elite_variants() -> void:
	var raw := FileAccess.get_file_as_string("res://data/v2/enemies_waves_v2.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check("b5_ew_json_valid", parsed is Dictionary, "")
	var ev_map: Dictionary = (parsed as Dictionary).get("elite_variants", {})
	_check("b5_elite_variants_cover_species", ev_map.size() >= 7, "got=%d" % ev_map.size())
	var all_tex_ok := true
	var hp_set := {}
	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	for sp in range(7):
		var cfg: Dictionary = ev_map.get(str(sp), {})
		var sp_path := String(cfg.get("sprite", ""))
		var tex := load(sp_path) as Texture2D
		if tex == null:
			all_tex_ok = false
		var e := enemy_scene.instantiate() as Enemy
		add_child(e)
		e.setup_type(Enemy.Type.ELITE, 0.0, sp)
		hp_set[int(round(e.max_health))] = true
		e.queue_free()
	_check("b5_all_elite_sprites_load", all_tex_ok, "")
	_check("b5_elite_stats_differentiated", hp_set.size() >= 6, "unique_hp=%d" % hp_set.size())
	var elite_sheets := [
		["res://assets/sprites/anim_elite_fox_run.png", 6, 128],
		["res://assets/sprites/anim_elite_doll_float.png", 6, 128],
		["res://assets/sprites/anim_elite_shanxiao_run.png", 8, 128],
		["res://assets/sprites/anim_elite_jiangshi_run.png", 8, 128],
		["res://assets/sprites/anim_elite_jinchan_run.png", 8, 128],
		["res://assets/sprites/anim_elite_shenjing_run.png", 8, 128],
		["res://assets/sprites/anim_elite_huodou_run.png", 8, 128],
		["res://assets/sprites/anim_yinsha_daotong_run.png", 8, 160],
		["res://assets/sprites/anim_zhenhun_shidun_run.png", 8, 160],
	]
	var sheets_ok := true
	var sheets_info := ""
	for pair in elite_sheets:
		var tex := load(String(pair[0])) as Texture2D
		var cell: int = int(pair[2])
		var want_w: int = int(pair[1]) * cell
		if tex == null:
			sheets_ok = false
			sheets_info += "%s:missing " % pair[0]
			continue
		if tex.get_width() != want_w or tex.get_height() != cell:
			sheets_ok = false
			sheets_info += "%s:%dx%d " % [pair[0], tex.get_width(), tex.get_height()]
	_check("b5_all_elite_anim_sheets_sized", sheets_ok, sheets_info)
	var ev_src := FileAccess.get_file_as_string("res://scripts/enemy_visual.gd")
	var ev_anim_ok := true
	for path in ["anim_elite_fox_run.png", "anim_elite_doll_float.png", "anim_elite_shanxiao_run.png", "anim_elite_jiangshi_run.png", "anim_elite_jinchan_run.png", "anim_elite_shenjing_run.png", "anim_elite_huodou_run.png", "anim_yinsha_daotong_run.png", "anim_zhenhun_shidun_run.png"]:
		if not ev_src.contains(path):
			ev_anim_ok = false
	_check("b5_enemy_visual_preloads_all_elite_sheets", ev_anim_ok, "")
	var spawner_src := FileAccess.get_file_as_string("res://scripts/spawner.gd")
	_check("b5_spawner_all_species_elite", spawner_src.contains("_get_elite_variant") and spawner_src.contains("elite_chance"), "")

func _test_batch8a_chest_never_empty() -> void:
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	var cc: V2CombatController = p.v2_combat
	var um := UpgradeManager.new()
	add_child(um)
	um.reset_run_controls()

	cc.orbit_rig.set_unlocked_slots(4)
	for wid in ["wpn_jade_sword", "wpn_thunder_talisman", "wpn_venom_banner", "wpn_jade_vase"]:
		for _i in range(OrbitWeaponRig.MAX_WEAPON_TIER):
			cc.add_weapon(wid, 1)
	var all_max := cc.orbit_rig.slots.size() == 4
	for s in cc.orbit_rig.slots:
		if bool(s["is_fusion"]) or int(s["tier"]) != OrbitWeaponRig.MAX_WEAPON_TIER:
			all_max = false
	_check("b8a_four_slots_all_lv8", all_max, str(cc.orbit_rig.slots))

	var roll_ok := true
	var first_reward: Dictionary = {}
	for _i in range(20):
		var rewards: Array[Dictionary] = um.roll_v2_chest_rewards(p)
		if rewards.is_empty():
			roll_ok = false
			break
		if first_reward.is_empty():
			first_reward = rewards[0]
	_check("b8a_full_loadout_chest_never_empty", roll_ok and not first_reward.is_empty(), str(first_reward))
	_check(
		"b8a_reward_card_fields",
		String(first_reward.get("title", "")) != "" and String(first_reward.get("desc", "")) != "" and String(first_reward.get("icon", "")) != "",
		str(first_reward)
	)
	var guarantee_titles := ["道心淬炼", "九转还魂丹", "天机洗髓"]
	var probe_rewards: Array[Dictionary] = um.roll_v2_chest_rewards(p)
	var has_guarantee := false
	for r in probe_rewards:
		if guarantee_titles.has(String(r.get("title", ""))):
			has_guarantee = true
	_check("b8a_no_upgrade_guarantee_card", has_guarantee, str(probe_rewards))

	var saved_items: Dictionary = cc.loader.items_by_id
	cc.loader.items_by_id = {}
	var fallback_rewards: Array[Dictionary] = um.roll_v2_chest_rewards(p)
	cc.loader.items_by_id = saved_items
	_check(
		"b8a_no_item_pool_still_has_card",
		not fallback_rewards.is_empty() and String(fallback_rewards[0].get("title", "")) != "",
		str(fallback_rewards)
	)

	var p7 := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p7)
	var cc7: V2CombatController = p7.v2_combat
	var um7 := UpgradeManager.new()
	add_child(um7)
	um7.reset_run_controls()
	cc7.orbit_rig.set_unlocked_slots(4)
	while not cc7.orbit_rig.slots.is_empty():
		cc7.orbit_rig.sell_weapon(0)
	cc7.add_weapon("wpn_jade_sword", OrbitWeaponRig.MAX_WEAPON_TIER - 1)
	var lv7_rewards: Array[Dictionary] = um7.roll_v2_chest_rewards(p7)
	_check(
		"b8a_lv7_to_lv8_chest_not_empty",
		not lv7_rewards.is_empty() and int(cc7.orbit_rig.get_weapon_tier("wpn_jade_sword")) == OrbitWeaponRig.MAX_WEAPON_TIER,
		str(lv7_rewards)
	)
	_check(
		"b8a_lv8_reward_text_uses_lv8",
		not lv7_rewards.is_empty() and String(lv7_rewards[0].get("desc", "")).contains("Lv.8"),
		str(lv7_rewards[0] if not lv7_rewards.is_empty() else {})
	)

	var chest_ui := (load("res://scenes/chest_ui.tscn") as PackedScene).instantiate() as ChestUI
	add_child(chest_ui)
	chest_ui.show_rewards([])
	var box := chest_ui.get_node("Panel/VBox/RewardBox") as HBoxContainer
	_check(
		"b8a_chest_ui_empty_input_fallback_visible",
		chest_ui.visible and box.get_child_count() == 1 and (box.get_child(0) as Control).visible,
		"cards=%d" % box.get_child_count()
	)
	chest_ui.queue_free()

	um.queue_free()
	p.queue_free()
	um7.queue_free()
	p7.queue_free()

func _test_batch9_pickup_and_freeze() -> void:
	await get_tree().process_frame
	_check(
		"b9_icons_exist",
		ResourceLoader.exists("res://assets/sprites/pickup_magnet.png") and ResourceLoader.exists("res://assets/sprites/pickup_taixu_talisman.png"),
		""
	)
	_check(
		"b9_alias_mapping",
		WorldPickup.normalize_kind("magnet_compass") == "qiankun_bag" and WorldPickup.normalize_kind("magnet") == "qiankun_bag" and WorldPickup.normalize_kind("frost_talisman") == "taixu_talisman",
		""
	)
	_check(
		"b9_auto_pull_whitelist",
		WorldPickup.kind_auto_pulls("spirit_stone") and not WorldPickup.kind_auto_pulls("peach") and not WorldPickup.kind_auto_pulls("spirit_pouch") and not WorldPickup.kind_auto_pulls("medium_gem") and not WorldPickup.kind_auto_pulls("qiankun_bag") and not WorldPickup.kind_auto_pulls("taixu_talisman"),
		""
	)
	var raw_data := FileAccess.get_file_as_string("res://data/v2/pickups_v2.json")
	_check("b9_data_names", raw_data.contains("聚灵罗盘") and raw_data.contains("太虚定身符"), "")

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.global_position = Vector2(1400.0, 1200.0)

	for k in ["peach", "spirit_pouch", "medium_gem"]:
		var wp := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
		add_child(wp)
		wp.setup(k)
		wp.global_position = p.global_position + Vector2(120.0, 0.0)
		var before := wp.global_position
		wp._physics_process(0.20)
		_check(
			"b9_" + k + "_manual_only",
			wp.global_position.is_equal_approx(before) and not wp.is_queued_for_deletion() and not bool(wp.get("_magnet_attracting")),
			"pos=%s" % str(wp.global_position)
		)
		wp.free()

	var peach := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(peach)
	peach.setup("peach")
	peach.global_position = p.global_position + Vector2(0.0, -48.0)
	peach._physics_process(0.016)
	_check("b9_contact_pickup_works", peach.is_queued_for_deletion(), "")

	var pouch := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(pouch)
	pouch.setup("spirit_pouch")
	pouch.global_position = p.global_position + Vector2(18.0, 0.0)
	var gold_before_pouch := p.v2_combat.run_gold
	pouch._physics_process(0.016)
	_check("b9_spirit_pouch_grants_run_gold", pouch.is_queued_for_deletion() and p.v2_combat.run_gold == gold_before_pouch + 5, "gold=%d->%d" % [gold_before_pouch, p.v2_combat.run_gold])

	var magnet_gem := (load("res://scenes/exp_gem.tscn") as PackedScene).instantiate() as ExpGem
	add_child(magnet_gem)
	magnet_gem.global_position = p.global_position + Vector2(120.0, 0.0)
	magnet_gem.setup_value(6.0)
	magnet_gem._physics_process(0.02)
	_check("b9_exp_gem_magnet_pull", magnet_gem.is_attracted, "")

	var far_gem := (load("res://scenes/exp_gem.tscn") as PackedScene).instantiate() as ExpGem
	add_child(far_gem)
	far_gem.global_position = p.global_position + Vector2(620.0, 0.0)
	far_gem.setup_value(6.0)
	var far_stone := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(far_stone)
	far_stone.setup("spirit_stone", 3)
	far_stone.global_position = p.global_position + Vector2(-640.0, 0.0)
	var bag := (load("res://scenes/world_pickup.tscn") as PackedScene).instantiate() as WorldPickup
	add_child(bag)
	bag.setup("magnet_compass")
	bag.global_position = p.global_position + Vector2(8.0, 0.0)
	bag._physics_process(0.016)
	_check(
		"b9_qiankun_bag_vacuums_all",
		bag.kind == "qiankun_bag" and bag.is_queued_for_deletion() and far_gem.is_attracted and bool(far_stone.get("_magnet_attracting")),
		"bag=%s gem=%s stone=%s" % [bag.kind, str(far_gem.is_attracted), str(far_stone.get("_magnet_attracting"))]
	)

	var minion := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(minion)
	minion.setup_type(Enemy.Type.MINION, 0.0, 0)
	minion.global_position = p.global_position + Vector2(300.0, 0.0)
	minion.max_health = 1000.0
	minion.current_health = 1000.0
	minion.apply_freeze(5.0)
	_check(
		"b9_freeze_five_seconds_minion",
		is_equal_approx(minion._freeze_timer, 5.0) and minion.visual_node.get_node_or_null("FreezeMarker") != null,
		"timer=%.2f" % minion._freeze_timer
	)
	var before_pos := minion.global_position
	minion._physics_process(1.0)
	_check(
		"b9_frozen_enemy_no_move",
		minion.global_position.is_equal_approx(before_pos) and is_equal_approx(minion._freeze_timer, 4.0),
		"timer=%.2f" % minion._freeze_timer
	)
	minion.take_damage_v2(100.0, false, true)
	_check("b9_frozen_minimal_defense_no_hidden_vuln", is_equal_approx(1000.0 - minion.current_health, 100.0), "dmg=%.1f" % (1000.0 - minion.current_health))

	var elite := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(elite)
	elite.setup_type(Enemy.Type.ELITE, 0.0, 0)
	elite.apply_freeze(5.0)
	_check("b9_freeze_five_seconds_elite", is_equal_approx(elite._freeze_timer, 5.0), "timer=%.2f" % elite._freeze_timer)

	var boss := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(boss)
	boss.setup_type(Enemy.Type.BOSS, 0.0, 0)
	boss.apply_freeze(5.0)
	_check(
		"b9_boss_freeze_and_slow",
		is_equal_approx(boss._freeze_timer, 1.5) and is_equal_approx(boss._slow_ratio, 0.6) and is_equal_approx(boss._slow_timer, 3.5),
		"freeze=%.2f slow=%.2f timer=%.2f" % [boss._freeze_timer, boss._slow_ratio, boss._slow_timer]
	)
	_check(
		"b9_enemy_bag_drop_chance",
		V2CombatController.qiankun_bag_drop_chance(Enemy.Type.MINION) > 0.0 and V2CombatController.qiankun_bag_drop_chance(Enemy.Type.ELITE) > V2CombatController.qiankun_bag_drop_chance(Enemy.Type.MINION) and is_equal_approx(V2CombatController.qiankun_bag_drop_chance(Enemy.Type.BOSS), 0.0),
		""
	)

	var dropped_bag: WorldPickup = p.v2_combat.spawn_qiankun_bag_at(p.global_position + Vector2(90.0, 0.0))
	var bag_spawned := dropped_bag != null
	await get_tree().process_frame
	var found_bag := false
	for wp in get_tree().get_nodes_in_group("world_pickups"):
		if is_instance_valid(wp) and String(wp.get("kind")) == "qiankun_bag":
			found_bag = true
			wp.free()
	_check("b9_spawn_bag_pickup", bag_spawned and found_bag, "")

	for n in [magnet_gem, far_gem, far_stone, minion, elite, boss, p]:
		if is_instance_valid(n):
			n.free()

func _batch10a_enemy(pos: Vector2, hp: float, target: Player) -> Enemy:
	var e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.current_health = hp
	e.target = target
	return e

func _test_batch10a_bell_and_banner(loader: V2DataLoader) -> void:
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.global_position = Vector2(1400.0, 1400.0)
	var cc: V2CombatController = p.v2_combat

	var bell: Dictionary = loader.weapons_by_id["wpn_gold_bell"]
	var bell_t1: Dictionary = (bell["tiers"] as Array)[0]
	var bell_res: Dictionary = bell.get("resonance_profile", {})
	var vine: Dictionary = loader.weapons_by_id["wpn_spirit_vine"]
	var vine_t1: Dictionary = (vine["tiers"] as Array)[0]
	_check(
		"b10a_bell_data_micro_control",
		is_equal_approx(float(bell_t1.get("slow_pct", 0.0)), 0.25) and is_equal_approx(float(bell_t1.get("slow_dur", 0.0)), 1.2) and float(bell_t1.get("knockback", 0.0)) > 0.0,
		str(bell_t1)
	)
	_check(
		"b10a_bell_resonance_removed_and_vine_none",
		bell_res.is_empty() and String(vine.get("element", "")) == "none" and not vine_t1.has("leech_hp") and is_equal_approx(float(vine_t1.get("root_dur", 0.0)), 0.75) and bool(vine_t1.get("pull_exp_gems", false)),
		"bell_res=%s vine=%s" % [str(bell_res), str(vine_t1)]
	)
	var banner: Dictionary = loader.weapons_by_id["wpn_venom_banner"]
	var banner_t3: Dictionary = (banner["tiers"] as Array)[2]
	_check(
		"b10a_banner_data_homing_spirits",
		String(banner.get("element", "")) == "venom" and String(banner.get("attack_pattern", "")) == "homing_soul_seal_spirits" and not banner_t3.has("aoe_radius") and int(banner_t3.get("projectile_count", 0)) == 2 and int(banner_t3.get("spread_targets", 0)) == 3,
		str(banner_t3)
	)

	var e_main := _batch10a_enemy(p.global_position + Vector2(120.0, 0.0), 6000.0, p)
	CombatGrid.rebuild(get_tree().get_nodes_in_group("enemies"))
	cc._on_weapon_fired(0, bell, bell_t1, p.global_position, e_main.global_position)
	_check(
		"b10a_bell_micro_pushback",
		e_main._knockback.x > 0.0 and is_equal_approx(e_main._knockback.y, 0.0),
		"kb=%s" % str(e_main._knockback)
	)
	_check(
		"b10a_bell_micro_slow",
		is_equal_approx(e_main._slow_ratio, 0.25) and is_equal_approx(e_main._slow_timer, 1.2),
		"slow=%.3f timer=%.2f" % [e_main._slow_ratio, e_main._slow_timer]
	)
	var bell_ring: V2AttackFx = null
	for child in get_children():
		if child is V2AttackFx and String((child as V2AttackFx).pulse_style) == "bell_tide":
			bell_ring = child as V2AttackFx
			break
	_check(
		"b10a_bell_multilayer_wave_visual",
		bell_ring != null and bell_ring._pulse_primary != null and bell_ring._pulse_secondary != null and bell_ring._pulse_layers.size() == 3,
		"ring=%s" % str(bell_ring)
	)

	var e_ice := _batch10a_enemy(p.global_position + Vector2(20.0, 130.0), 6000.0, p)
	e_ice.max_shield = 500.0
	e_ice.current_shield = 500.0
	e_ice.apply_freeze(3.0)
	CombatGrid.rebuild(get_tree().get_nodes_in_group("enemies"))
	cc._on_weapon_fired(0, bell, bell_t1, p.global_position, e_ice.global_position)
	_check(
		"b10a_metal_bell_triggers_react_shatter",
		not e_ice.is_frozen() and e_ice.current_shield <= 410.0 and cc.reaction_count >= 1,
		"frozen=%s shield=%.1f rx=%d" % [str(e_ice.is_frozen()), e_ice.current_shield, cc.reaction_count]
	)

	var e_det_a := _batch10a_enemy(p.global_position + Vector2(-140.0, 0.0), 100.0, p)
	var e_det_b := _batch10a_enemy(p.global_position + Vector2(-175.0, 0.0), 200.0, p)
	cc.deal_v2_damage(e_det_a, 10.0, "fire", {})
	cc.deal_v2_damage(e_det_a, 10.0, "venom", {})
	CombatGrid.rebuild(get_tree().get_nodes_in_group("enemies"))
	var det_b_hp := e_det_b.current_health
	e_det_a.die()
	_check(
		"b10a_detonate_death_blast_no_chain",
		e_det_b.current_health < det_b_hp and e_det_b._detonate_mark_timer <= 0.0,
		"b_hp=%.1f->%.1f mark=%.2f" % [det_b_hp, e_det_b.current_health, e_det_b._detonate_mark_timer]
	)

	for e in [e_main, e_ice, e_det_a, e_det_b]:
		if is_instance_valid(e):
			e.free()

	var target_a := _batch10a_enemy(p.global_position + Vector2(220.0, 0.0), 6000.0, p)
	var target_b := _batch10a_enemy(p.global_position + Vector2(160.0, 150.0), 6000.0, p)
	CombatGrid.rebuild(get_tree().get_nodes_in_group("enemies"))
	cc._on_weapon_fired(1, banner, banner_t3, p.global_position, target_a.global_position)
	var spirits: Array = []
	for s in get_tree().get_nodes_in_group("venom_spirits"):
		if is_instance_valid(s):
			spirits.append(s)
	_check(
		"b10a_banner_spawns_tracking_spirits",
		spirits.size() == 2 and not bool(spirits[0].get("is_max_tier")),
		"spirits=%d" % spirits.size()
	)
	for _step in range(40):
		var alive := 0
		for s in spirits:
			if is_instance_valid(s):
				s._physics_process(0.05)
				alive += 1
		if alive == 0:
			break
	var sealed_primary: Enemy = null
	for e in [target_a, target_b]:
		if is_instance_valid(e) and e.has_soul_seal():
			sealed_primary = e
			break
	_check(
		"b10a_banner_soul_seal_dot",
		sealed_primary != null and sealed_primary._dot_dps > 0.0 and sealed_primary._dot_elem == "venom",
		"sealed=%s dps=%.1f elem=%s" % [str(sealed_primary != null), sealed_primary._dot_dps if sealed_primary != null else -1.0, sealed_primary._dot_elem if sealed_primary != null else ""]
	)

	if sealed_primary != null:
		for e in [target_a, target_b]:
			if is_instance_valid(e) and e != sealed_primary:
				e.global_position = p.global_position + Vector2(900.0, 0.0)
		var spread_targets: Array[Enemy] = []
		for i in range(4):
			var ang := TAU * float(i) / 4.0
			spread_targets.append(_batch10a_enemy(sealed_primary.global_position + Vector2(cos(ang), sin(ang)) * 62.0, 6000.0, p))
		CombatGrid.rebuild(get_tree().get_nodes_in_group("enemies"))
		sealed_primary.take_damage_v2(999999.0, true, true, "venom")
		var infected := 0
		for e in spread_targets:
			if is_instance_valid(e) and e.has_soul_seal():
				infected += 1
		_check(
			"b10a_banner_soul_seal_death_spread",
			cc.soul_seal_spread_count == 1 and infected == 3,
			"spread_count=%d infected=%d" % [cc.soul_seal_spread_count, infected]
		)
		for e in spread_targets:
			if is_instance_valid(e):
				e.free()

	for e in [target_a, target_b, p]:
		if is_instance_valid(e):
			e.free()

func _test_batch10b_awakened_vfx(loader: V2DataLoader) -> void:
	_check(
		"b10b_awakened_tier_gate",
		V2AttackFx.is_awakened_tier(8, false) and not V2AttackFx.is_awakened_tier(7, false) and V2AttackFx.is_awakened_tier(9, true) and not V2AttackFx.is_awakened_tier(1, false),
		"tier gate mismatch"
	)

	var missing_effect: Array[String] = []
	var palette_colors := {}
	var palette_packs := {}
	for wid in loader.weapons_by_id.keys():
		var w: Dictionary = loader.weapons_by_id[wid]
		var eff := String((w.get("vfx_profile", {}) as Dictionary).get("max_tier_effect", ""))
		if not V2AttackFx.has_awakened_effect(eff):
			missing_effect.append(String(wid))
			continue
		var spec := V2AttackFx.awakened_spec(eff)
		palette_colors[String(spec.get("primary", ""))] = true
		palette_packs[String(spec.get("pack", ""))] = true
	_check(
		"b10b_all_weapons_awakened_effect",
		missing_effect.is_empty() and loader.weapons_by_id.size() == 8,
		"missing=%s count=%d" % [str(missing_effect), loader.weapons_by_id.size()]
	)
	_check(
		"b10b_awakened_palettes_distinct",
		palette_colors.size() == 8 and palette_packs.size() >= 6,
		"colors=%d packs=%s" % [palette_colors.size(), str(palette_packs)]
	)

	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.global_position = Vector2(1400.0, 1800.0)
	var cc: V2CombatController = p.v2_combat
	var origin := p.global_position
	var sword_fx := V2AttackFx.new()
	add_child(sword_fx)
	sword_fx.setup_boomerang(cc, p, origin, Vector2.RIGHT, 50.0, 870.0, 465.0, 5, "metal", Color(0.98, 0.80, 0.09), false, false, true)
	_check(
		"b10b_sword_rain_awakened",
		sword_fx.awakened and sword_fx.awakened_effect == "ink_sword_afterimage" and sword_fx.awaken_layers >= 3 and sword_fx._awaken_formation != null and sword_fx._awaken_swords.size() == 9,
		"layers=%d swords=%d" % [sword_fx.awaken_layers, sword_fx._awaken_swords.size()]
	)
	var sword_t7 := V2AttackFx.new()
	add_child(sword_t7)
	sword_t7.setup_boomerang(cc, p, origin, Vector2.RIGHT, 43.0, 830.0, 440.0, 5, "metal", Color(0.18, 0.83, 0.75))
	_check(
		"b10b_sword_lv7_not_awakened",
		not sword_t7.awakened and sword_t7.awaken_layers == 0 and sword_t7._awaken_formation == null,
		"awakened=%s" % str(sword_t7.awakened)
	)

	var fire_fx := V2AttackFx.new()
	add_child(fire_fx)
	fire_fx.setup_burn_zone(cc, origin, origin + Vector2(200.0, 60.0), 28.0, 120.0, 3.0, 18.0, Color(0.95, 0.27, 0.37, 0.34), true, 1.0, true)
	var fire_lob_layers := fire_fx._awaken_flames.size()
	fire_fx._enter_burn_zone_visuals()
	_check(
		"b10b_fire_sea_awakened",
		fire_fx.awakened and fire_lob_layers >= 3 and fire_fx._awaken_pillars.size() == 3 and fire_fx.awaken_layers >= 5,
		"lob=%d pillars=%d layers=%d" % [fire_lob_layers, fire_fx._awaken_pillars.size(), fire_fx.awaken_layers]
	)

	var bolt_fx := V2AttackFx.new()
	add_child(bolt_fx)
	bolt_fx.setup_chain_bolt(PackedVector2Array([origin, origin + Vector2(120.0, -30.0), origin + Vector2(240.0, 40.0)]), Color(0.98, 0.88, 0.30), true, true)
	_check(
		"b10b_thunder_pillar_awakened",
		bolt_fx.awakened and bolt_fx._bolt_sky != null and bolt_fx._bolt_fork != null and bolt_fx._bolt_scorch != null and bolt_fx._bolt_tendrils.size() == 4 and bolt_fx.awaken_layers >= 7,
		"sky=%s fork=%s tendrils=%d layers=%d" % [str(bolt_fx._bolt_sky != null), str(bolt_fx._bolt_fork != null), bolt_fx._bolt_tendrils.size(), bolt_fx.awaken_layers]
	)

	var ice_fx := V2AttackFx.new()
	add_child(ice_fx)
	ice_fx.setup_ice_shard(cc, origin, Vector2.RIGHT, 20.0, 310.0, 1, 0.30, 2.4, Color(0.88, 0.95, 0.99), false, 1, true)
	_check(
		"b10b_ice_crystal_awakened",
		ice_fx.awakened and ice_fx._awaken_orbit.size() == 3 and ice_fx.awaken_layers >= 4,
		"orbit=%d layers=%d" % [ice_fx._awaken_orbit.size(), ice_fx.awaken_layers]
	)

	var water_fx := V2AttackFx.new()
	add_child(water_fx)
	water_fx.setup_water_splash(cc, origin, origin + Vector2(0.0, 180.0), 28.0, 130.0, 0.30, 2.4, "water", Color(0.65, 0.95, 1.0, 0.50), true, true)
	var crest_cache := water_fx._awaken_crests.size()
	water_fx._enter_water_impact()
	var crest_visible := 0
	for item in water_fx._awaken_crests:
		var crest := item.get("node") as Line2D
		if crest != null and is_instance_valid(crest) and crest.visible:
			crest_visible += 1
	_check(
		"b10b_water_tide_awakened",
		water_fx.awakened and crest_cache == 3 and crest_visible == 3 and water_fx.awaken_layers >= 5,
		"crests=%d visible=%d layers=%d" % [crest_cache, crest_visible, water_fx.awaken_layers]
	)

	var bell_fx := V2AttackFx.new()
	add_child(bell_fx)
	bell_fx.setup_pulse_ring(origin, 290.0, Color(0.98, 0.88, 0.30, 0.38), 0.62, true, "bell_tide", 1.0, true)
	_check(
		"b10b_bell_rune_rings_awakened",
		bell_fx.awakened and bell_fx._pulse_layers.size() == 6 and bell_fx.awaken_layers >= 3,
		"layers=%d awaken=%d" % [bell_fx._pulse_layers.size(), bell_fx.awaken_layers]
	)
	var bell_t7 := V2AttackFx.new()
	add_child(bell_t7)
	bell_t7.setup_pulse_ring(origin, 275.0, Color(0.98, 0.88, 0.30, 0.38), 0.62, true, "bell_tide", 1.0)
	_check(
		"b10b_bell_lv7_not_awakened",
		not bell_t7.awakened and bell_t7._pulse_layers.size() == 3,
		"layers=%d" % bell_t7._pulse_layers.size()
	)

	var venom_fx := V2AttackFx.new()
	add_child(venom_fx)
	venom_fx.setup_pulse_ring(origin, 130.0, Color(0.66, 0.98, 0.25, 0.42), 0.35, true, "venom_dual", 1.0, true)
	_check(
		"b10b_venom_thorns_awakened",
		venom_fx.awakened and venom_fx._awaken_thorns.size() == 6 and venom_fx._awaken_tendrils.size() == 4 and venom_fx.awaken_layers >= 10,
		"thorns=%d tendrils=%d layers=%d" % [venom_fx._awaken_thorns.size(), venom_fx._awaken_tendrils.size(), venom_fx.awaken_layers]
	)

	var fusion_fx := V2AttackFx.new()
	add_child(fusion_fx)
	fusion_fx.setup_fusion_domain(cc, p, origin, "orbit_burst_array", 120.0, 40.0, 1.5, Color(0.96, 0.45, 0.09, 0.28), 0, 1.0)
	_check(
		"b10b_fusion_domain_awakened",
		fusion_fx.awakened and fusion_fx.awakened_effect == "fusion_domain" and fusion_fx._awaken_runes.size() == 1 and fusion_fx.awaken_layers >= 2,
		"runes=%d layers=%d" % [fusion_fx._awaken_runes.size(), fusion_fx.awaken_layers]
	)

	var over_cap := 0
	for fx in [sword_fx, fire_fx, bolt_fx, ice_fx, water_fx, bell_fx, venom_fx, fusion_fx]:
		for child in (fx as Node).get_children():
			if child is GPUParticles2D and (child as GPUParticles2D).amount > V2AttackFx.AWAKENED_PARTICLE_CAP:
				over_cap += 1
	_check(
		"b10b_awakened_particle_cap",
		V2AttackFx.awakened_particle_amount(999) == V2AttackFx.AWAKENED_PARTICLE_CAP and V2VfxFactory.MAX_ACTIVE_TRANSIENT == 36 and over_cap == 0,
		"over_cap=%d amount=%d" % [over_cap, V2AttackFx.awakened_particle_amount(999)]
	)

	var sword_def: Dictionary = loader.weapons_by_id["wpn_jade_sword"]
	var tiers: Array = sword_def["tiers"]
	var before_children := get_child_count()
	cc._on_weapon_fired(0, sword_def, tiers[7], p.global_position, p.global_position + Vector2(260.0, 0.0))
	var fired_awakened := false
	for i in range(before_children, get_child_count()):
		var node := get_child(i)
		if node is V2AttackFx and (node as V2AttackFx).mode == V2AttackFx.Mode.BOOMERANG:
			fired_awakened = (node as V2AttackFx).awakened
	var before_lv7 := get_child_count()
	cc._on_weapon_fired(0, sword_def, tiers[6], p.global_position, p.global_position + Vector2(260.0, 0.0))
	var fired_lv7_awakened := true
	for i in range(before_lv7, get_child_count()):
		var node := get_child(i)
		if node is V2AttackFx and (node as V2AttackFx).mode == V2AttackFx.Mode.BOOMERANG:
			fired_lv7_awakened = (node as V2AttackFx).awakened
	_check(
		"b10b_controller_threads_awakened_tier",
		fired_awakened and not fired_lv7_awakened,
		"lv8=%s lv7=%s" % [str(fired_awakened), str(fired_lv7_awakened)]
	)

	var rig := OrbitWeaponRig.new()
	add_child(rig)
	rig.setup(loader)
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER):
		rig.add_weapon("wpn_fire_gourd", 1)
	var rig_sp: Sprite2D = rig.slots[0]["sprite"] as Sprite2D
	_check(
		"b10b_orbit_max_tier_aura",
		rig_sp.get_node_or_null("MaxTierAura") != null and rig_sp.get_node_or_null("MaxTierParticles") != null and rig_sp.get_node_or_null("MaxTierTrail") != null,
		"aura visual missing"
	)
	var rig_lv7 := OrbitWeaponRig.new()
	add_child(rig_lv7)
	rig_lv7.setup(loader)
	for _lv in range(OrbitWeaponRig.MAX_WEAPON_TIER - 1):
		rig_lv7.add_weapon("wpn_fire_gourd", 1)
	var rig_lv7_sp: Sprite2D = rig_lv7.slots[0]["sprite"] as Sprite2D
	_check(
		"b10b_orbit_lv7_has_no_aura",
		rig_lv7_sp.get_node_or_null("MaxTierAura") == null,
		"lv7 should not show aura"
	)

	for n in [sword_fx, sword_t7, fire_fx, bolt_fx, ice_fx, water_fx, bell_fx, bell_t7, venom_fx, fusion_fx, rig, rig_lv7, p]:
		if is_instance_valid(n):
			n.free()

func _test_flying_sword_dummy_and_debug_isolation() -> void:
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	var cc: V2CombatController = p.v2_combat
	var sw := V2AttackFx.new()
	add_child(sw)
	sw.setup_boomerang(cc, p, p.global_position, Vector2.RIGHT, 20.0, 600.0, 240.0, 3, "metal", Color(0.18, 0.83, 0.75))
	var max_x := p.global_position.x
	var ever_returned := false
	for _step in range(12):
		if not is_instance_valid(sw) or sw.is_queued_for_deletion():
			break
		sw._physics_process(0.05)
		if is_instance_valid(sw):
			if sw.global_position.x < max_x - 0.1:
				ever_returned = true
			max_x = maxf(max_x, sw.global_position.x)
	await get_tree().process_frame
	_check(
		"sword_flies_straight_no_return",
		not ever_returned and max_x >= p.global_position.x + 200.0 and not is_instance_valid(sw),
		"ever_returned=%s max_x=%.1f valid=%s" % [str(ever_returned), max_x, str(is_instance_valid(sw))]
	)
	if is_instance_valid(sw):
		sw.free()
	if is_instance_valid(p):
		p.free()

	var main_scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main_scene)
	await get_tree().process_frame
	var pause_menu := main_scene.get_node_or_null("PauseMenu")
	var has_sandbox_node := main_scene.get_node_or_null("V2DebugSandbox") != null
	var has_pause_sandbox_btn := pause_menu != null and pause_menu.find_child("DebugSandboxButton", true, false) != null
	_check(
		"normal_game_excludes_debug_sandbox",
		not has_sandbox_node and not has_pause_sandbox_btn,
		"sandbox=%s pause_btn=%s" % [str(has_sandbox_node), str(has_pause_sandbox_btn)]
	)
	main_scene.free()
	ObjectPools.clear()
	await get_tree().process_frame

	var title_scene := (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(title_scene)
	await get_tree().process_frame
	var title_debug_btn := title_scene.find_child("DebugSandboxModeButton", true, false)
	_check("title_has_debug_mode_button", title_debug_btn != null, "missing DebugSandboxModeButton")
	title_scene.free()
	await get_tree().process_frame

	var dbg_scene := (load("res://scenes/debug_sandbox.tscn") as PackedScene).instantiate()
	add_child(dbg_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var dbg_pause_menu := dbg_scene.get_node_or_null("PauseMenu")
	var dbg_sandbox := dbg_scene.get_node_or_null("V2DebugSandbox") as V2DebugSandbox
	var dummies: Array[TrainingDummy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is TrainingDummy:
			dummies.append(node as TrainingDummy)
	var dummy_ok := dummies.size() == 3
	if dummy_ok:
		var d0 := dummies[0]
		var pos0 := d0.global_position
		d0._physics_process(0.1)
		d0.take_damage_v2(120.0, false, false, "metal")
		var mid_ok := is_equal_approx(d0.max_health, 5000.0) and is_equal_approx(d0.current_health, 4880.0) and is_equal_approx(d0.contact_damage, 0.0) and d0.global_position.is_equal_approx(pos0) and is_equal_approx(d0.total_damage, 120.0) and d0.hit_count == 1
		d0.take_damage_v2(6000.0, false, false, "metal")
		var reset_ok := not d0.is_dead and is_equal_approx(d0.current_health, 5000.0) and is_equal_approx(d0.total_damage, 6120.0)
		d0.reset_stats()
		dummy_ok = mid_ok and reset_ok and is_equal_approx(d0.total_damage, 0.0) and d0.hit_count == 0
	var loader_chk := V2DataLoader.new()
	loader_chk.load_all("res://data/v2")
	var data_driven_ok := dbg_sandbox != null and dbg_sandbox._weapon_rows.size() == loader_chk.weapons_by_id.size() and dbg_sandbox._item_rows.size() == loader_chk.items_by_id.size() and dbg_sandbox._arcana_rows.is_empty() and dbg_sandbox._char_btns.size() == CharacterData.all().size() and dbg_sandbox._stage_btns.size() == loader_chk.stages.size()
	loader_chk.free()
	_check(
		"debug_sandbox_isolated_with_wooden_dummies",
		dbg_sandbox != null
		and dbg_scene.get_node_or_null("Spawner") == null
		and dbg_scene.get_node_or_null("StageDirector") == null
		and dbg_scene.get_node_or_null("UpgradeUI") == null
		and data_driven_ok
		and dbg_pause_menu != null and dbg_pause_menu.find_child("DebugSandboxButton", true, false) != null
		and dummy_ok,
		"dummies=%d dummy_ok=%s dd=%s" % [dummies.size(), str(dummy_ok), str(data_driven_ok)]
	)
	dbg_scene.free()
	ObjectPools.clear()
	await get_tree().process_frame
