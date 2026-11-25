extends Node
class_name WeaponManager

signal loadout_changed

const SLASH_SCENE := "res://scenes/sword_slash.tscn"
const SWORD_SCENE := "res://scenes/sword.tscn"
const ORBIT_SCENE := "res://scenes/orbit_sword.tscn"
const THUNDER_SCENE := "res://scenes/thunder.tscn"
const TALISMAN_SCENE := "res://scenes/talisman.tscn"
const AURA_SCENE := "res://scenes/jade_aura.tscn"

var weapons: Dictionary = {}
var passives: Dictionary = {}

var _player: CharacterBody2D = null
var _orbit_swords: Array[Node2D] = []
var _orbit_angle: float = 0.0
var _jade_aura: Node2D = null
var _delayed_slashes: Array[Dictionary] = []

var crit_chance: float = 0.12
var crit_mult: float = 1.65
var cooldown_mult: float = 1.0
var area_mult: float = 1.0
var damage_mult: float = 1.0
var bonus_amount: int = 0
var auto_fire_enabled: bool = true

func bind_player(p: CharacterBody2D, start_weapon: String = "lotus_slash") -> void:
	_player = p
	weapons.clear()
	passives.clear()
	_delayed_slashes.clear()
	_clear_persistent_nodes()
	add_or_upgrade_weapon(start_weapon)
	_recompute_stats()

func _clear_persistent_nodes() -> void:
	for s in _orbit_swords:
		if is_instance_valid(s):
			ObjectPools.release(s)
	_orbit_swords.clear()
	if _jade_aura != null and is_instance_valid(_jade_aura):
		_jade_aura.queue_free()
	_jade_aura = null

func has_weapon(wid: String) -> bool:
	return weapons.has(wid)

func weapon_level(wid: String) -> int:
	if not weapons.has(wid):
		return 0
	return int(weapons[wid]["level"])

func is_weapon_evolved(wid: String) -> bool:
	if not weapons.has(wid):
		return false
	return bool(weapons[wid]["evolved"])

func has_passive(pid: String) -> bool:
	return passives.has(pid)

func passive_level(pid: String) -> int:
	return int(passives.get(pid, 0))

func add_or_upgrade_weapon(wid: String) -> bool:
	var cfg := WeaponCatalog.get_weapon(wid)
	if cfg.is_empty():
		return false
	if weapons.has(wid):
		var cur := int(weapons[wid]["level"])
		if cur >= WeaponCatalog.MAX_WEAPON_LEVEL:
			return false
		weapons[wid]["level"] = cur + 1
	else:
		if weapons.size() >= WeaponCatalog.MAX_WEAPON_SLOTS:
			return false
		weapons[wid] = {"level": 1, "evolved": false, "timer": 0.15}
	_recompute_stats()
	_sync_persistent_weapons()
	emit_signal("loadout_changed")
	return true

func add_or_upgrade_passive(pid: String) -> bool:
	var cfg := WeaponCatalog.get_passive(pid)
	if cfg.is_empty():
		return false
	var max_lv := int(cfg.get("max_level", WeaponCatalog.MAX_PASSIVE_LEVEL))
	var cur := int(passives.get(pid, 0))
	if cur >= max_lv:
		return false
	if cur == 0 and passives.size() >= WeaponCatalog.MAX_PASSIVE_SLOTS:
		return false
	passives[pid] = cur + 1
	_recompute_stats(pid == "spirit_pill")
	_sync_persistent_weapons()
	emit_signal("loadout_changed")
	return true

func evolve_candidates() -> Array[String]:
	var out: Array[String] = []
	for wid in weapons.keys():
		var st: Dictionary = weapons[wid]
		if bool(st["evolved"]):
			continue
		if int(st["level"]) < WeaponCatalog.MAX_WEAPON_LEVEL:
			continue
		var cfg := WeaponCatalog.get_weapon(str(wid))
		var partner := str(cfg.get("partner_passive", ""))
		if partner != "" and passive_level(partner) >= 1:
			out.append(str(wid))
	return out

func evolve_weapon(wid: String) -> bool:
	if not weapons.has(wid):
		return false
	if bool(weapons[wid]["evolved"]):
		return false
	weapons[wid]["evolved"] = true
	weapons[wid]["level"] = WeaponCatalog.MAX_WEAPON_LEVEL
	_recompute_stats()
	_sync_persistent_weapons()
	emit_signal("loadout_changed")
	return true

func get_weapon_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for wid in weapons.keys():
		var cfg := WeaponCatalog.get_weapon(str(wid))
		var st: Dictionary = weapons[wid]
		var evo := bool(st["evolved"])
		var lv := int(st["level"])
		var partner := str(cfg.get("partner_passive", ""))
		var is_maxed := (not evo) and lv >= WeaponCatalog.MAX_WEAPON_LEVEL
		var ready_evo := is_maxed and partner != "" and passive_level(partner) >= 1
		out.append({
			"id": str(wid),
			"name": str(cfg["evo_name"] if evo else cfg["name"]),
			"icon": str(cfg["evo_icon"] if evo else cfg["icon"]),
			"level": lv,
			"evolved": evo,
			"maxed": is_maxed,
			"ready_evo": ready_evo,
		})
	return out

func get_passive_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in passives.keys():
		var cfg := WeaponCatalog.get_passive(str(pid))
		var lv := int(passives[pid])
		var max_lv := int(cfg.get("max_level", WeaponCatalog.MAX_PASSIVE_LEVEL))
		out.append({
			"id": str(pid),
			"name": str(cfg["name"]),
			"icon": str(cfg["icon"]),
			"level": lv,
			"maxed": lv >= max_lv,
		})
	return out

func refresh_stats() -> void:
	_recompute_stats()
	_sync_persistent_weapons()

func _recompute_stats(heal_from_pill: bool = false) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var jade_lv := passive_level("sword_jade")
	var gourd_lv := passive_level("spirit_gourd")
	var boots_lv := passive_level("cloud_boots")
	var wind_lv := passive_level("wind_orb")
	var lamp_lv := passive_level("fire_lamp")
	var pill_lv := passive_level("spirit_pill")

	var sect_might := float(_player.get("sect_might_mult")) if "sect_might_mult" in _player else 1.0
	var limit_might := float(_player.get("limit_might_bonus")) if "limit_might_bonus" in _player else 0.0
	var limit_haste := float(_player.get("limit_haste_bonus")) if "limit_haste_bonus" in _player else 0.0

	var slash_lv := weapon_level("lotus_slash")
	crit_chance = clampf(_player.base_crit_chance + jade_lv * 0.07 + (0.08 if slash_lv >= 5 else 0.0), 0.0, 0.85)
	crit_mult = 1.65 + jade_lv * 0.15
	cooldown_mult = maxf(0.32, pow(0.92, float(gourd_lv)) * pow(0.95, limit_haste))
	area_mult = 1.0 + lamp_lv * 0.12
	damage_mult = (1.0 + lamp_lv * 0.08) * sect_might * (1.0 + limit_might)
	bonus_amount = wind_lv

	_player.speed = _player.base_speed * (1.0 + boots_lv * 0.10)
	_player.dash_cooldown = maxf(0.85, _player.base_dash_cooldown * pow(0.88, float(boots_lv)))
	_player.magnet_radius = _player.base_magnet_radius * (1.0 + gourd_lv * 0.18)
	_player.regen_per_second = pill_lv * 0.8

	var target_max_hp: float = float(_player.base_max_health) + float(pill_lv) * 25.0
	if not is_equal_approx(float(_player.max_health), target_max_hp):
		var diff: float = target_max_hp - float(_player.max_health)
		_player.max_health = target_max_hp
		if diff > 0.0:
			_player.current_health = minf(_player.max_health, _player.current_health + diff)
		_player.emit_signal("health_changed", _player.current_health, _player.max_health)
	elif heal_from_pill and _player.has_method("heal"):
		_player.heal(25.0)

func _sync_persistent_weapons() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if weapons.has("taiji_array"):
		var lv := weapon_level("taiji_array")
		var evo := is_weapon_evolved("taiji_array")
		var st := WeaponCatalog.weapon_stat("taiji_array", lv)
		var count: int = (6 if evo else int(st.get("count", 2))) + mini(2, bonus_amount)
		var dmg := (125.0 if evo else float(st.get("dmg", 26.0))) * damage_mult
		var kb := 210.0 if evo else float(st.get("kb", 110.0))
		for s in _orbit_swords:
			if is_instance_valid(s):
				ObjectPools.release(s)
		_orbit_swords.clear()
		for i in range(count):
			var sw = ObjectPools.acquire(ORBIT_SCENE, _player)
			if sw != null:
				sw.damage = dmg
				sw.knockback = kb
				sw.is_evolved = evo
				_orbit_swords.append(sw)
	else:
		for s in _orbit_swords:
			if is_instance_valid(s):
				ObjectPools.release(s)
		_orbit_swords.clear()

	if weapons.has("jade_aura"):
		var lv := weapon_level("jade_aura")
		var evo := is_weapon_evolved("jade_aura")
		var st := WeaponCatalog.weapon_stat("jade_aura", lv)
		if _jade_aura == null or not is_instance_valid(_jade_aura):
			var sc := load(AURA_SCENE) as PackedScene
			if sc != null:
				_jade_aura = sc.instantiate()
				_player.add_child(_jade_aura)
		if _jade_aura != null:
			var rad := (200.0 if evo else float(st.get("rad", 96.0))) * area_mult
			var dmg := (88.0 if evo else float(st.get("dmg", 18.0))) * damage_mult
			var interval := (0.26 if evo else float(st.get("cd", 0.60))) * cooldown_mult
			var kb := 165.0 if evo else float(st.get("kb", 70.0))
			var slow := 0.38 if evo else float(st.get("slow", 0.0))
			_jade_aura.configure(rad, dmg, interval, kb, slow, evo, _player, crit_chance, crit_mult)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_dead:
		return

	_tick_delayed_slashes(delta)
	if not auto_fire_enabled:
		return

	_update_orbit_swords(delta)

	for wid in weapons.keys():
		if wid == "taiji_array" or wid == "jade_aura":
			continue
		var st: Dictionary = weapons[wid]
		st["timer"] = float(st["timer"]) - delta
		if float(st["timer"]) <= 0.0:
			var cd := _fire_weapon(str(wid), int(st["level"]), bool(st["evolved"]))
			st["timer"] = maxf(0.14, cd * cooldown_mult)

func _update_orbit_swords(delta: float) -> void:
	if _orbit_swords.is_empty():
		return
	var lv := weapon_level("taiji_array")
	var evo := is_weapon_evolved("taiji_array")
	var st := WeaponCatalog.weapon_stat("taiji_array", lv)
	var rot_speed := 7.2 if evo else float(st.get("rot_speed", 3.2))
	var rad := (148.0 if evo else float(st.get("rad", 84.0))) * area_mult
	_orbit_angle += rot_speed * delta
	var step := TAU / float(_orbit_swords.size())
	for i in range(_orbit_swords.size()):
		var sw := _orbit_swords[i]
		if is_instance_valid(sw):
			var a := _orbit_angle + float(i) * step
			sw.position = Vector2(cos(a), sin(a)) * rad
			sw.rotation = a + PI * 0.5

func _tick_delayed_slashes(delta: float) -> void:
	var i := _delayed_slashes.size() - 1
	while i >= 0:
		_delayed_slashes[i]["delay"] = float(_delayed_slashes[i]["delay"]) - delta
		if float(_delayed_slashes[i]["delay"]) <= 0.0:
			var req: Dictionary = _delayed_slashes[i]
			_delayed_slashes.remove_at(i)
			_spawn_slash(req["dir"], float(req["dmg"]), float(req["rad"]), float(req["kb"]), bool(req["evo"]), req.get("pos", Vector2.INF))
		i -= 1

func trigger_dash_slash(dash_dir: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if "character_id" in _player and str(_player.character_id) == "jinyiwei_gunner":
		var g_lv := maxi(1, weapon_level("shenji_musket"))
		var g_evo := is_weapon_evolved("shenji_musket")
		var g_st := WeaponCatalog.weapon_stat("shenji_musket", g_lv)
		var g_dmg := (float(g_st.get("dmg", 48.0)) * 1.25) * damage_mult
		var fire_dir: Vector2 = dash_dir.normalized() if dash_dir.length_squared() > 0.01 else (_player.get_aim_direction() if _player.has_method("get_aim_direction") else Vector2.RIGHT)
		var base_a: float = fire_dir.angle()
		for i in range(5):
			var sw = ObjectPools.acquire(SWORD_SCENE, _player.get_parent(), 120)
			if sw == null:
				break
			sw.global_position = _player.global_position
			var ang := base_a + (float(i) - 2.0) * 0.14
			if sw.has_method("setup_bullet"):
				sw.setup_bullet(Vector2.from_angle(ang), g_dmg, 1020.0, 3, 64.0 * area_mult, g_evo, 140.0)
			else:
				sw.setup(Vector2.from_angle(ang), g_dmg, 1020.0, 3, 0, g_evo, 140.0)
		_spawn_slash(fire_dir, g_dmg * 1.1, 118.0 * area_mult, 190.0, g_evo, _player.global_position)
		Sfx.play_varied("cannon_blast", -7.0)
		return
	var lv := maxi(1, weapon_level("lotus_slash"))
	var evo := is_weapon_evolved("lotus_slash")
	var st := WeaponCatalog.weapon_stat("lotus_slash", lv)
	var dmg := (float(st.get("dmg", 46.0)) * 1.25) * damage_mult
	var rad := float(st.get("rad", 116.0)) * 1.1 * area_mult
	_spawn_slash(dash_dir, dmg, rad, 185.0, evo, _player.global_position)
	_delayed_slashes.append({"delay": 0.16, "dir": dash_dir, "dmg": dmg * 1.15, "rad": rad * 1.08, "kb": 195.0, "evo": evo, "pos": Vector2.INF})

func _fire_weapon(wid: String, lv: int, evo: bool) -> float:
	match wid:
		"lotus_slash":
			return _cast_lotus_slash(lv, evo)
		"shenji_musket":
			return _cast_shenji_musket(lv, evo)
		"flying_sword":
			return _cast_flying_sword(lv, evo)
		"thunder_seal":
			return _cast_thunder_seal(lv, evo)
		"fire_lotus":
			return _cast_fire_lotus(lv, evo)
	return 1.2

func _cast_shenji_musket(lv: int, evo: bool) -> float:
	var st := WeaponCatalog.weapon_stat("shenji_musket", lv)
	var nearest := _find_nearest_enemy()
	var base_dir: Vector2 = _player.get_aim_direction() if _player.has_method("get_aim_direction") else Vector2.RIGHT
	if nearest != null and is_instance_valid(nearest):
		var to_e := nearest.global_position - _player.global_position
		if to_e.length_squared() > 4.0:
			base_dir = to_e.normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = Vector2.RIGHT
	var base_angle := base_dir.angle()
	var count: int = (6 if evo else int(st.get("count", 1))) + bonus_amount
	var dmg := (128.0 if evo else float(st.get("dmg", 42.0))) * damage_mult
	var spd := 1180.0 if evo else float(st.get("spd", 880.0))
	var pierce := 5 if evo else int(st.get("pierce", 2))
	var blast := (92.0 if evo else float(st.get("blast", 0.0))) * area_mult
	var kb := 165.0 if evo else float(st.get("kb", 85.0))

	for i in range(count):
		var sw = ObjectPools.acquire(SWORD_SCENE, _player.get_parent(), 120)
		if sw == null:
			break
		sw.global_position = _player.global_position + base_dir * 18.0
		var offset_ang := (float(i) - float(count - 1) * 0.5) * 0.11
		var final_dir := Vector2.from_angle(base_angle + offset_ang)
		var rolled_dmg := dmg * (crit_mult if randf() < crit_chance else 1.0)
		if sw.has_method("setup_bullet"):
			sw.setup_bullet(final_dir, rolled_dmg, spd, pierce, blast, evo, kb)
		else:
			sw.setup(final_dir, rolled_dmg, spd, pierce, 0, evo, kb)
	var vis := _player.get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("trigger_attack_anim"):
		vis.trigger_attack_anim(base_dir)
	Sfx.play_varied("gun_shot", -9.0)
	if evo:
		Sfx.play_varied("cannon_blast", -12.0)
	return 0.28 if evo else float(st.get("cd", 0.84))

func _cast_lotus_slash(lv: int, evo: bool) -> float:
	var dir: Vector2 = _player.get_aim_direction() if _player.has_method("get_aim_direction") else (_player.facing_dir if _player.facing_dir.length_squared() > 0.01 else Vector2.RIGHT)
	var st := WeaponCatalog.weapon_stat("lotus_slash", lv)
	var base_dmg := (165.0 if evo else float(st.get("dmg", 46.0))) * damage_mult
	var rad := (195.0 if evo else float(st.get("rad", 116.0))) * area_mult
	var kb := 230.0 if evo else float(st.get("kb", 150.0))

	if evo:
		_spawn_slash(dir, base_dmg, rad, kb, true)
		if bonus_amount > 0:
			_delayed_slashes.append({"delay": 0.14, "dir": -dir, "dmg": base_dmg * 0.85, "rad": rad, "kb": kb, "evo": true})
		return 0.65

	var dir_cnt := int(st.get("dirs", 1))
	var dirs: Array[Vector2] = [dir]
	if dir_cnt >= 2:
		dirs.append(-dir)
	if dir_cnt >= 4:
		dirs.append(dir.rotated(PI * 0.5))
		dirs.append(dir.rotated(-PI * 0.5))

	for d in dirs:
		_spawn_slash(d, base_dmg, rad, kb, false)

	var extra_waves := int(st.get("waves", 0)) + mini(1, bonus_amount)
	for w in range(extra_waves):
		_delayed_slashes.append({
			"delay": 0.13 * float(w + 1),
			"dir": dir if w % 2 == 0 else -dir,
			"dmg": base_dmg * 0.9,
			"rad": rad * 1.05,
			"kb": kb,
			"evo": false,
		})
	return float(st.get("cd", 1.08))

func _spawn_slash(dir: Vector2, dmg: float, rad: float, kb: float, evo: bool, world_pos: Vector2 = Vector2.INF) -> void:
	if _player == null or _player.get_parent() == null:
		return
	var sl = ObjectPools.acquire(SLASH_SCENE, _player.get_parent(), 32)
	if sl == null:
		return
	var vis := _player.get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("trigger_attack_anim"):
		vis.trigger_attack_anim(dir)
	sl.global_position = _player.global_position if world_pos == Vector2.INF else world_pos
	sl.setup(dir, dmg, rad, kb, crit_chance, crit_mult, evo, _player)

func _cast_flying_sword(lv: int, evo: bool) -> float:
	var target := _find_nearest_enemy()
	if target == null:
		return 0.25
	var st := WeaponCatalog.weapon_stat("flying_sword", lv)
	var base_dir := (target.global_position - _player.global_position).normalized()
	var base_angle := base_dir.angle()
	var count: int = (4 if evo else int(st.get("count", 1))) + bonus_amount
	var dmg := (130.0 if evo else float(st.get("dmg", 38.0))) * damage_mult
	var spd := 890.0 if evo else float(st.get("spd", 610.0))
	var pierce := 6 if evo else int(st.get("pierce", 2))
	var ricochet := 2 if evo else 0
	var kb := 160.0 if evo else float(st.get("kb", 65.0))

	for i in range(count):
		var sw = ObjectPools.acquire(SWORD_SCENE, _player.get_parent(), 120)
		if sw == null:
			break
		sw.global_position = _player.global_position
		var offset_ang := (float(i) - float(count - 1) * 0.5) * 0.16
		var final_dir := Vector2.from_angle(base_angle + offset_ang)
		var rolled_dmg := dmg * (crit_mult if randf() < crit_chance else 1.0)
		sw.setup(final_dir, rolled_dmg, spd, pierce, ricochet, evo, kb)
	Sfx.play_varied("sword_cast", -13.0)
	return 0.24 if evo else float(st.get("cd", 1.12))

func _cast_thunder_seal(lv: int, evo: bool) -> float:
	var candidates: Array[Node2D] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			if _player.global_position.distance_to(e.global_position) <= 760.0:
				candidates.append(e)
	if candidates.is_empty():
		return 0.35
	var st := WeaponCatalog.weapon_stat("thunder_seal", lv)
	var strikes: int = (5 if evo else int(st.get("count", 1))) + bonus_amount
	var dmg := (235.0 if evo else float(st.get("dmg", 72.0))) * damage_mult
	var rad := (142.0 if evo else float(st.get("rad", 74.0))) * area_mult
	var chains := 2 if evo else 0

	for i in range(strikes):
		var pick: Node2D = candidates[randi() % candidates.size()]
		var th = ObjectPools.acquire(THUNDER_SCENE, _player.get_parent(), 40)
		if th == null:
			break
		th.damage = dmg * (crit_mult if randf() < crit_chance else 1.0)
		th.radius = rad
		th.chain_count = chains
		th.is_evolved = evo
		th.global_position = pick.global_position
	return 0.92 if evo else float(st.get("cd", 2.45))

func _cast_fire_lotus(lv: int, evo: bool) -> float:
	var st := WeaponCatalog.weapon_stat("fire_lotus", lv)
	var count: int = (4 if evo else int(st.get("count", 1))) + bonus_amount
	var dmg := (145.0 if evo else float(st.get("dmg", 40.0))) * damage_mult
	var burn := (52.0 if evo else float(st.get("burn", 12.0))) * damage_mult
	var rad := (136.0 if evo else float(st.get("rad", 70.0))) * area_mult
	var dur := 5.2 if evo else float(st.get("dur", 3.1))

	var nearest := _find_nearest_enemy()
	for i in range(count):
		var tl = ObjectPools.acquire(TALISMAN_SCENE, _player.get_parent(), 32)
		if tl == null:
			break
		var override_pos := Vector2.INF
		if i == 0 and nearest != null and is_instance_valid(nearest):
			override_pos = nearest.global_position
		tl.setup(_player.global_position, dmg, rad, burn, dur, evo, override_pos, crit_chance, crit_mult)
	return 1.40 if evo else float(st.get("cd", 2.70))

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_sq := INF
	var nearby := CombatGrid.query(_player.global_position, 440.0)
	var source: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in source:
		if is_instance_valid(e) and not e.is_dead:
			var d_sq := _player.global_position.distance_squared_to(e.global_position)
			if d_sq < best_sq:
				best_sq = d_sq
				best = e
	if best == null and not nearby.is_empty():
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.is_dead:
				var d_sq := _player.global_position.distance_squared_to(e.global_position)
				if d_sq < best_sq:
					best_sq = d_sq
					best = e
	return best
