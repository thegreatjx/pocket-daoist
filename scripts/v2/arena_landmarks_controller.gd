class_name ArenaLandmarksController
extends Node2D

signal spirit_array_triggered(pos: Vector2)
signal stele_shattered(pos: Vector2)

enum LandmarkMode { CLASSIC, REALM }
enum VentState { IDLE, WARNING, ERUPTING }
enum SteleState { READY, CHARGING, COOLDOWN }

const CHEST_SCENE := "res://scenes/treasure_chest.tscn"
const ARRAY_TRIGGER_RADIUS := 145.0
const ARRAY_CHARGE_SEC := 2.5
const ARRAY_BUFF_SEC := 8.0

const LAVA_IDLE_SEC := 7.3
const LAVA_WARN_SEC := 1.5
const LAVA_ERUPT_SEC := 1.2
const STELE_CHARGE_SEC := 1.2
const STELE_COOLDOWN_SEC := 25.0
const STELE_AWAKEN_RADIUS := 130.0
const STELE_SEARCH_RADIUS := 560.0

class DemonSealingStele:
	extends Node2D
	signal shattered(pos: Vector2)

	var max_hp: float = 120.0
	var hp: float = 120.0
	var _broken: bool = false
	var _anim_t: float = 0.0

	func _ready() -> void:
		add_to_group("breakables")
		z_index = -1

	func take_damage(amount: float) -> void:
		if _broken:
			return
		hp -= amount
		if hp <= 0.0:
			_broken = true
			shattered.emit(global_position)
			queue_free()

	func _process(delta: float) -> void:
		_anim_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.65 + 0.25 * sin(_anim_t * 3.5)
		draw_set_transform(Vector2(0.0, 20.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 26.0, Color(0.06, 0.05, 0.10, 0.40))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-16.0, -48.0, 32.0, 60.0), Color(0.18, 0.16, 0.24, 1.0))
		draw_rect(Rect2(-16.0, -48.0, 32.0, 60.0), Color(0.86, 0.64, 0.26, pulse), false, 2.2)
		draw_circle(Vector2(0.0, -24.0), 7.0, Color(0.95, 0.28, 0.24, pulse))
		if hp < max_hp:
			var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
			draw_rect(Rect2(-20.0, -58.0, 40.0, 5.0), Color(0.1, 0.1, 0.1, 0.85))
			draw_rect(Rect2(-19.0, -57.0, 38.0 * ratio, 3.0), Color(0.92, 0.30, 0.24, 1.0))

var _mode: LandmarkMode = LandmarkMode.CLASSIC
var _realm_id: String = ""
var _realm_cfg: Dictionary = {}
var _realm_center: Vector2 = Vector2(640.0, 360.0)
var _hazards: Array[Dictionary] = []
var _spring_heal_timer: float = 0.0
var _ice_aura_cd_by_enemy: Dictionary = {}
var _ice_prune_timer: float = 0.0
var _current_wave: int = 1

var spirit_arrays: Array[Dictionary] = []
var demon_steles: Array[Dictionary] = []
var active_array_index: int = -1
var charge_progress: float = 0.0
var array_consumed: bool = false
var active_stele: DemonSealingStele = null

var _bg: Node = null
var _player: Node2D = null
var _spawner: Node = null
var _anim_t: float = 0.0

func _ready() -> void:
	add_to_group("landmarks_controller")
	z_index = -4
	_resolve_refs.call_deferred()

func set_classic_mode() -> void:
	_mode = LandmarkMode.CLASSIC
	_realm_id = ""
	_realm_cfg = {}
	_hazards.clear()
	_ice_aura_cd_by_enemy.clear()
	_spring_heal_timer = 0.0
	if _player != null and is_instance_valid(_player) and "v2_combat" in _player and _player.v2_combat != null:
		_player.v2_combat.set_arena_bonuses({})
	_sync_from_background()
	activate_wave(1)
	queue_redraw()

func apply_realm(realm_id: String, realm_cfg: Dictionary, center: Vector2, hazard_sites: Array[Dictionary]) -> void:
	_mode = LandmarkMode.REALM
	_realm_id = realm_id
	_realm_cfg = realm_cfg.duplicate(true)
	_realm_center = center
	_hazards.clear()
	_ice_aura_cd_by_enemy.clear()
	_spring_heal_timer = 0.0
	if _player != null and is_instance_valid(_player) and "v2_combat" in _player and _player.v2_combat != null:
		_player.v2_combat.set_arena_bonuses({})

	for i in range(hazard_sites.size()):
		var site: Dictionary = hazard_sites[i]
		var htype := String(site.get("type", ""))
		var entry := {
			"id": String(site.get("id", "hz_%d" % i)),
			"type": htype,
			"pos": site.get("pos", center),
			"radius": float(site.get("radius", 155.0)),
			"tick_timer": 0.0,
			"vent_state": VentState.IDLE,
			"vent_timer": fmod(float(i) * 2.5, LAVA_IDLE_SEC),
			"erupt_hit_ids": {},
			"erupt_hit_player": false,
			"stele_state": SteleState.READY,
			"stele_charge": 0.0,
			"stele_cd": 0.0,
		}
		_hazards.append(entry)
	queue_redraw()

func has_active_spirit_array() -> bool:
	if _mode == LandmarkMode.REALM:
		for h in _hazards:
			if String(h.get("type", "")) == "sword_stele" and int(h.get("stele_state", SteleState.COOLDOWN)) == SteleState.READY:
				return true
		return false
	return active_array_index >= 0 and active_array_index < spirit_arrays.size() and not array_consumed

func get_active_spirit_array_pos() -> Vector2:
	if _mode == LandmarkMode.REALM:
		var best_pos := Vector2.ZERO
		var best_d2 := INF
		var ref_pos := _player.global_position if (_player != null and is_instance_valid(_player)) else _realm_center
		for h in _hazards:
			if String(h.get("type", "")) == "sword_stele" and int(h.get("stele_state", SteleState.COOLDOWN)) == SteleState.READY:
				var hp: Vector2 = h["pos"]
				var d2 := hp.distance_squared_to(ref_pos)
				if d2 < best_d2:
					best_d2 = d2
					best_pos = hp
		return best_pos
	if not has_active_spirit_array():
		return Vector2.ZERO
	return spirit_arrays[active_array_index]["pos"]

func setup(bg: Node, player_node: Node2D, spawner_node: Node = null) -> void:
	_bg = bg
	_player = player_node
	_spawner = spawner_node
	_sync_from_background()
	activate_wave(1)

func _resolve_refs() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _bg == null:
		_bg = tree.get_first_node_in_group("background")
	if _player == null:
		_player = tree.get_first_node_in_group("player") as Node2D
	if _spawner == null:
		_spawner = tree.get_first_node_in_group("spawner")
	_sync_from_background()
	if _mode == LandmarkMode.CLASSIC and active_array_index == -1 and not spirit_arrays.is_empty():
		activate_wave(1)

func _sync_from_background() -> void:
	if _bg == null or not _bg.has_method("get_landmarks_by_role"):
		return
	spirit_arrays = _bg.get_landmarks_by_role("spirit_array")
	demon_steles = _bg.get_landmarks_by_role("demon_stele")

func activate_wave(wave: int, _stele_interval: int = 3) -> void:
	_current_wave = maxi(1, wave)
	if _mode == LandmarkMode.REALM:
		return
	if spirit_arrays.is_empty():
		_sync_from_background()
	if not spirit_arrays.is_empty():
		active_array_index = (wave + randi()) % spirit_arrays.size()
	else:
		active_array_index = -1
	charge_progress = 0.0
	array_consumed = false
	queue_redraw()

func spawn_stele(_wave: int = 3) -> DemonSealingStele:
	return null

func _process(delta: float) -> void:
	_anim_t += delta
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	if _mode == LandmarkMode.REALM:
		_step_realm_process(delta)
		queue_redraw()
		return

	if active_array_index >= 0 and active_array_index < spirit_arrays.size() and not array_consumed:
		var arr_pos: Vector2 = spirit_arrays[active_array_index]["pos"]
		if _player.global_position.distance_to(arr_pos) <= ARRAY_TRIGGER_RADIUS:
			charge_progress += delta
			if charge_progress >= ARRAY_CHARGE_SEC:
				_trigger_spirit_array(arr_pos)
		else:
			charge_progress = maxf(0.0, charge_progress - delta * 0.6)
	queue_redraw()

func _step_realm_process(delta: float) -> void:
	var p_pos := _player.global_position
	var v2: V2CombatController = _player.get("v2_combat") as V2CombatController if "v2_combat" in _player else null

	var bonuses := {}
	var arr_r := float(_realm_cfg.get("center_array_radius", 270.0))
	var road_hw := float(_realm_cfg.get("road_half_width", 105.0))
	var half_span := float(_realm_cfg.get("map_size", 4200.0)) * 0.5 - 200.0
	if p_pos.distance_to(_realm_center) <= arr_r:
		bonuses["attack_speed_pct"] = 0.087
		bonuses["pickup_radius_pct"] = 0.20
	else:
		var dx := absf(p_pos.x - _realm_center.x)
		var dy := absf(p_pos.y - _realm_center.y)
		var on_v_road := dx <= road_hw and dy <= half_span
		var on_h_road := dy <= road_hw and dx <= half_span
		if on_v_road or on_h_road:
			bonuses["move_speed_pct"] = 0.05

	var in_spring := false
	for h in _hazards:
		var htype := String(h.get("type", ""))
		var hpos: Vector2 = h["pos"]
		var hrad := float(h.get("radius", 155.0))
		match htype:
			"spring_pool":
				if p_pos.distance_to(hpos) <= hrad:
					in_spring = true
				_step_spring_pool(h, delta, v2)
			"lava_vent":
				_step_lava_vent(h, delta, p_pos, v2)
			"frozen_pond":
				_step_frozen_pond(h, delta, v2)
			"sword_stele":
				_step_sword_stele(h, delta, p_pos, v2)

	if in_spring:
		bonuses["move_speed_pct"] = float(bonuses.get("move_speed_pct", 0.0)) + 0.06
		_spring_heal_timer += delta
		if _spring_heal_timer >= 3.0:
			_spring_heal_timer = 0.0
			if _player.has_method("heal"):
				var mhp := float(_player.get("max_health")) if "max_health" in _player else 120.0
				_player.heal(mhp * 0.02)
	else:
		_spring_heal_timer = 0.0

	if v2 != null:
		v2.set_arena_bonuses(bonuses)

	_ice_prune_timer += delta
	if _ice_prune_timer >= 3.0:
		_ice_prune_timer = 0.0
		var now_s := float(Time.get_ticks_msec()) * 0.001
		for eid in _ice_aura_cd_by_enemy.keys():
			if float(_ice_aura_cd_by_enemy[eid]) <= now_s:
				_ice_aura_cd_by_enemy.erase(eid)

func _step_spring_pool(h: Dictionary, delta: float, v2: V2CombatController) -> void:
	h["tick_timer"] = float(h.get("tick_timer", 0.0)) + delta
	if float(h["tick_timer"]) < 0.45:
		return
	h["tick_timer"] = 0.0
	if v2 == null:
		return
	var hpos: Vector2 = h["pos"]
	var hrad := float(h.get("radius", 160.0))
	for e in _query_enemies(hpos, hrad):
		v2.apply_environment_aura(e, "water", 5.0)

func _step_lava_vent(h: Dictionary, delta: float, p_pos: Vector2, v2: V2CombatController) -> void:
	var st := int(h.get("vent_state", VentState.IDLE))
	var t := float(h.get("vent_timer", 0.0)) + delta
	var hpos: Vector2 = h["pos"]
	var hrad := float(h.get("radius", 155.0))
	match st:
		VentState.IDLE:
			if t >= LAVA_IDLE_SEC:
				h["vent_state"] = VentState.WARNING
				h["vent_timer"] = 0.0
			else:
				h["vent_timer"] = t
		VentState.WARNING:
			if t >= LAVA_WARN_SEC:
				h["vent_state"] = VentState.ERUPTING
				h["vent_timer"] = 0.0
				h["erupt_hit_ids"] = {}
				h["erupt_hit_player"] = false
				var parent_n := get_parent()
				if parent_n != null:
					V2VfxFactory.spawn_boss_shockwave(parent_n, hpos, hrad, Color(0.98, 0.36, 0.14, 0.88), Color(1.0, 0.84, 0.36, 0.90), 0.45)
				if has_node("/root/Sfx"):
					get_node("/root/Sfx").call("play", "fire_gourd_burn", -6.0)
				_apply_lava_eruption_hits(h, hpos, hrad, p_pos, v2)
			else:
				h["vent_timer"] = t
		VentState.ERUPTING:
			_apply_lava_eruption_hits(h, hpos, hrad, p_pos, v2)
			if t >= LAVA_ERUPT_SEC:
				h["vent_state"] = VentState.IDLE
				h["vent_timer"] = 0.0
			else:
				h["vent_timer"] = t

func _apply_lava_eruption_hits(h: Dictionary, hpos: Vector2, hrad: float, p_pos: Vector2, v2: V2CombatController) -> void:
	if not bool(h.get("erupt_hit_player", false)) and p_pos.distance_to(hpos) <= hrad:
		h["erupt_hit_player"] = true
		if _player.has_method("take_damage"):
			var mhp := float(_player.get("max_health")) if "max_health" in _player else 120.0
			_player.take_damage(maxf(4.0, roundf(mhp * 0.06)))
	if v2 != null:
		var hit_map: Dictionary = h.get("erupt_hit_ids", {})
		var dmg := 45.0 * (1.0 + float(_current_wave - 1) * 0.12)
		for e in _query_enemies(hpos, hrad):
			var eid := e.get_instance_id()
			if hit_map.has(eid):
				continue
			hit_map[eid] = true
			v2.apply_environment_hit(e, dmg, "fire", {"allow_reaction": true})

func _step_frozen_pond(h: Dictionary, delta: float, v2: V2CombatController) -> void:
	h["tick_timer"] = float(h.get("tick_timer", 0.0)) + delta
	if float(h["tick_timer"]) < 0.50:
		return
	h["tick_timer"] = 0.0
	var hpos: Vector2 = h["pos"]
	var hrad := float(h.get("radius", 160.0))
	var now_s := float(Time.get_ticks_msec()) * 0.001
	for e in _query_enemies(hpos, hrad):
		if e.has_method("apply_slow"):
			e.apply_slow(0.20, 1.2)
		if v2 != null:
			var eid := e.get_instance_id()
			if now_s >= float(_ice_aura_cd_by_enemy.get(eid, 0.0)):
				_ice_aura_cd_by_enemy[eid] = now_s + 1.5
				v2.apply_environment_aura(e, "ice", 3.5)

func _step_sword_stele(h: Dictionary, delta: float, p_pos: Vector2, v2: V2CombatController) -> void:
	var st := int(h.get("stele_state", SteleState.READY))
	var hpos: Vector2 = h["pos"]
	match st:
		SteleState.COOLDOWN:
			var rem := float(h.get("stele_cd", 0.0)) - delta
			if rem <= 0.0:
				h["stele_state"] = SteleState.READY
				h["stele_cd"] = 0.0
				h["stele_charge"] = 0.0
			else:
				h["stele_cd"] = rem
		SteleState.READY, SteleState.CHARGING:
			if p_pos.distance_to(hpos) <= STELE_AWAKEN_RADIUS:
				var ch := float(h.get("stele_charge", 0.0)) + delta
				h["stele_charge"] = ch
				h["stele_state"] = SteleState.CHARGING
				if ch >= STELE_CHARGE_SEC:
					_fire_sword_stele_salvo(hpos, v2)
					h["stele_state"] = SteleState.COOLDOWN
					h["stele_cd"] = STELE_COOLDOWN_SEC
					h["stele_charge"] = 0.0
			else:
				var ch := maxf(0.0, float(h.get("stele_charge", 0.0)) - delta * 0.8)
				h["stele_charge"] = ch
				h["stele_state"] = SteleState.CHARGING if ch > 0.0 else SteleState.READY

func _fire_sword_stele_salvo(origin: Vector2, v2: V2CombatController) -> void:
	var candidates := _query_enemies(origin, STELE_SEARCH_RADIUS)
	if not candidates.is_empty():
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			var af := bool(a.is_frozen()) if a.has_method("is_frozen") else false
			var bf := bool(b.is_frozen()) if b.has_method("is_frozen") else false
			if af != bf:
				return af
			return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin)
		)
	var parent_n := get_parent()
	var dmg := 65.0 * (1.0 + float(_current_wave - 1) * 0.14)
	var shot_count := 7
	for i in range(shot_count):
		var target_e: Node2D = candidates[i % candidates.size()] if not candidates.is_empty() else null
		var dest := target_e.global_position if target_e != null else origin + Vector2.from_angle(TAU * float(i) / float(shot_count)) * 320.0
		if parent_n != null:
			V2VfxFactory.spawn_hit_spark(parent_n, dest, "metal", true, Color(1.0, 0.88, 0.36, 0.94))
		if target_e != null and v2 != null:
			v2.apply_environment_hit(target_e, dmg, "metal", {"allow_reaction": true})
	if v2 != null:
		v2.play_v2_cue("sfx_sword_whoosh", "weapon", 1.05)
	var tree := get_tree()
	if tree != null:
		tree.call_group("ui", "show_banner", "【无主古剑碑唤醒 · 万剑破罡！】")

func _query_enemies(center: Vector2, radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var tree := get_tree()
	if tree == null:
		return out
	var r2 := radius * radius
	for n in tree.get_nodes_in_group("enemies"):
		if n != null and is_instance_valid(n) and n is Node2D and not bool(n.get("is_dead")):
			var e := n as Node2D
			if e.global_position.distance_squared_to(center) <= r2:
				out.append(e)
	return out

func _trigger_spirit_array(arr_pos: Vector2) -> void:
	array_consumed = true
	charge_progress = ARRAY_CHARGE_SEC
	if _player.has_method("apply_temp_buff"):
		_player.apply_temp_buff(6.0, 0.25, ARRAY_BUFF_SEC)
	if _player.has_method("heal"):
		var max_hp: float = float(_player.get("max_health")) if "max_health" in _player else 100.0
		_player.heal(max_hp * 0.15)
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").call("play", "level_up", -4.0)
	var tree := get_tree()
	if tree != null:
		tree.call_group("ui", "show_banner", "【聚灵阵共鸣】回血 15% · 伤害 +25% · 攻速 +30%（持续 8 秒）")
	spirit_array_triggered.emit(arr_pos)

func _on_stele_shattered(pos: Vector2) -> void:
	active_stele = null
	var parent_node: Node = get_parent() if get_parent() != null else self
	if ResourceLoader.exists(CHEST_SCENE):
		var chest_scene := load(CHEST_SCENE) as PackedScene
		if chest_scene != null:
			var chest := chest_scene.instantiate() as Node2D
			chest.global_position = pos + Vector2(0.0, 68.0)
			parent_node.call_deferred("add_child", chest)
	if has_node("/root/Stats"):
		get_node("/root/Stats").call("add_spirit_stones", 15)
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0
		var e_type := Enemy.Type.ELITE if i == 0 else Enemy.Type.MINION
		var dist := 260.0 if i == 0 else 200.0
		var delay := 1.25 if i == 0 else 0.95
		var raid_pos: Vector2 = pos + Vector2(cos(ang), sin(ang)) * dist
		if _spawner != null and _spawner.has_method("spawn_telegraphed_enemy"):
			_spawner.spawn_telegraphed_enemy(raid_pos, e_type, delay)
		else:
			var tele := SpawnTelegraph.new()
			tele.setup(raid_pos, delay, 42.0 if e_type == Enemy.Type.ELITE else 30.0, Callable())
			parent_node.add_child(tele)
	var tree := get_tree()
	if tree != null:
		tree.call_group("ui", "show_banner", "【镇魔碑碎裂 · 天机宝箱降世！】")
	stele_shattered.emit(pos)

func _draw() -> void:
	if _mode == LandmarkMode.REALM:
		_draw_realm_hazards()
		return
	if active_array_index < 0 or active_array_index >= spirit_arrays.size() or array_consumed:
		return
	var pos: Vector2 = spirit_arrays[active_array_index]["pos"]
	var pulse: float = 0.65 + 0.35 * sin(_anim_t * 4.0)
	draw_circle(pos, ARRAY_TRIGGER_RADIUS, Color(0.18, 0.88, 0.72, 0.14 * pulse))
	draw_arc(pos, ARRAY_TRIGGER_RADIUS, 0.0, TAU, 48, Color(0.28, 0.96, 0.80, 0.55 * pulse), 2.8)
	if charge_progress > 0.0:
		var ratio: float = clampf(charge_progress / ARRAY_CHARGE_SEC, 0.0, 1.0)
		draw_arc(pos, ARRAY_TRIGGER_RADIUS * 0.78, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, Color(0.98, 0.86, 0.36, 0.88), 4.5)
	_draw_world_label(pos, ARRAY_TRIGGER_RADIUS,
		"聚灵充能中 %.1fs" % maxf(0.0, ARRAY_CHARGE_SEC - charge_progress) if charge_progress > 0.0 else "聚灵阵（站入 2.5 秒触发）",
		"回血15% · 伤害+25% · 攻速+30%",
		Color(0.98, 0.92, 0.45, 0.98),
		Color(0.42, 0.98, 0.84, 0.96)
	)

func _draw_realm_hazards() -> void:
	var arr_r := float(_realm_cfg.get("center_array_radius", 270.0))
	if _player != null and is_instance_valid(_player) and _player.global_position.distance_to(_realm_center) <= arr_r:
		var pulse := 0.65 + 0.35 * sin(_anim_t * 4.0)
		draw_arc(_realm_center, arr_r, 0.0, TAU, 56, Color(0.32, 0.96, 0.80, 0.48 * pulse), 2.8)

	for h in _hazards:
		var htype := String(h.get("type", ""))
		var pos: Vector2 = h["pos"]
		var rad := float(h.get("radius", 155.0))
		match htype:
			"spring_pool":
				var pulse := 0.55 + 0.35 * sin(_anim_t * 2.8)
				draw_arc(pos, rad * 0.86, 0.0, TAU, 40, Color(0.36, 0.90, 0.98, 0.35 * pulse), 2.2)
				_draw_world_label(pos, rad, "灵露清泉", "踩入挂水 · 移速+6% · 缓回血", Color(0.56, 0.96, 1.0, 0.96), Color(0.74, 0.98, 0.88, 0.92))
			"lava_vent":
				var st := int(h.get("vent_state", VentState.IDLE))
				var t := float(h.get("vent_timer", 0.0))
				if st == VentState.WARNING:
					var frac := clampf(t / LAVA_WARN_SEC, 0.0, 1.0)
					draw_circle(pos, rad * frac, Color(0.98, 0.24, 0.12, 0.24))
					draw_arc(pos, rad, 0.0, TAU, 40, Color(1.0, 0.34, 0.16, 0.88), 3.2)
				elif st == VentState.ERUPTING:
					draw_circle(pos, rad, Color(1.0, 0.44, 0.12, 0.30))
					draw_arc(pos, rad, 0.0, TAU, 40, Color(1.0, 0.80, 0.28, 0.92), 3.6)
				else:
					draw_arc(pos, rad, 0.0, TAU, 36, Color(0.96, 0.45, 0.20, 0.22), 1.6)
			"frozen_pond":
				var pulse := 0.55 + 0.35 * sin(_anim_t * 2.4)
				draw_arc(pos, rad * 0.88, 0.0, TAU, 40, Color(0.54, 0.88, 1.0, 0.36 * pulse), 2.2)
				_draw_world_label(pos, rad, "寒潭薄冰", "妖物减速20% · 周期挂冰", Color(0.72, 0.94, 1.0, 0.96), Color(0.84, 0.96, 1.0, 0.90))
			"sword_stele":
				var st := int(h.get("stele_state", SteleState.READY))
				if st == SteleState.COOLDOWN:
					var cd_ratio := 1.0 - clampf(float(h.get("stele_cd", 0.0)) / STELE_COOLDOWN_SEC, 0.0, 1.0)
					draw_arc(pos, STELE_AWAKEN_RADIUS, 0.0, TAU, 40, Color(0.45, 0.58, 0.68, 0.28), 2.0)
					draw_arc(pos, STELE_AWAKEN_RADIUS * 0.82, -PI * 0.5, -PI * 0.5 + TAU * cd_ratio, 40, Color(0.56, 0.82, 0.96, 0.55), 3.0)
					_draw_world_label(pos, STELE_AWAKEN_RADIUS, "剑碑蓄势中 %.0fs" % float(h.get("stele_cd", 0.0)), "蓄满后可再度齐射金剑", Color(0.76, 0.88, 0.96, 0.92), Color(0.64, 0.80, 0.90, 0.86))
				else:
					var pulse := 0.65 + 0.35 * sin(_anim_t * 3.8)
					draw_circle(pos, STELE_AWAKEN_RADIUS, Color(0.96, 0.82, 0.32, 0.12 * pulse))
					draw_arc(pos, STELE_AWAKEN_RADIUS, 0.0, TAU, 44, Color(1.0, 0.86, 0.38, 0.62 * pulse), 2.8)
					var ch := float(h.get("stele_charge", 0.0))
					if ch > 0.0:
						draw_arc(pos, STELE_AWAKEN_RADIUS * 0.78, -PI * 0.5, -PI * 0.5 + TAU * clampf(ch / STELE_CHARGE_SEC, 0.0, 1.0), 44, Color(1.0, 0.92, 0.45, 0.95), 4.5)
					_draw_world_label(pos, STELE_AWAKEN_RADIUS,
						"唤醒中 %.1fs" % maxf(0.0, STELE_CHARGE_SEC - ch) if ch > 0.0 else "无主古剑碑（停留 1.2s 唤醒）",
						"齐射金剑 · 优先碎冰削盾35%",
						Color(1.0, 0.92, 0.48, 0.98),
						Color(0.68, 0.94, 1.0, 0.94)
					)

func _draw_world_label(pos: Vector2, rad: float, main_txt: String, sub_txt: String, main_col: Color, sub_col: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	if _player != null and is_instance_valid(_player) and _player.global_position.distance_to(pos) > 480.0:
		return
	var vp := get_viewport()
	if vp != null:
		var inv := vp.get_canvas_transform().affine_inverse()
		var view_tl := inv * Vector2.ZERO
		var view_br := inv * vp.get_visible_rect().size
		var vis_rect := Rect2(view_tl, view_br - view_tl).abs()
		if not vis_rect.grow(-24.0).has_point(pos):
			return
	var main_pos := pos + Vector2(-130.0, -rad - 26.0)
	var sub_pos := pos + Vector2(-130.0, -rad - 8.0)
	draw_string(font, main_pos + Vector2(1.0, 1.0), main_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 16, Color(0.04, 0.10, 0.09, 0.92))
	draw_string(font, main_pos, main_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 16, main_col)
	draw_string(font, sub_pos + Vector2(1.0, 1.0), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 13, Color(0.04, 0.10, 0.09, 0.92))
	draw_string(font, sub_pos, sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 260.0, 13, sub_col)
