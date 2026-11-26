extends Node2D

signal wave_completed(completed_wave: int, next_wave: int)

@export var enemy_scene_path: String = "res://scenes/enemy.tscn"
@export var jar_scene_path: String = "res://scenes/breakable_jar.tscn"
@export var base_spawn_interval: float = 0.45
@export var min_spawn_interval: float = 0.14
@export var max_enemies: int = 250
@export var despawn_distance: float = 1800.0

var spawn_timer: float = 0.0
var elapsed: float = 0.0
var cleanup_timer: float = 0.0
var jar_timer: float = 6.0
var spawn_interval: float = 0.60

var _next_elite_time: float = 95.0
var _is_boss_spawned: bool = false
var _boss_instance: Node2D = null

var chapter_index: int = 0
var chapter_duration: float = 480.0
var chapter_boss_name: String = "苍鬃狼王"
var chapter_palette: Dictionary = {}
const ELITE_FIRST_SEC := 60.0
var enemy_weights: Dictionary = {"wolf": 0.65, "ghost": 0.25, "skeleton": 0.10}
var elite_interval: float = 95.0

var _chapter_elapsed: float = 0.0
var _swarm_music_timer: float = 0.0
var _stage_hp_mult: float = 1.0
var _stage_mods: Dictionary = {}
var _stage_enemy_speed_mult: float = 1.0
var _stage_hp_ramp_per_min: float = 0.0
var _stage_pool_bias: Dictionary = {}
var _extra_chest_elite_per_min: bool = false
var _next_stage_elite_time: float = 60.0
var _stage_waves: Array[Dictionary] = []
var _triggered_events: Dictionary = {}
var _wave_cap: int = 48
var _wave_budget_rate: float = 2.6
var _wave_hp_scale: float = 1.0
var _wave_dmg_scale: float = 1.0
var _wave_speed_scale: float = 1.0
var _wave_exp_mult: float = 1.0
var _wave_exp_val: float = 6.0
var _wave_tier_variant: int = 1
var _wave_pool_entries: Array = []
var _wave_shop_after: bool = true
var _spawn_pause_timer: float = 0.0
var _endless_level: int = 0
var _current_wave_num: int = 1
var _last_notified_wave: int = 0
var _wave_start_time: float = 0.0
var _pending_telegraphs: int = 0
var _pending_elite_telegraphs: int = 0
var _rare_elite_cd: float = 0.0
var _wave_elite_every_sec: float = 0.0
var _elite_spawn_timer: float = ELITE_FIRST_SEC

var _v2_loader: V2DataLoader = null
var _director: V2SpawnDirector = V2SpawnDirector.new()
var _cached_bg: Node = null
var debug_spawning_paused: bool = false

@onready var player: Node2D = get_node_or_null("../Player")

func _ready() -> void:
	add_to_group("spawner")
	_ensure_v2_loader()

func _ensure_v2_loader() -> void:
	if _v2_loader == null:
		_v2_loader = V2DataLoader.new()
		add_child(_v2_loader)
		_v2_loader.load_all()

func should_open_shop_after_wave(wave_num: int) -> bool:
	if _endless_level > 0:
		return true
	var idx := wave_num - 1
	if idx >= 0 and idx < _stage_waves.size():
		return bool(_stage_waves[idx].get("shop_after", true))
	return true

func pause_spawning(sec: float) -> void:
	_spawn_pause_timer = maxf(_spawn_pause_timer, sec)

func _process(delta: float) -> void:
	elapsed += delta
	_chapter_elapsed += delta
	_rare_elite_cd = maxf(0.0, _rare_elite_cd - delta)
	_evaluate_wave_schedule()

	if player == null or not is_instance_valid(player):
		var p := get_tree().get_nodes_in_group("player")
		if p.size() > 0:
			player = p[0]
		return

	if _swarm_music_timer > 0.0:
		_swarm_music_timer -= delta
		if _swarm_music_timer <= 0.0 and not _is_boss_spawned:
			Music.play_track("battle", 1.0)

	var current_cap := mini(max_enemies, 40 if _is_boss_spawned else _enemy_cap())
	var alive := get_tree().get_nodes_in_group("enemies").size()

	if debug_spawning_paused:
		return
	if _spawn_pause_timer > 0.0:
		_spawn_pause_timer = maxf(0.0, _spawn_pause_timer - delta)
	elif base_spawn_interval < 0.05:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			if alive < current_cap:
				_spawn_enemy(Enemy.Type.MINION)
	else:
		_director.advance_formation(delta)
		if alive + _pending_telegraphs < current_cap:
			var pool := _active_v2_pool()
			var rate_mult := 1.0
			if "v2_combat" in player and player.v2_combat != null:
				rate_mult = player.v2_combat.get_spawn_rate_mult()
			var reqs := _director.step_budget(delta * rate_mult, _current_wave_num, pool, _wave_budget_rate)
			if not reqs.is_empty():
				if _director.formation == V2SpawnDirector.Formation.SHIELD_KITER_SQUAD and reqs.size() >= 2:
					_spawn_squad_batch(reqs, current_cap)
				else:
					for req in reqs:
						if get_tree().get_nodes_in_group("enemies").size() + _pending_telegraphs >= current_cap:
							break
						var arch: Dictionary = req["archetype"]
						_spawn_from_archetype(arch)

	if _wave_elite_every_sec > 0.0 and not _is_boss_spawned and _spawn_pause_timer <= 0.0:
		_elite_spawn_timer -= delta
		if _elite_spawn_timer <= 0.0:
			_elite_spawn_timer = _wave_elite_every_sec
			if _chapter_elapsed >= ELITE_FIRST_SEC and _count_active_elites() < _max_active_elites():
				var elite_arch := _pick_pool_archetype()
				if not elite_arch.is_empty():
					_spawn_from_archetype(elite_arch, false, true)

	if _extra_chest_elite_per_min and not _is_boss_spawned and _chapter_elapsed >= _next_stage_elite_time:
		_next_stage_elite_time += 60.0
		_spawn_enemy(Enemy.Type.ELITE, -1, true)

	if _endless_level > 0 and elapsed >= _next_elite_time and not _is_boss_spawned:
		_next_elite_time = elapsed + maxf(25.0, elite_interval - float(_endless_level) * 6.0)
		_spawn_enemy(Enemy.Type.ELITE, -1, true)

	jar_timer -= delta
	if jar_timer <= 0.0:
		jar_timer = 14.0
		_spawn_breakable_jar()

	cleanup_timer += delta
	if cleanup_timer >= 2.0:
		cleanup_timer = 0.0
		_cleanup_far_enemies()

func _evaluate_wave_schedule() -> void:
	if base_spawn_interval < 0.05:
		spawn_interval = maxf(min_spawn_interval, base_spawn_interval)
		return

	if _stage_waves.is_empty():
		spawn_interval = maxf(min_spawn_interval, base_spawn_interval - elapsed * 0.0025)
		return

	var active_idx: int = _stage_waves.size() - 1
	for i in range(_stage_waves.size()):
		var w: Dictionary = _stage_waves[i]
		if _chapter_elapsed >= float(w.get("start", 0.0)) and _chapter_elapsed < float(w.get("end", 99999.0)):
			active_idx = i
			break

	var active: Dictionary = _stage_waves[active_idx]
	var prev_wave := _current_wave_num
	_current_wave_num = active_idx + 1 + _endless_level * 5

	var endless_fast := 1.0 + float(_endless_level) * 0.25
	spawn_interval = maxf(min_spawn_interval, float(active.get("interval", 0.45)) / endless_fast)
	_wave_cap = int(round(float(active.get("cap", 60)) * (1.0 + float(_endless_level) * 0.15)))
	_wave_budget_rate = float(active.get("budget_per_sec", V2SpawnDirector.budget_per_sec(_current_wave_num))) * endless_fast
	_wave_hp_scale = float(active.get("hp_scale", 1.0)) * (1.0 + float(_endless_level) * 0.45)
	_wave_dmg_scale = float(active.get("dmg_scale", 1.0 + float(active_idx) * 0.22)) * (1.0 + float(_endless_level) * 0.25)
	_wave_speed_scale = float(active.get("speed_scale", 1.0)) * (1.0 + float(_endless_level) * 0.06)
	_wave_exp_mult = float(active.get("exp_mult", 1.0)) * (1.0 + float(_endless_level) * 0.30)
	_wave_exp_val = float(active.get("exp_val", 4.0 * _wave_exp_mult))
	_wave_tier_variant = clampi(int(active.get("tier_variant", 1)), 1, 3)
	_wave_elite_every_sec = maxf(0.0, float(active.get("elite_every_sec", 0.0)))
	_wave_shop_after = bool(active.get("shop_after", true))
	var raw_pool = active.get("pool", [])
	_wave_pool_entries = raw_pool if raw_pool is Array else []

	if _current_wave_num != _last_notified_wave:
		_last_notified_wave = _current_wave_num
		_wave_start_time = float(active.get("start", _chapter_elapsed))
		_director.reset_queue()
		if player != null and is_instance_valid(player) and "v2_combat" in player and player.v2_combat != null:
			player.v2_combat.set_current_wave(_current_wave_num)
		var landmarks := get_parent().get_node_or_null("ArenaLandmarks") if get_parent() != null else null
		if landmarks != null and landmarks.has_method("activate_wave"):
			landmarks.activate_wave(_current_wave_num, int(_stage_mods.get("stele_wave_interval", 3)))
		if not _is_boss_spawned and get_tree() != null:
			get_tree().call_group("ui", "update_wave_info", _current_wave_num, maxi(1, _stage_waves.size()), String(active.get("name", "")))
		if prev_wave >= 1 and _current_wave_num > prev_wave and not _is_boss_spawned and _chapter_elapsed > 1.0:
			wave_completed.emit(prev_wave, _current_wave_num)

	var w_weights = active.get("weights", null)
	if w_weights is Dictionary and not w_weights.is_empty():
		enemy_weights = w_weights

	if _is_boss_spawned:
		return

	for i in range(_stage_waves.size()):
		var w: Dictionary = _stage_waves[i]
		var events: Array = w.get("events", [])
		for j in range(events.size()):
			var ev_key := "%d_%d" % [i, j]
			if _triggered_events.has(ev_key):
				continue
			var ev: Dictionary = events[j]
			if _chapter_elapsed >= float(ev.get("time", 99999.0)):
				_triggered_events[ev_key] = true
				_fire_wave_event(ev)

func _active_v2_pool() -> Array:
	_ensure_v2_loader()
	if _v2_loader == null or _v2_loader.enemy_archetypes.is_empty():
		return []
	var pool: Array = []
	if not _wave_pool_entries.is_empty():
		for entry in _wave_pool_entries:
			if not (entry is Dictionary):
				continue
			var aid := String((entry as Dictionary).get("id", ""))
			if not _v2_loader.enemy_archetypes.has(aid):
				continue
			var arch: Dictionary = (_v2_loader.enemy_archetypes[aid] as Dictionary).duplicate()
			var w := maxf(0.05, float((entry as Dictionary).get("weight", 1.0)))
			w *= maxf(0.1, float(_stage_pool_bias.get(aid, 1.0)))
			arch["_spawn_weight"] = w
			pool.append(arch)
	if pool.is_empty():
		for id_str in _v2_loader.enemy_archetypes.keys():
			var arch: Dictionary = (_v2_loader.enemy_archetypes[id_str] as Dictionary).duplicate()
			var aid := String(arch.get("id", ""))
			arch["_spawn_weight"] = maxf(0.1, float(_stage_pool_bias.get(aid, 1.0)))
			pool.append(arch)
	return _director.apply_subwave_cadence(pool, maxf(0.0, _chapter_elapsed - _wave_start_time))

func _pick_pool_archetype() -> Dictionary:
	var pool := _active_v2_pool()
	if pool.is_empty():
		return {}
	var total_w := 0.0
	for a in pool:
		total_w += maxf(0.05, float((a as Dictionary).get("_spawn_weight", 1.0)))
	var roll := randf() * maxf(0.05, total_w)
	var acc := 0.0
	for a in pool:
		var d := a as Dictionary
		acc += maxf(0.05, float(d.get("_spawn_weight", 1.0)))
		if roll <= acc:
			return d
	return pool[pool.size() - 1] as Dictionary

func _fire_wave_event(ev: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var kind := str(ev.get("type", "swarm"))
	var msg := str(ev.get("msg", ""))
	match kind:
		"ring":
			_spawn_ring_event(int(ev.get("count", 24)), msg)
		"flank":
			_spawn_flank_lanes(int(ev.get("count", 18)), msg)
		"mini_boss":
			_spawn_mini_boss(float(ev.get("hp", 750.0)), msg)
		_:
			_trigger_swarm(int(ev.get("count", 30)), int(ev.get("elites", 1)), msg)

func apply_chapter(chapter: Dictionary) -> void:
	_ensure_v2_loader()
	chapter_index = maxi(0, int(chapter.get("id", 1)) - 1)
	chapter_duration = float(chapter.get("duration", 480.0))
	elite_interval = float(chapter.get("elite_interval", 95.0))
	chapter_boss_name = str(chapter.get("boss_name", chapter_boss_name))
	chapter_palette = chapter.get("palette", {})
	var raw_mods = chapter.get("mods", {})
	_stage_mods = raw_mods if raw_mods is Dictionary else {}
	_stage_hp_mult = float(_stage_mods.get("enemy_hp", chapter.get("hp_mult", 1.0 + float(chapter_index) * 0.25)))
	_stage_enemy_speed_mult = float(_stage_mods.get("enemy_speed", 1.0))
	_stage_hp_ramp_per_min = float(_stage_mods.get("hp_ramp_per_min", 0.0))
	var pb = _stage_mods.get("pool_bias", {})
	_stage_pool_bias = pb if pb is Dictionary else {}
	_extra_chest_elite_per_min = bool(_stage_mods.get("extra_chest_elite_per_min", false))
	_next_stage_elite_time = 60.0
	var raw_waves = chapter.get("waves", [])
	_stage_waves.clear()
	if raw_waves is Array:
		for w in raw_waves:
			if w is Dictionary:
				_stage_waves.append(w)
	_triggered_events.clear()
	var w = chapter.get("enemy_weights", null)
	if w is Dictionary and not w.is_empty():
		enemy_weights = w
	_chapter_elapsed = 0.0
	_is_boss_spawned = false
	_boss_instance = null
	_endless_level = 0
	_current_wave_num = 1
	_last_notified_wave = 0
	_wave_start_time = 0.0
	_pending_telegraphs = 0
	_pending_elite_telegraphs = 0
	_rare_elite_cd = 0.0
	_wave_elite_every_sec = 0.0
	_elite_spawn_timer = ELITE_FIRST_SEC
	_spawn_pause_timer = 0.0
	_director.reset()
	_next_elite_time = elapsed + elite_interval
	_evaluate_wave_schedule()
	if player != null and is_instance_valid(player) and "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.set_current_wave(_current_wave_num)

func set_endless_level(lv: int) -> void:
	_endless_level = maxi(0, lv)
	_is_boss_spawned = false
	_boss_instance = null
	_last_notified_wave = 0
	_next_elite_time = elapsed + 30.0

func finish_wave_and_vacuum() -> Dictionary:
	return V2SpawnDirector.trigger_wave_end_vacuum(get_tree(), player)

func spawn_chapter_boss(chapter: Dictionary) -> Node2D:
	return _spawn_boss(chapter)

func spawn_boss_entry(entry: Dictionary) -> Node2D:
	if bool(entry.get("mini", false)):
		_spawn_mini_boss(float(entry.get("hp", 4600.0)), "【%s 现身 · 斩将夺箱！】" % String(entry.get("name", "小首领")))
		return null
	return _spawn_boss({
		"boss_name": String(entry.get("name", "")),
		"boss_type": String(entry.get("type", "wolf")),
		"boss_hp": float(entry.get("hp", 4600.0)),
	})

func _spawn_boss(chapter: Dictionary) -> Node2D:
	_is_boss_spawned = true
	_swarm_music_timer = 0.0
	Music.play_track("boss", 0.55)
	Sfx.play_boss_or_fallback("boss_roar", "thunder", -1.0, 0.85)
	var boss_name := str(chapter.get("boss_name", chapter_boss_name))
	get_tree().call_group("ui", "show_banner", "【首领降临 · %s】" % boss_name)

	var angle := randf() * TAU
	var spawn_pos := _offscreen_ring_point(angle, randf_range(240.0, 400.0))

	var boss = ObjectPools.acquire(enemy_scene_path, get_parent())
	if boss == null:
		return null
	boss.global_position = spawn_pos
	if boss.has_method("setup_type"):
		boss.setup_type(Enemy.Type.BOSS, elapsed, _boss_species(chapter))
	var p_lv := int(player.get("level")) if (player != null and "level" in player) else 1
	var lv_scale := 1.0 + maxf(0.0, float(p_lv - 15)) * 0.025
	var endless_scale := 1.0 + float(_endless_level) * 0.65
	var boss_hp := float(chapter.get("boss_hp", 4600.0)) * lv_scale * endless_scale
	boss.max_health = boss_hp
	boss.current_health = boss_hp
	boss.exp_gem_value = 180.0
	boss.modulate = Color.WHITE
	_boss_instance = boss

	get_tree().call_group("ui", "set_boss_name", boss_name)
	get_tree().call_group("ui", "activate_boss_bar", boss.max_health)
	return boss

func _count_active_elites() -> int:
	var count := _pending_elite_telegraphs
	if not is_inside_tree() or get_tree() == null:
		return count
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != null and is_instance_valid(e) and not bool(e.get("is_dead")) and int(e.get("enemy_type")) == Enemy.Type.ELITE:
			count += 1
	return count

func _max_active_elites() -> int:
	if _endless_level > 0 or _current_wave_num >= 8:
		return 3
	if _current_wave_num <= 3:
		return 1
	return 2

func spawn_telegraphed_enemy(
	world_pos: Vector2,
	enemy_type: int = Enemy.Type.MINION,
	telegraph_sec: float = 0.8,
	species_override: int = -1,
	arch_override: Dictionary = {}
) -> void:
	if get_parent() == null or _pending_telegraphs >= 16:
		return
	var target_pos := world_pos
	var eff_telegraph := telegraph_sec
	var is_elite := (enemy_type == Enemy.Type.ELITE)
	if is_elite:
		if player != null and is_instance_valid(player):
			var away := target_pos - player.global_position
			var dist := away.length()
			if dist < 340.0:
				var dir := away / dist if dist > 1.0 else Vector2.from_angle(randf() * TAU)
				target_pos = player.global_position + dir * 380.0
		eff_telegraph = maxf(eff_telegraph, 1.25)
		_pending_elite_telegraphs += 1
	var pos := _clamp_to_arena(target_pos)
	_pending_telegraphs += 1
	var tele := SpawnTelegraph.new()
	var rad := 42.0 if is_elite else 30.0
	tele.setup(pos, eff_telegraph, rad, func(spawn_p: Vector2) -> void:
		_pending_telegraphs = maxi(0, _pending_telegraphs - 1)
		if is_elite:
			_pending_elite_telegraphs = maxi(0, _pending_elite_telegraphs - 1)
		if is_inside_tree():
			_instantiate_enemy_at(spawn_p, enemy_type, species_override, arch_override)
	)
	get_parent().add_child(tele)

func _spawn_breakable_jar() -> void:
	if get_tree().get_nodes_in_group("world_pickups").size() >= 6:
		return
	var scene := load("res://scenes/world_pickup.tscn") as PackedScene
	if scene == null or get_parent() == null or player == null:
		return
	var ang := randf() * TAU
	var dist := randf_range(340.0, 560.0)
	var pos := _clamp_to_arena(player.global_position + Vector2(cos(ang), sin(ang)) * dist)
	var player_lv := int(player.get("level")) if player.get("level") != null else 1
	var frost_mult := 1.0
	if "v2_combat" in player and player.v2_combat != null and player.v2_combat.has_method("has_arcana"):
		if player.v2_combat.has_arcana("arcana_glacial_shatter"):
			frost_mult = 2.0
	var kind := BreakableJar.roll_drop_kind(player_lv, frost_mult)
	var pickup = scene.instantiate()
	pickup.global_position = pos
	get_parent().add_child(pickup)
	if pickup.has_method("setup"):
		pickup.setup(kind)
	if pickup.has_method("pop_out"):
		pickup.pop_out(Vector2.from_angle(ang))

func _enemy_cap() -> int:
	return mini(max_enemies, _wave_cap)

func _boss_species(chapter: Dictionary) -> int:
	match str(chapter.get("boss_type", "wolf")):
		"ghost": return 1
		"skeleton": return 2
		_: return 0

func _pick_minion_species() -> int:
	var wolf_w := float(enemy_weights.get("wolf", 0.18))
	var ghost_w := float(enemy_weights.get("ghost", 0.16))
	var skel_w := float(enemy_weights.get("skeleton", 0.14))
	var jiangshi_w := float(enemy_weights.get("jiangshi", 0.14))
	var jinchan_w := float(enemy_weights.get("jinchan", 0.12))
	var shenjing_w := float(enemy_weights.get("shenjing", 0.14))
	var huodou_w := float(enemy_weights.get("huodou", 0.12))
	var total := wolf_w + ghost_w + skel_w + jiangshi_w + jinchan_w + shenjing_w + huodou_w
	if total <= 0.0:
		return 0
	var roll := randf() * total
	var acc := wolf_w
	if roll < acc: return 0
	acc += ghost_w
	if roll < acc: return 1
	acc += skel_w
	if roll < acc: return 2
	acc += jiangshi_w
	if roll < acc: return 3
	acc += jinchan_w
	if roll < acc: return 4
	acc += shenjing_w
	if roll < acc: return 5
	return 6

func _spawn_squad_batch(reqs: Array[Dictionary], cap: int) -> void:
	var arena := _get_arena_rect()
	var cam := _camera_world_rect()
	var pillars := _get_pillars()
	var pick := _director.pick_spawn_point(arena, cam, player.global_position, pillars, false)
	var slots := _director.build_formation_offsets(
		V2SpawnDirector.Formation.SHIELD_KITER_SQUAD,
		pick["pos"] as Vector2,
		player.global_position,
		reqs.size()
	)
	for i in range(slots.size()):
		if get_tree().get_nodes_in_group("enemies").size() + _pending_telegraphs >= cap:
			break
		var pos: Vector2 = _clamp_to_arena(slots[i]["pos"] as Vector2)
		var arch: Dictionary = reqs[i]["archetype"]
		var sp_id: int = int(arch.get("species", -1))
		if sp_id < 0:
			sp_id = 2 if String(slots[i]["role"]) == "shield" else 1
		if bool(pick["use_telegraph"]):
			spawn_telegraphed_enemy(pos, Enemy.Type.MINION, float(pick["telegraph_sec"]), sp_id, arch)
		else:
			_instantiate_enemy_at(pos, Enemy.Type.MINION, sp_id, arch)

func _spawn_from_archetype(arch: Dictionary, force_telegraph: bool = false, force_elite: bool = false) -> void:
	var arena := _get_arena_rect()
	var cam := _camera_world_rect()
	var pillars := _get_pillars()
	var behavior := String(arch.get("ai_behavior", "swarm_chaser"))
	var can_promote_elite := _wave_elite_every_sec <= 0.0 and _current_wave_num >= 3 and _rare_elite_cd <= 0.0 and _count_active_elites() < _max_active_elites()
	var elite_roll := randf()
	var elite_chance := float(arch.get("elite_chance", 0.10))
	var is_rare_elite := can_promote_elite and elite_roll < elite_chance
	if is_rare_elite:
		_rare_elite_cd = 26.0
	var e_type := Enemy.Type.ELITE if (is_rare_elite or force_elite) else Enemy.Type.MINION
	var sp_id := int(arch.get("species", -1))
	if sp_id < 0:
		match behavior:
			"kiter_shooter", "splitter_bomber":
				sp_id = 1
			"shield_bulwark":
				sp_id = 2
			_:
				sp_id = 0
	var min_tele_dist := 380.0 if e_type == Enemy.Type.ELITE else 300.0
	var pick := _director.pick_spawn_point(arena, cam, player.global_position, pillars, force_telegraph or e_type == Enemy.Type.ELITE, min_tele_dist)
	if bool(pick["use_telegraph"]):
		spawn_telegraphed_enemy(pick["pos"] as Vector2, e_type, float(pick["telegraph_sec"]), sp_id, arch)
	else:
		_instantiate_enemy_at(pick["pos"] as Vector2, e_type, sp_id, arch)

func _spawn_ring_event(count: int, msg: String) -> void:
	Sfx.play_boss_or_fallback("swarm_horn", "thunder", -2.0, 0.95)
	if msg != "":
		get_tree().call_group("ui", "show_banner", msg)
	var room := maxi(0, _enemy_cap() - get_tree().get_nodes_in_group("enemies").size())
	var n := mini(count, room)
	var cam := _camera_world_rect()
	var cam_half := cam.size * 0.5
	for i in range(n):
		var ang := TAU * float(i) / float(maxi(1, n)) + randf_range(-0.08, 0.08)
		var pad := randf_range(200.0, 360.0)
		var pos := _clamp_to_arena(cam.get_center() + Vector2(cos(ang) * (cam_half.x + pad), sin(ang) * (cam_half.y + pad)))
		var arch := _pick_pool_archetype()
		var sp_id := int(arch.get("species", _pick_minion_species())) if not arch.is_empty() else _pick_minion_species()
		_instantiate_enemy_at(pos, Enemy.Type.MINION, sp_id, arch)

func _spawn_flank_lanes(count: int, msg: String) -> void:
	Sfx.play_boss_or_fallback("swarm_horn", "thunder", -2.0, 0.95)
	if msg != "":
		get_tree().call_group("ui", "show_banner", msg)
	var room := maxi(0, _enemy_cap() - get_tree().get_nodes_in_group("enemies").size())
	var n := mini(count, room)
	var half := maxi(1, n / 2)
	var cam := _camera_world_rect()
	var cam_half := cam.size * 0.5
	var pad := randf_range(200.0, 360.0)
	for side in [-1.0, 1.0]:
		for i in range(half):
			var oy := (float(i) - float(half - 1) * 0.5) * 44.0
			var pos := _clamp_to_arena(Vector2(cam.get_center().x + side * (cam_half.x + pad), cam.get_center().y + oy))
			var arch := _pick_pool_archetype()
			var sp_id := int(arch.get("species", _pick_minion_species())) if not arch.is_empty() else _pick_minion_species()
			_instantiate_enemy_at(pos, Enemy.Type.MINION, sp_id, arch)

func _spawn_mini_boss(base_hp: float, msg: String, species_override: int = -1) -> void:
	Sfx.play_boss_or_fallback("swarm_horn", "thunder", -2.0, 0.85)
	if msg != "":
		get_tree().call_group("ui", "show_banner", msg)
	var pick := _director.pick_spawn_point(_get_arena_rect(), _camera_world_rect(), player.global_position, _get_pillars(), true, 380.0)
	var sp_id := species_override if species_override >= 0 else _pick_minion_species()
	spawn_telegraphed_enemy(pick["pos"] as Vector2, Enemy.Type.ELITE, 1.25, sp_id, {"override_hp": base_hp, "is_mini_boss": true})

func _trigger_swarm(count: int, elites: int, msg: String) -> void:
	Sfx.play_boss_or_fallback("swarm_horn", "thunder", -2.0, 0.92)
	if not _is_boss_spawned:
		Music.play_track("swarm", 0.6)
		_swarm_music_timer = 18.0
	if msg != "":
		get_tree().call_group("ui", "show_banner", msg)

	var alive := get_tree().get_nodes_in_group("enemies").size()
	var room := maxi(0, _enemy_cap() - alive)
	count = mini(count, room)
	elites = mini(elites, maxi(0, room - count))

	for i in range(count):
		var angle := (float(i) / float(maxi(1, count))) * TAU + randf_range(-0.1, 0.1)
		var spawn_pos := _offscreen_ring_point(angle, randf_range(200.0, 360.0))
		var arch := _pick_pool_archetype()
		var sp_id := int(arch.get("species", _pick_minion_species())) if not arch.is_empty() else _pick_minion_species()
		_instantiate_enemy_at(spawn_pos, Enemy.Type.MINION, sp_id, arch)

	for _e in range(elites):
		_spawn_mini_boss(2200.0, "")

func _spawn_enemy(type: Enemy.Type = Enemy.Type.MINION, species_override: int = -1, force_telegraph: bool = false) -> void:
	if base_spawn_interval < 0.05:
		var pos := _offscreen_ring_point(randf() * TAU, randf_range(200.0, 360.0))
		_instantiate_enemy_at(pos, type, species_override)
		return

	var min_tele := 380.0 if type == Enemy.Type.ELITE else 300.0
	var pick := _director.pick_spawn_point(_get_arena_rect(), _camera_world_rect(), player.global_position, _get_pillars(), force_telegraph, min_tele)
	if bool(pick["use_telegraph"]):
		spawn_telegraphed_enemy(pick["pos"] as Vector2, type, float(pick["telegraph_sec"]), species_override)
	else:
		_instantiate_enemy_at(pick["pos"] as Vector2, type, species_override)

func _offscreen_ring_point(angle: float, pad: float) -> Vector2:
	var cam := _camera_world_rect()
	var cam_half := cam.size * 0.5
	var offset := Vector2(cos(angle) * (cam_half.x + pad), sin(angle) * (cam_half.y + pad))
	return _clamp_to_arena(cam.get_center() + offset)

func _instantiate_enemy_at(
	spawn_pos: Vector2,
	type: Enemy.Type,
	species_override: int = -1,
	arch_override: Dictionary = {}
) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	var enemy = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
	if enemy == null:
		return
	enemy.global_position = _clamp_to_arena(spawn_pos)
	var eff_arch := arch_override
	if eff_arch.is_empty() and type == Enemy.Type.MINION and species_override < 0:
		eff_arch = _pick_pool_archetype()
	var sp_id := species_override if species_override >= 0 else (int(eff_arch.get("species", _pick_minion_species())) if not eff_arch.is_empty() else _pick_minion_species())
	if enemy.has_method("setup_type"):
		enemy.setup_type(type, elapsed, sp_id)
	_scale_to_chapter(enemy)
	if not eff_arch.is_empty():
		if eff_arch.has("override_hp"):
			var bhp := float(eff_arch["override_hp"]) * _stage_hp_mult * (1.0 + float(_endless_level) * 0.5)
			enemy.max_health = bhp
			enemy.current_health = bhp
			enemy.is_mini_boss = bool(eff_arch.get("is_mini_boss", false))
			enemy.exp_gem_value = 45.0
			enemy.exp_gem_count = 4
			enemy.gold_value = 35
		elif eff_arch.has("base_hp") or eff_arch.has("hp_units"):
			if enemy.has_method("apply_archetype"):
				enemy.apply_archetype(eff_arch, _wave_tier_variant)
			var unit_hp := _v2_loader.get_unit_hp() if _v2_loader != null else V2DataLoader.BASE_UNIT_HP
			var base_spd_const := _v2_loader.get_base_enemy_speed() if _v2_loader != null else V2DataLoader.BASE_ENEMY_SPEED
			var raw_hp := float(eff_arch.get("base_hp", float(eff_arch.get("hp_units", 1.0)) * unit_hp))
			var raw_spd := float(eff_arch.get("move_speed", float(eff_arch.get("speed_pct", 100.0)) * 0.01 * base_spd_const))
			var time_ramp := 1.0 + _stage_hp_ramp_per_min * (_chapter_elapsed / 60.0)
			var v2_hp := raw_hp * _stage_hp_mult * _wave_hp_scale * time_ramp * (1.0 + float(_endless_level) * 0.45)
			if enemy.enemy_type == Enemy.Type.ELITE:
				var ev := _get_elite_variant(sp_id)
				v2_hp *= float(ev.get("hp_mult", 3.2))
				enemy.speed = raw_spd * float(ev.get("speed_mult", 1.12)) * _stage_enemy_speed_mult * _wave_speed_scale
				enemy.knockback_resistance = maxf(float(ev.get("kb_resist", 0.75)), enemy.knockback_resistance)
				if ev.has("phys_reduction"):
					enemy.damage_reduction = maxf(enemy.damage_reduction, float(ev.get("phys_reduction", 0.0)))
				if ev.has("slow_resist"):
					enemy.resistances["slow_resist"] = maxf(float(enemy.resistances.get("slow_resist", 0.0)), float(ev.get("slow_resist", 0.0)))
				enemy.exp_gem_count = int(ev.get("exp_gem_count", 4))
				enemy.exp_gem_value = maxf(22.0, float(eff_arch.get("xp_value", 5)) * _wave_exp_mult * float(ev.get("xp_mult", 2.5)))
				enemy.gold_value = maxi(6, int(eff_arch.get("gold_value", 3)) * int(ev.get("gold_mult", 3)))
			else:
				enemy.speed = raw_spd * _stage_enemy_speed_mult * _wave_speed_scale
				enemy.exp_gem_value = maxf(1.5, float(eff_arch.get("xp_value", 3)) * _wave_exp_mult)
				enemy.gold_value = int(eff_arch.get("gold_value", 1))
			enemy.max_health = v2_hp
			enemy.current_health = v2_hp
			var dmg_mult := float(_get_elite_variant(sp_id).get("dmg_mult", 1.45)) if enemy.enemy_type == Enemy.Type.ELITE else 1.0
			enemy.contact_damage = float(eff_arch.get("base_dmg", 8.0)) * _wave_dmg_scale * dmg_mult
			if enemy.enemy_type == Enemy.Type.ELITE:
				_apply_elite_affix(enemy)
		elif eff_arch.has("move_speed") and enemy.enemy_type == Enemy.Type.MINION:
			enemy.speed = float(eff_arch["move_speed"]) * _stage_enemy_speed_mult * _wave_speed_scale

func _apply_elite_affix(enemy: Node) -> void:
	if _v2_loader == null or _v2_loader.elite_affixes.is_empty():
		return
	var affix: Dictionary = _v2_loader.get_random_elite_affix()
	if affix.is_empty():
		return
	enemy.elite_affix_id = String(affix.get("id", ""))
	enemy.elite_aura_color = Color.from_string(String(affix.get("aura_color", "#FFFFFF")), Color(1.0, 1.0, 1.0))
	var speed_mult := float(affix.get("speed_mult", 1.0))
	if not is_equal_approx(speed_mult, 1.0):
		enemy.speed *= speed_mult
	var hp_mult := float(affix.get("hp_mult", 1.0))
	if not is_equal_approx(hp_mult, 1.0):
		enemy.max_health *= hp_mult
		enemy.current_health = enemy.max_health
	enemy.knockback_resistance = maxf(enemy.knockback_resistance, float(affix.get("kb_resist", 0.0)))
	enemy.elite_blast_delay = float(affix.get("blast_delay", 0.0))
	enemy.elite_blast_radius = float(affix.get("blast_radius", 0.0))
	enemy.elite_blast_damage = float(affix.get("blast_damage", 0.0))

func _clamp_to_arena(pos: Vector2) -> Vector2:
	var arena := _get_arena_rect().grow(-56.0)
	return Vector2(clampf(pos.x, arena.position.x, arena.end.x), clampf(pos.y, arena.position.y, arena.end.y))

func scale_spawned_minion(enemy: Node) -> void:
	_scale_to_chapter(enemy)

func debug_spawn_pack(kind: String, count: int = 12) -> void:
	if player == null or not is_instance_valid(player):
		return
	_ensure_v2_loader()
	for i in range(count):
		var ang := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.12, 0.12)
		var dist := randf_range(210.0, 310.0)
		var pos := _clamp_to_arena(player.global_position + Vector2(cos(ang), sin(ang)) * dist)
		if kind == "elite":
			_instantiate_enemy_at(pos, Enemy.Type.ELITE, i % 7)
		elif kind == "dummy":
			_instantiate_enemy_at(pos, Enemy.Type.MINION, 2, {"override_hp": 5000.0, "move_speed": 22.0})
		else:
			_instantiate_enemy_at(pos, Enemy.Type.MINION, -1)

func debug_clear_enemies() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemies"):
		if e != null and is_instance_valid(e) and not bool(e.get("is_boss")):
			ObjectPools.release(e)

func _scale_to_chapter(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_boss:
		return
	var base_hp := 32.0
	match enemy.species:
		1: base_hp = 24.0
		2: base_hp = 44.0
		3: base_hp = 30.0
		4: base_hp = 58.0
		5: base_hp = 22.0
		6: base_hp = 46.0
	var time_ramp := 1.0 + _stage_hp_ramp_per_min * (_chapter_elapsed / 60.0)
	var hp := base_hp * _stage_hp_mult * _wave_hp_scale * time_ramp
	if enemy.enemy_type == Enemy.Type.ELITE:
		hp = 110.0 * _stage_hp_mult * _wave_hp_scale * time_ramp
		enemy.exp_gem_value = maxf(20.0, _wave_exp_val * 2.4)
		enemy.exp_gem_count = 4
	else:
		enemy.exp_gem_value = _wave_exp_val
	enemy.max_health = hp
	enemy.current_health = hp
	enemy.speed *= _stage_enemy_speed_mult * _wave_speed_scale

func _cleanup_far_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return
	var arena := _get_arena_rect()
	var cam := _camera_world_rect()
	var pillars := _get_pillars()
	var p_vel := Vector2.ZERO
	if "velocity" in player and (player.velocity as Vector2).length_squared() > 4.0:
		p_vel = player.velocity
	elif "last_move_dir" in player:
		p_vel = (player.last_move_dir as Vector2) * 200.0

	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			var act := _director.compute_recycle_action(e.global_position, player.global_position, p_vel, cam, arena, pillars)
			match String(act["action"]):
				"despawn":
					e.despawn()
				"recycle":
					if not e.is_boss:
						e.global_position = act["pos"] as Vector2

func _get_background() -> Node:
	if _cached_bg != null and is_instance_valid(_cached_bg):
		return _cached_bg
	var tree := get_tree()
	if tree != null:
		_cached_bg = tree.get_first_node_in_group("background")
	return _cached_bg

func _get_arena_rect() -> Rect2:
	var bg := _get_background()
	if bg != null and bg.has_method("get_arena_rect"):
		return bg.get_arena_rect()
	return Rect2(-760.0, -640.0, 2800.0, 2000.0)

func _get_pillars() -> Array:
	var bg := _get_background()
	if bg != null and bg.has_method("get_pillars"):
		return bg.get_pillars()
	return []

func _camera_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(player.global_position - Vector2(640.0, 360.0), Vector2(1280.0, 720.0))
	var vp_size := vp.get_visible_rect().size
	var inv := vp.get_canvas_transform().affine_inverse()
	var tl := inv * Vector2.ZERO
	var br := inv * vp_size
	return Rect2(tl, br - tl).abs()

var _elite_variants_cache: Dictionary = {}

func _get_elite_variant(sp_id: int) -> Dictionary:
	if _elite_variants_cache.is_empty():
		var raw := FileAccess.get_file_as_string("res://data/v2/enemies_waves_v2.json")
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			var ev_map: Variant = (parsed as Dictionary).get("elite_variants", {})
			if ev_map is Dictionary:
				_elite_variants_cache = ev_map as Dictionary
	var key := str(clampi(sp_id, 0, 6))
	var v: Variant = _elite_variants_cache.get(key, {})
	return v as Dictionary if v is Dictionary else {}
