class_name V2SpawnDirector
extends RefCounted

const OFFSCREEN_MIN := 120.0
const OFFSCREEN_MAX := 240.0
const TELEGRAPH_SEC := 0.8
const RECYCLE_SCREEN_MULT := 1.8
const EXTREME_DESPAWN_DIST := 3000.0
const BREATHER_DURATION := 10.0

const SUBWAVE_BEAT_SEC := 8.0

enum Formation {
	SCATTER_RING,
	SHIELD_KITER_SQUAD,
	ENCIRCLEMENT_RING,
	BREATHER,
}

class WavePulseFx:
	extends Node2D

	var duration: float = 0.85
	var elapsed: float = 0.0
	var max_radius: float = 620.0
	var _ring_sprite: Sprite2D = null
	var _ring_mat: ShaderMaterial = null
	var _core_sprite: Sprite2D = null

	func _ready() -> void:
		add_to_group("v2_transient_vfx")
		z_index = 6

		_ring_sprite = V2VfxFactory.make_shader_sprite(
			V2VfxFactory.TEX_MAGIC_04,
			V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE,
			{
				"primary_color": Color(1.0, 0.88, 0.42, 1.0),
				"accent_color": Color(0.42, 0.96, 0.82, 1.0),
				"progress": 0.08,
				"ring_width": 0.14,
				"petal_count": 8.0,
				"spin_speed": 1.6,
				"alpha_limit": 0.86,
				"is_wave": 1.0,
				"fade": 1.0,
			},
			max_radius * 2.0
		)
		_ring_mat = _ring_sprite.material as ShaderMaterial
		add_child(_ring_sprite)

		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

		_core_sprite = Sprite2D.new()
		_core_sprite.texture = V2VfxFactory.TEX_FLARE_01
		_core_sprite.modulate = Color(1.0, 0.92, 0.56, 0.82)
		_core_sprite.material = add_mat
		_core_sprite.scale = Vector2.ONE * 0.45
		add_child(_core_sprite)

		var burst := GPUParticles2D.new()
		burst.texture = V2VfxFactory.TEX_STAR_06
		burst.amount = 24
		burst.lifetime = 0.72
		burst.one_shot = true
		burst.explosiveness = 0.88
		burst.emitting = true
		var pmat := ParticleProcessMaterial.new()
		pmat.particle_flag_disable_z = true
		pmat.spread = 180.0
		pmat.initial_velocity_min = 190.0
		pmat.initial_velocity_max = 420.0
		pmat.gravity = Vector3.ZERO
		pmat.damping_min = 180.0
		pmat.damping_max = 280.0
		pmat.scale_min = 0.08
		pmat.scale_max = 0.18
		pmat.color_ramp = _build_pulse_ramp()
		burst.process_material = pmat
		burst.material = add_mat
		add_child(burst)

	func _build_pulse_ramp() -> GradientTexture1D:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.96, 0.65, 1.0))
		g.add_point(0.45, Color(0.48, 0.98, 0.84, 0.85))
		g.set_color(1, Color(0.35, 0.88, 0.95, 0.0))
		var tex := GradientTexture1D.new()
		tex.gradient = g
		return tex

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= duration:
			queue_free()
			return
		var t := clampf(elapsed / maxf(0.01, duration), 0.0, 1.0)
		var ease_t := 1.0 - pow(1.0 - t, 2.2)
		var fade := 1.0 - pow(t, 1.35)
		if _ring_mat != null:
			_ring_mat.set_shader_parameter("progress", clampf(0.08 + 0.92 * ease_t, 0.0, 1.0))
			_ring_mat.set_shader_parameter("fade", fade)
		if _core_sprite != null:
			_core_sprite.scale = Vector2.ONE * (0.45 + ease_t * 1.4)
			_core_sprite.modulate.a = (1.0 - t) * 0.72

var budget: float = 0.0
var formation: int = Formation.SCATTER_RING
var formation_timer: float = 14.0
var formation_cycle: int = 0
var _queued_arch_id: String = ""
var _last_subwave_beat: int = -1
var _spawn_seq: int = 0

func reset() -> void:
	budget = 0.0
	formation = Formation.SCATTER_RING
	formation_timer = 14.0
	formation_cycle = 0
	_spawn_seq = 0
	reset_queue()

func reset_queue() -> void:
	_queued_arch_id = ""
	_last_subwave_beat = -1

func apply_subwave_cadence(pool_archetypes: Array, wave_elapsed: float) -> Array:
	var n := pool_archetypes.size()
	if n <= 1:
		return pool_archetypes
	var solo_count := mini(n, 4)
	var cycle_len := solo_count + 1
	var beat_idx := int(floor(maxf(0.0, wave_elapsed) / SUBWAVE_BEAT_SEC))
	if beat_idx != _last_subwave_beat:
		_last_subwave_beat = beat_idx
		_queued_arch_id = ""
	var slot := beat_idx % cycle_len
	if slot >= solo_count:
		return pool_archetypes
	var featured_idx := slot if n <= solo_count else ((beat_idx / cycle_len) * solo_count + slot) % n
	var other_total := 0.0
	for i in range(n):
		if i != featured_idx:
			other_total += maxf(0.05, float((pool_archetypes[i] as Dictionary).get("_spawn_weight", 1.0)))
	var adjusted: Array = []
	for i in range(n):
		var arch: Dictionary = (pool_archetypes[i] as Dictionary).duplicate()
		if i == featured_idx:
			arch["_spawn_weight"] = 0.85
		else:
			var base_w := maxf(0.05, float(arch.get("_spawn_weight", 1.0)))
			arch["_spawn_weight"] = 0.15 * (base_w / maxf(0.05, other_total))
		adjusted.append(arch)
	return adjusted

static func budget_per_sec(wave: int) -> float:
	return 2.2 + 0.65 * float(maxi(0, wave - 1))

static func calc_curse_spawn_mult(curse_pct: float) -> float:
	return 1.0 + maxf(0.0, curse_pct) * 0.5

static func calc_curse_hp_mult(curse_pct: float) -> float:
	return 1.0 + maxf(0.0, curse_pct)

func advance_formation(delta: float) -> int:
	formation_timer -= delta
	if formation_timer <= 0.0:
		formation_cycle = (formation_cycle + 1) % 4
		match formation_cycle:
			0:
				formation = Formation.SCATTER_RING
				formation_timer = 14.0
			1:
				formation = Formation.SHIELD_KITER_SQUAD
				formation_timer = 10.0
			2:
				formation = Formation.ENCIRCLEMENT_RING
				formation_timer = 8.0
			_:
				formation = Formation.BREATHER
				formation_timer = BREATHER_DURATION
	return formation

func _pick_weighted(candidates: Array) -> Dictionary:
	var total_w := 0.0
	for a in candidates:
		total_w += maxf(0.05, float((a as Dictionary).get("_spawn_weight", 1.0)))
	var roll := randf() * maxf(0.05, total_w)
	var acc := 0.0
	for a in candidates:
		var cand := a as Dictionary
		acc += maxf(0.05, float(cand.get("_spawn_weight", 1.0)))
		if roll <= acc:
			return cand
	return candidates[candidates.size() - 1] as Dictionary

func step_budget(delta: float, wave: int, pool_archetypes: Array, budget_rate_override: float = -1.0) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	if formation == Formation.BREATHER or pool_archetypes.is_empty():
		return requests

	var rate := budget_rate_override if budget_rate_override >= 0.0 else budget_per_sec(wave)
	budget += rate * maxf(0.0, delta)

	var spawned: int = 0
	while spawned < 4:
		var pick: Dictionary = {}
		if _queued_arch_id != "":
			for a in pool_archetypes:
				var arch := a as Dictionary
				if String(arch.get("id", "")) == _queued_arch_id:
					pick = arch
					break
			if pick.is_empty():
				_queued_arch_id = ""

		if pick.is_empty():
			if _spawn_seq == 0:
				var affordable: Array = []
				for a in pool_archetypes:
					var arch := a as Dictionary
					if maxf(0.5, float(arch.get("spawn_cost", 1.0))) <= budget:
						affordable.append(arch)
				pick = _pick_weighted(affordable if not affordable.is_empty() else pool_archetypes)
			else:
				pick = _pick_weighted(pool_archetypes)
			_queued_arch_id = String(pick.get("id", ""))

		var cost: float = maxf(0.5, float(pick.get("spawn_cost", 1.0)))
		if budget < cost:
			break
		budget -= cost
		_queued_arch_id = ""
		_spawn_seq += 1
		requests.append({"archetype": pick, "formation": formation})
		spawned += 1
	return requests

func pick_spawn_point(
	arena_rect: Rect2,
	camera_rect: Rect2,
	player_pos: Vector2,
	pillars: Array,
	force_telegraph: bool = false,
	min_telegraph_dist: float = 240.0
) -> Dictionary:
	var safe_arena := arena_rect.grow(-48.0)
	if not force_telegraph:
		var side: int = randi() % 4
		for _attempt in range(3):
			var cand: Vector2 = _sample_offscreen_side(camera_rect, side)
			if safe_arena.has_point(cand) and not EnemySteeringDirector.check_pillar_collision(cand, 24.0, pillars, 12.0):
				return {"pos": cand, "use_telegraph": false, "telegraph_sec": 0.0}

	var tele_pos := _sample_telegraph_point(arena_rect.grow(-64.0), player_pos, pillars, min_telegraph_dist)
	return {"pos": tele_pos, "use_telegraph": true, "telegraph_sec": TELEGRAPH_SEC}

func _sample_offscreen_side(camera_rect: Rect2, side: int) -> Vector2:
	var pad := randf_range(OFFSCREEN_MIN, OFFSCREEN_MAX)
	match side:
		0:
			return Vector2(
				randf_range(camera_rect.position.x - OFFSCREEN_MAX, camera_rect.end.x + OFFSCREEN_MAX),
				camera_rect.position.y - pad
			)
		1:
			return Vector2(
				randf_range(camera_rect.position.x - OFFSCREEN_MAX, camera_rect.end.x + OFFSCREEN_MAX),
				camera_rect.end.y + pad
			)
		2:
			return Vector2(
				camera_rect.position.x - pad,
				randf_range(camera_rect.position.y - OFFSCREEN_MAX, camera_rect.end.y + OFFSCREEN_MAX)
			)
		_:
			return Vector2(
				camera_rect.end.x + pad,
				randf_range(camera_rect.position.y - OFFSCREEN_MAX, camera_rect.end.y + OFFSCREEN_MAX)
			)

func _sample_telegraph_point(inner_arena: Rect2, player_pos: Vector2, pillars: Array, min_telegraph_dist: float = 220.0) -> Vector2:
	var min_d := maxf(220.0, min_telegraph_dist)
	var max_d := maxf(min_d + 160.0, 420.0)
	for _i in range(16):
		var ang := randf() * TAU
		var dist := randf_range(min_d, max_d)
		var cand := player_pos + Vector2(cos(ang), sin(ang)) * dist
		if inner_arena.has_point(cand) and not EnemySteeringDirector.check_pillar_collision(cand, 28.0, pillars, 12.0):
			return cand

	var to_center := (inner_arena.get_center() - player_pos)
	var dir := to_center.normalized() if to_center.length_squared() > 1.0 else Vector2.RIGHT
	var fallback := player_pos + dir * maxf(260.0, min_d)
	return Vector2(
		clampf(fallback.x, inner_arena.position.x, inner_arena.end.x),
		clampf(fallback.y, inner_arena.position.y, inner_arena.end.y)
	)

func build_formation_offsets(kind: int, center_pos: Vector2, player_pos: Vector2, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = maxi(1, count)
	var to_p := (player_pos - center_pos)
	var forward := to_p.normalized() if to_p.length_squared() > 1.0 else Vector2.RIGHT
	var right := Vector2(-forward.y, forward.x)

	match kind:
		Formation.SHIELD_KITER_SQUAD:
			var front_n: int = maxi(1, n / 2)
			for i in range(n):
				if i < front_n:
					var lat := (float(i) - float(front_n - 1) * 0.5) * 44.0
					out.append({"pos": center_pos + forward * 34.0 + right * lat, "role": "shield"})
				else:
					var back_i := i - front_n
					var back_n := maxi(1, n - front_n)
					var lat_b := (float(back_i) - float(back_n - 1) * 0.5) * 52.0
					out.append({"pos": center_pos - forward * 48.0 + right * lat_b, "role": "kiter"})
		Formation.ENCIRCLEMENT_RING:
			for i in range(n):
				var ang := (float(i) / float(n)) * TAU
				out.append({"pos": player_pos + Vector2(cos(ang), sin(ang)) * 480.0, "role": "swarm"})
		_:
			for i in range(n):
				var ang_s := randf() * TAU
				out.append({"pos": center_pos + Vector2(cos(ang_s), sin(ang_s)) * randf_range(0.0, 56.0), "role": "swarm"})
	return out

func compute_recycle_action(
	enemy_pos: Vector2,
	player_pos: Vector2,
	player_vel: Vector2,
	camera_rect: Rect2,
	arena_rect: Rect2,
	pillars: Array
) -> Dictionary:
	var dist := enemy_pos.distance_to(player_pos)
	if dist > EXTREME_DESPAWN_DIST:
		return {"action": "despawn"}

	var recycle_dist := maxf(camera_rect.size.y, 720.0) * RECYCLE_SCREEN_MULT
	if dist <= recycle_dist:
		return {"action": "keep"}

	var forward := player_vel.normalized() if player_vel.length_squared() > 4.0 else (player_pos - enemy_pos).normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var base_ang := forward.angle()
	var half_w := maxf(320.0, camera_rect.size.x * 0.5)
	var half_h := maxf(180.0, camera_rect.size.y * 0.5)
	var safe_arena := arena_rect.grow(-48.0)

	for _i in range(12):
		var ang := base_ang + randf_range(-1.05, 1.05)
		var dir := Vector2(cos(ang), sin(ang))
		var edge_x := half_w / maxf(0.15, absf(dir.x))
		var edge_y := half_h / maxf(0.15, absf(dir.y))
		var r := minf(edge_x, edge_y) + randf_range(OFFSCREEN_MIN, OFFSCREEN_MAX)
		var cand := player_pos + dir * r
		if safe_arena.has_point(cand) and not EnemySteeringDirector.check_pillar_collision(cand, 24.0, pillars, 12.0):
			return {"action": "recycle", "pos": cand}

	return {"action": "keep"}

static func trigger_wave_end_vacuum(tree: SceneTree, player: Node2D) -> Dictionary:
	var vacuumed: int = 0
	if tree == null:
		return {"despawned": 0, "banished": 0, "knocked_elites": 0, "gold_gained": 0, "gems_spawned": 0, "vacuumed": 0}

	var has_player := player != null and is_instance_valid(player)
	if has_player:
		for st in tree.get_nodes_in_group("spirit_stones"):
			if st != null and is_instance_valid(st) and st.has_method("attract_to"):
				st.attract_to(player)
				vacuumed += 1
	return {
		"despawned": 0,
		"banished": 0,
		"knocked_elites": 0,
		"gold_gained": 0,
		"gems_spawned": 0,
		"vacuumed": vacuumed,
	}
