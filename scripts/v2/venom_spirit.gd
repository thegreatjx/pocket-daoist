class_name VenomSpirit
extends Node2D

const RETARGET_INTERVAL := 0.22
const SEARCH_RADIUS := 340.0
const HIT_RADIUS := 26.0
const MAX_LIFETIME := 3.2

var controller: Node = null
var damage: float = 10.0
var speed: float = 380.0
var max_range: float = 400.0
var dot_dps: float = 10.0
var dot_dur: float = 4.0
var spread_radius: float = 110.0
var spread_targets: int = 3
var color: Color = Color(0.20, 0.83, 0.60, 1.0)
var halo_color: Color = Color(0.65, 0.55, 0.98, 1.0)
var is_max_tier: bool = false

var elapsed: float = 0.0
var travelled: float = 0.0
var _dir: Vector2 = Vector2.RIGHT
var _target: Node2D = null
var _retarget_timer: float = 0.0
var _trail: Array[Vector2] = []
var _trail_line: Line2D = null
var _core: Sprite2D = null
var _halo: Sprite2D = null
var _wisp: Sprite2D = null
var _wisp_echo: Sprite2D = null
var _glow: Sprite2D = null
var _wisp_base: Vector2 = Vector2.ONE
var _trail_limit: int = 9
var _done: bool = false

func _ready() -> void:
	add_to_group("venom_spirits")
	z_index = 5

func setup(
	ctrl: Node,
	origin: Vector2,
	direction: Vector2,
	target_pos: Vector2,
	dmg: float,
	spd: float,
	rng: float,
	dps: float,
	dur: float,
	spirit_col: Color,
	halo_col: Color,
	spread_r: float,
	max_targets: int,
	maxed: bool = false
) -> void:
	controller = ctrl
	global_position = origin
	_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	damage = dmg
	speed = spd
	max_range = rng
	dot_dps = dps
	dot_dur = dur
	color = spirit_col
	halo_color = halo_col
	spread_radius = spread_r
	spread_targets = clampi(max_targets, 1, 3)
	is_max_tier = maxed
	_target = _acquire_target(target_pos, 260.0)
	_build_visuals()

func _build_visuals() -> void:
	_trail_line = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 15.0, {
		"primary_color": Color(color.r, color.g, color.b, 0.72),
		"edge_color": Color(0.86, 0.94, 1.0, 0.95),
		"intensity": 1.30,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.05, 1.0))
	_trail_line.top_level = true
	_trail_line.z_index = 3
	add_child(_trail_line)

	_glow = V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, 54.0 if is_max_tier else 46.0, Color(color.r, color.g, color.b, 0.42), true)
	add_child(_glow)

	_halo = V2VfxFactory.make_sprite(V2VfxFactory.TEX_TWIRL_03, 56.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.62), true)
	add_child(_halo)

	_core = V2VfxFactory.make_sprite(V2VfxFactory.TEX_SMOKE_07, 42.0, Color(color.r * 0.8, color.g, color.b * 0.9, 0.88), false)
	add_child(_core)

	_wisp = V2VfxFactory.make_sprite(V2VfxFactory.TEX_SPARK_06, 24.0, Color(0.82, 1.0, 0.88, 0.95), true)
	_wisp_base = _wisp.scale
	add_child(_wisp)

	if is_max_tier:
		_trail_limit = 14
		_trail_line.width = 21.0
		_wisp_echo = V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_09, 20.0, Color(0.86, 0.62, 1.0, 0.88), true)
		add_child(_wisp_echo)
		var aura := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.42, 0.96, 0.44, 0.88),
			"accent_color": Color(0.80, 0.56, 1.0, 1.0),
			"petal_count": 6.0,
			"spin_speed": 2.6,
			"alpha_limit": 0.44,
			"is_wave": 0.0,
		}, 74.0)
		add_child(aura)

	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
		"amount": 10,
		"lifetime": 0.42,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 8.0,
		"vel_max": 34.0,
		"scale_min": 0.04,
		"scale_max": 0.09,
		"additive": false,
		"color_start": Color(color.r, color.g, color.b, 0.46),
		"color_end": Color(halo_color.r, halo_color.g, halo_color.b, 0.0),
	}))
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
		"amount": 8,
		"lifetime": 0.32,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 16.0,
		"vel_max": 52.0,
		"scale_min": 0.025,
		"scale_max": 0.055,
		"color_start": Color(0.72, 1.0, 0.82, 0.92),
		"color_end": Color(halo_color.r, halo_color.g, halo_color.b, 0.0),
	}))

	if is_max_tier:
		add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
			"amount": 16,
			"lifetime": 0.55,
			"one_shot": false,
			"local_coords": false,
			"vel_min": 12.0,
			"vel_max": 44.0,
			"scale_min": 0.05,
			"scale_max": 0.12,
			"additive": false,
			"color_start": Color(0.50, 0.92, 0.34, 0.52),
			"color_end": Color(0.62, 0.38, 0.96, 0.0),
		}))
		add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_09, {
			"amount": 12,
			"lifetime": 0.40,
			"one_shot": false,
			"local_coords": false,
			"vel_min": 24.0,
			"vel_max": 78.0,
			"scale_min": 0.025,
			"scale_max": 0.06,
			"color_start": Color(0.90, 1.0, 0.66, 0.92),
			"color_end": Color(0.70, 0.44, 1.0, 0.0),
		}))

func _acquire_target(from_pos: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_score := radius * radius
	var candidates := CombatGrid.query(from_pos, radius)
	for raw in candidates:
		var e := raw as Node2D
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		var d2 := from_pos.distance_squared_to(e.global_position)
		if e.has_method("has_soul_seal") and bool(e.call("has_soul_seal")):
			d2 *= 2.2
		if d2 < best_score:
			best_score = d2
			best = e
	if best != null:
		return best
	if candidates.is_empty() and is_inside_tree():
		for raw in get_tree().get_nodes_in_group("enemies"):
			var e := raw as Node2D
			if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
				continue
			var d2 := from_pos.distance_squared_to(e.global_position)
			if d2 < best_score:
				best_score = d2
				best = e
	return best

func _find_hit() -> Node2D:
	if _target != null and is_instance_valid(_target) and not bool(_target.get("is_dead")):
		if global_position.distance_squared_to(_target.global_position) <= HIT_RADIUS * HIT_RADIUS:
			return _target
	var best: Node2D = null
	var best_d2 := HIT_RADIUS * HIT_RADIUS
	for raw in CombatGrid.query(global_position, HIT_RADIUS):
		var e := raw as Node2D
		if e == null or not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		var d2 := global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best

func _physics_process(delta: float) -> void:
	if _done:
		return
	elapsed += delta
	if elapsed >= MAX_LIFETIME:
		_done = true
		queue_free()
		return

	if _target == null or not is_instance_valid(_target) or bool(_target.get("is_dead")):
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = RETARGET_INTERVAL
			_target = _acquire_target(global_position, SEARCH_RADIUS)

	if _target != null and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		if to_target.length_squared() > 1.0:
			_dir = _dir.lerp(to_target.normalized(), clampf(delta * 8.5, 0.0, 1.0))
			if _dir.length_squared() > 0.001:
				_dir = _dir.normalized()

	var step := speed * delta
	global_position += _dir * step
	travelled += step

	_trail.append(global_position)
	if _trail.size() > _trail_limit:
		_trail.remove_at(0)
	if _trail_line != null and _trail.size() >= 2:
		_trail_line.points = PackedVector2Array(_trail)

	if _halo != null:
		_halo.rotation += delta * 5.2
	if _wisp != null:
		_wisp.rotation -= delta * 7.0
		var pulse := 1.0 + 0.18 * sin(elapsed * 11.0)
		_wisp.scale = _wisp_base * pulse
	if _wisp_echo != null:
		_wisp_echo.rotation += delta * 4.4
		var echo_ang := elapsed * 7.5
		_wisp_echo.position = Vector2(cos(echo_ang), sin(echo_ang)) * 26.0
	if _core != null:
		_core.rotation += delta * 2.4

	var hit := _find_hit()
	if hit != null:
		_impact(hit)
		return
	if travelled >= max_range:
		_done = true
		queue_free()

func _impact(enemy: Node2D) -> void:
	if _done:
		return
	_done = true
	if enemy.has_method("apply_soul_seal"):
		enemy.apply_soul_seal(dot_dps, dot_dur, spread_radius, spread_targets)
	elif enemy.has_method("apply_dot"):
		enemy.apply_dot(dot_dps, dot_dur, false, "venom")
	if enemy.has_method("set_active_element"):
		enemy.set_active_element("wood", 3.0)
	if controller != null and is_instance_valid(controller) and controller.has_method("deal_v2_damage"):
		controller.deal_v2_damage(enemy, damage, "wood", {
			"knockback_dir": _dir,
			"knockback": 30.0,
		})
	if is_inside_tree() and get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		var extra: Dictionary = {"small": true}
		if is_max_tier:
			var links: Array = []
			for raw in CombatGrid.query(global_position, spread_radius):
				if links.size() >= 4:
					break
				var other := raw as Node2D
				if other == null or not is_instance_valid(other) or other == enemy or bool(other.get("is_dead")):
					continue
				links.append(other.global_position - global_position)
			extra = {"small": false, "links": links}
		var fx := V2ReactionFx.new()
		get_parent().add_child(fx)
		fx.setup_weapon_burst("soul_seal_burst", global_position, _dir, 56.0 if not is_max_tier else 78.0, color, extra)
	queue_free()
