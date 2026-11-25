class_name V2AttackFx
extends Node2D

enum Mode { BOOMERANG, BURN_LOB, CHAIN_BOLT, ICE_SHARD, PULSE_RING, FUSION_DOMAIN, WATER_SPLASH }

const TEX_JADE_SWORD: Texture2D = preload("res://assets/v2/weapons/wpn_jade_sword.png")
const TEX_THUNDER_ARC_STRIP: Texture2D = preload("res://assets/sprites/fx_thunder_arc_strip.png")
const THUNDER_ARC_FRAMES := 8
const ALPHA_SCALE_THRESHOLD := 1.30
const ALPHA_SCALE_MIN_FACTOR := 0.48
const AWAKENED_TIER := 8
const FUSION_TIER := 9
const AWAKENED_PARTICLE_CAP := 24
const AWAKENED_MAX_LAYERS := 8
const AWAKENED_SKY_HEIGHT := 520.0

const AWAKENED_EFFECTS := {
	"ink_sword_afterimage": {"primary": "#FACC15", "accent": "#2DD4BF", "pack": "sword"},
	"shader_fire_lotus_ring": {"primary": "#FB923C", "accent": "#FFF7ED", "pack": "fire"},
	"gold_core_chain_bolt": {"primary": "#C4B5FD", "accent": "#FEF9C3", "pack": "thunder"},
	"frost_wheel_shatter": {"primary": "#BAE6FD", "accent": "#E0F2FE", "pack": "ice"},
	"soul_seal_pandemic_burst": {"primary": "#A3E635", "accent": "#C4B5FD", "pack": "venom"},
	"bagua_echo_shockwave": {"primary": "#FDE047", "accent": "#FEF3C7", "pack": "bell"},
	"double_water_tide": {"primary": "#67E8F9", "accent": "#ECFEFF", "pack": "water"},
	"ancient_vine_bloom": {"primary": "#BEF264", "accent": "#4ADE80", "pack": "vine"},
	"fusion_domain": {"primary": "#FDBA74", "accent": "#FDE68A", "pack": "fusion"},
}

static func is_awakened_tier(tier: int, is_fusion: bool = false) -> bool:
	return is_fusion or tier >= AWAKENED_TIER

static func has_awakened_effect(effect_id: String) -> bool:
	return AWAKENED_EFFECTS.has(effect_id)

static func awakened_spec(effect_id: String) -> Dictionary:
	return AWAKENED_EFFECTS.get(effect_id, {})

static func awakened_color(effect_id: String, fallback: Color) -> Color:
	var spec := awakened_spec(effect_id)
	if spec.is_empty():
		return fallback
	return Color.from_string(String(spec.get("primary", "")), fallback)

static func awakened_particle_amount(base: int, awakened_scale: int = 1) -> int:
	return clampi(base * maxi(1, awakened_scale), 1, AWAKENED_PARTICLE_CAP)

var mode: int = Mode.PULSE_RING
var controller: Node = null
var player_node: Node2D = null

var damage: float = 10.0
var element: String = ""
var shot_id: int = 0
var color: Color = Color(0.18, 0.83, 0.75, 1.0)
var radius: float = 60.0
var duration: float = 0.35
var elapsed: float = 0.0
var area_scale: float = 1.0
var effective_alpha_limit: float = 0.34

static func alpha_from_scale(base_alpha: float, area_mult: float) -> float:
	var factor := 1.0 if area_mult <= ALPHA_SCALE_THRESHOLD else clampf(ALPHA_SCALE_THRESHOLD / maxf(0.01, area_mult), ALPHA_SCALE_MIN_FACTOR, 1.0)
	return clampf(base_alpha * factor, 0.05, 1.0)

enum SwordPhase { FLYING, RAIN_TRAILING }

var dir: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var max_range: float = 340.0
var pierce_left: int = 2
var travelled: float = 0.0
var hit_out: Dictionary = {}
var spin_ang: float = 0.0
var trail: Array[Vector2] = []
var is_afterimage: bool = false
var is_flame_fusion: bool = false

var start_pos: Vector2 = Vector2.ZERO
var dest_pos: Vector2 = Vector2.ZERO
var fly_dur: float = 0.26
var landed: bool = false
var tick_dps: float = 7.0
var zone_dur: float = 2.2
var burn_dur: float = 1.6
var tick_acc: float = 0.0
var implode_perk: bool = false

var chain_points: PackedVector2Array = PackedVector2Array()
var is_gold_core: bool = false
var _bolt_anchors: PackedVector2Array = PackedVector2Array()
var _bolt_core: Line2D = null
var _bolt_sky_core: Line2D = null
var _bolt_sub_branches: Array[Line2D] = []
var _bolt_arc_sprites: Array[Dictionary] = []
var _bolt_flicker_acc: float = 0.0

var slow_pct: float = 0.0
var slow_dur: float = 0.0
var split_on_hit: bool = false
var hit_ids: Dictionary = {}

var domain_kind: String = ""
var domain_tick_acc: float = 0.0
var domain_chain_count: int = 0

var pulse_style: String = "default"
var _ground_layer: bool = true

var awakened: bool = false
var awakened_effect: String = ""
var awaken_layers: int = 0
var _trail_limit: int = 10
var _sword_phase: int = SwordPhase.FLYING
var _awaken_core: Line2D = null
var _awaken_formation: Sprite2D = null
var _awaken_swords: Array[Dictionary] = []
var _awaken_flames: Array[Dictionary] = []
var _awaken_pillars: Array[Dictionary] = []
var _scorch_sprite: Sprite2D = null
var _fire_tongues: Array[Dictionary] = []
var _smoke_particles: GPUParticles2D = null
var _awaken_crests: Array[Dictionary] = []
var _awaken_runes: Array[Dictionary] = []
var _awaken_orbit: Array[Dictionary] = []
var _awaken_thorns: Array[Dictionary] = []
var _awaken_tendrils: Array[Line2D] = []
var _bolt_sky: Line2D = null
var _bolt_fork: Line2D = null
var _bolt_scorch: Sprite2D = null
var _bolt_tendrils: Array[Line2D] = []
var _water_ripple_done: bool = false

var _trail_line: Line2D = null
var _trail_particles: GPUParticles2D = null
var _main_sprite: Sprite2D = null
var _glow_sprite: Sprite2D = null
var _perk_sprite: Sprite2D = null
var _zone_particles: GPUParticles2D = null
var _lotus_particles: GPUParticles2D = null
var _bolt_main: Line2D = null
var _bolt_branch: Line2D = null
var _pulse_primary: Sprite2D = null
var _pulse_secondary: Sprite2D = null
var _pulse_layers: Array[Dictionary] = []
var _domain_base: Sprite2D = null
var _domain_ring: Sprite2D = null
var _domain_rim_arc: Line2D = null
var _domain_swords: Array[Sprite2D] = []
var _domain_flash_timer: float = 0.0
var _mist_sprite: Sprite2D = null
var _water_double_tide: bool = false
var _water_second_done: bool = false

func setup_boomerang(
	ctrl: Node,
	p_node: Node2D,
	origin: Vector2,
	direction: Vector2,
	dmg: float,
	spd: float,
	rng: float,
	pierce: int,
	elem: String,
	trail_col: Color,
	afterimage: bool = false,
	flame_fusion: bool = false,
	awakened_flag: bool = false
) -> void:
	mode = Mode.BOOMERANG
	controller = ctrl
	player_node = p_node
	global_position = origin
	dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	damage = dmg
	speed = spd
	max_range = rng
	pierce_left = maxi(1, pierce)
	element = elem
	color = trail_col
	is_afterimage = afterimage
	is_flame_fusion = flame_fusion
	z_index = 4

	var ink := 0.72 if (is_afterimage or is_flame_fusion) else 0.12
	var edge_c := Color(1.0, 0.88, 0.45, 1.0) if is_flame_fusion else Color(0.90, 1.0, 0.98, 1.0)
	_trail_line = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 20.0 if is_flame_fusion else 16.0, {
		"primary_color": Color(color.r, color.g, color.b, 0.82 if not is_afterimage else 0.65),
		"edge_color": edge_c,
		"ink_strength": ink,
		"intensity": 1.45,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.08, 1.0))
	_trail_line.top_level = true
	_trail_line.z_index = 3
	add_child(_trail_line)

	var p_tex := V2VfxFactory.TEX_FLAME_02 if is_flame_fusion else V2VfxFactory.TEX_TRACE_05
	_trail_particles = V2VfxFactory.make_gpu_particles(p_tex, {
		"amount": 12,
		"lifetime": 0.28,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 18.0,
		"vel_max": 52.0,
		"scale_min": 0.03,
		"scale_max": 0.07,
		"color_start": Color(color.r, color.g, color.b, 0.85),
		"color_end": Color(color.r, color.g, color.b, 0.0),
	})
	add_child(_trail_particles)

	_glow_sprite = V2VfxFactory.make_sprite(
		V2VfxFactory.TEX_FLARE_01,
		54.0 if is_flame_fusion else 44.0,
		Color(color.r, color.g, color.b, 0.55 if is_afterimage else 0.75),
		true
	)
	add_child(_glow_sprite)

	_main_sprite = Sprite2D.new()
	_main_sprite.texture = TEX_JADE_SWORD
	_main_sprite.scale = Vector2(0.18, 0.18)
	_main_sprite.rotation = dir.angle() + PI * 0.25
	if is_flame_fusion:
		_main_sprite.modulate = Color(1.25, 0.84, 0.55, 0.92 if not is_afterimage else 0.70)
	elif is_afterimage:
		_main_sprite.modulate = Color(0.45, 0.95, 0.90, 0.68)
	add_child(_main_sprite)

	if is_afterimage and get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		var slash_fx := V2ReactionFx.new()
		get_parent().add_child(slash_fx)
		slash_fx.setup_weapon_burst("sword_double_slash", origin + dir * 22.0, dir, 90.0, color)

	if awakened_flag:
		awakened = true
		_trail_limit = 18
		awakened_effect = "fusion_domain" if is_flame_fusion else "ink_sword_afterimage"
		if is_flame_fusion:
			_build_awakened_flame_blade(origin)
		else:
			_build_awakened_sword_rain(origin, direction)

func _build_awakened_sword_rain(origin: Vector2, direction: Vector2) -> void:
	var gold := Color(1.0, 0.86, 0.30, 1.0)
	if _trail_line != null:
		_trail_line.width = 26.0
		if _trail_line.material is ShaderMaterial:
			var mat := _trail_line.material as ShaderMaterial
			mat.set_shader_parameter("intensity", 1.85)
			mat.set_shader_parameter("edge_color", gold)
			mat.set_shader_parameter("ink_strength", 0.62)
	_awaken_core = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 7.0, {
		"primary_color": Color(1.0, 0.95, 0.72, 0.95),
		"edge_color": Color(1.0, 1.0, 1.0, 1.0),
		"intensity": 2.1,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.04, 1.0))
	_awaken_core.top_level = true
	_awaken_core.z_index = 4
	add_child(_awaken_core)

	_awaken_formation = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(0.26, 0.92, 0.86, 0.92),
		"accent_color": gold,
		"petal_count": 8.0,
		"spin_speed": 2.2,
		"alpha_limit": 0.50,
		"is_wave": 0.0,
	}, 230.0)
	_awaken_formation.scale = Vector2(1.0, 1.0)
	_awaken_formation.top_level = true
	_awaken_formation.global_position = origin
	_awaken_formation.z_index = -4
	add_child(_awaken_formation)

	var sword_count := 9
	var base_dir := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var back_dir := -base_dir
	var side_dir := Vector2(-base_dir.y, base_dir.x)
	for i in range(sword_count):
		var fan_norm := float(i) / float(sword_count - 1) * 2.0 - 1.0
		var spread_ang := fan_norm * 0.42
		var launch_dir := Vector2.from_angle(base_dir.angle() + spread_ang)
		var hover_pos := origin + back_dir * (26.0 + absf(fan_norm) * 14.0) + side_dir * (fan_norm * 46.0) + Vector2(0.0, -18.0 - (1.0 - absf(fan_norm)) * 16.0)
		var sp := V2VfxFactory.make_sprite(TEX_JADE_SWORD, 54.0, Color(1.0, 0.94, 0.58, 0.96), true)
		sp.top_level = true
		sp.global_position = hover_pos
		sp.rotation = launch_dir.angle() + PI * 0.25
		sp.z_index = 5
		add_child(sp)
		var sw_trail := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 8.5, {
			"primary_color": Color(1.0, 0.86, 0.28, 0.88),
			"edge_color": Color(0.32, 0.96, 0.86, 1.0),
			"intensity": 1.65,
			"use_texture_mask": 0.0,
		}, V2VfxFactory.make_taper_curve(0.04, 1.0))
		sw_trail.top_level = true
		sw_trail.z_index = 4
		add_child(sw_trail)
		_awaken_swords.append({
			"node": sp,
			"trail": sw_trail,
			"pts": [],
			"pos": hover_pos,
			"dir": launch_dir,
			"vel": launch_dir * 960.0,
			"delay": 0.05 + float(i) * 0.025,
			"life": 0.0,
			"hit_ids": {},
			"base_scale": sp.scale,
		})
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_TRACE_05, {
		"amount": awakened_particle_amount(20),
		"lifetime": 0.42,
		"one_shot": true,
		"explosiveness": 0.95,
		"direction": direction,
		"spread": 82.0,
		"vel_min": 280.0,
		"vel_max": 620.0,
		"scale_min": 0.06,
		"scale_max": 0.15,
		"color_start": Color(1.0, 0.96, 0.68, 0.95),
		"color_end": Color(0.20, 0.90, 0.80, 0.0),
	}))
	awaken_layers = 4

func _build_awakened_flame_blade(origin: Vector2) -> void:
	if _trail_line != null:
		_trail_line.width = 30.0
		if _trail_line.material is ShaderMaterial:
			(_trail_line.material as ShaderMaterial).set_shader_parameter("intensity", 1.95)
	var outer := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLAME_02, 88.0, Color(1.0, 0.42, 0.10, 0.78), true)
	add_child(outer)
	var inner := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FIRE_01, 44.0, Color(1.0, 0.95, 0.82, 0.92), true)
	add_child(inner)
	_awaken_flames.append({"node": outer, "base": outer.scale, "phase": 0.0, "spin": 1.6})
	_awaken_flames.append({"node": inner, "base": inner.scale, "phase": 1.4, "spin": -2.2})
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
		"amount": awakened_particle_amount(14),
		"lifetime": 0.42,
		"one_shot": false,
		"local_coords": false,
		"gravity": Vector3(0.0, -60.0, 0.0),
		"vel_min": 30.0,
		"vel_max": 95.0,
		"scale_min": 0.03,
		"scale_max": 0.07,
		"color_start": Color(1.0, 0.86, 0.42, 0.95),
		"color_end": Color(0.95, 0.28, 0.06, 0.0),
	}))
	awaken_layers = 3

func setup_burn_zone(
	ctrl: Node,
	origin: Vector2,
	target_pos: Vector2,
	impact_dmg: float,
	aoe_r: float,
	z_dur: float,
	dps: float,
	zone_col: Color,
	implode: bool = false,
	area_mult: float = 1.0,
	awakened_flag: bool = false,
	b_dur: float = 1.6
) -> void:
	mode = Mode.BURN_LOB
	controller = ctrl
	global_position = origin
	start_pos = origin
	dest_pos = target_pos
	damage = impact_dmg
	radius = aoe_r
	zone_dur = z_dur
	burn_dur = maxf(0.0, b_dur)
	tick_dps = dps
	area_scale = maxf(0.5, area_mult)
	var base_a := clampf(zone_col.a, 0.25, 0.36)
	effective_alpha_limit = alpha_from_scale(base_a, area_scale)
	color = zone_col
	color.a = effective_alpha_limit
	implode_perk = implode
	element = "fire"
	z_index = 4

	_trail_line = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 10.0, {
		"primary_color": Color(0.96, 0.38, 0.08, 0.82),
		"edge_color": Color(1.0, 0.88, 0.40, 1.0),
		"intensity": 1.35,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.06, 1.0))
	_trail_line.top_level = true
	_trail_line.z_index = 3
	add_child(_trail_line)

	_glow_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, 26.0, Color(1.0, 0.56, 0.16, 0.58), true)
	add_child(_glow_sprite)
	_main_sprite = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_LIGHT_01, V2VfxFactory.SHADER_FIRE_FLAME_2D, {
		"core_color": Color(1.0, 0.96, 0.72, 1.0),
		"mid_color": Color(1.0, 0.48, 0.10, 1.0),
		"outer_color": Color(0.74, 0.14, 0.04, 1.0),
		"speed": 4.5,
		"noise_scale": 4.2,
		"flame_shape": 2.0,
		"intensity": 1.2,
		"alpha_limit": 0.94,
	}, 34.0)
	add_child(_main_sprite)
	_trail_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
		"amount": 8,
		"lifetime": 0.24,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 14.0,
		"vel_max": 42.0,
		"scale_min": 0.025,
		"scale_max": 0.05,
		"color_start": Color(1.0, 0.82, 0.36, 0.92),
		"color_end": Color(0.94, 0.24, 0.04, 0.0),
	})
	add_child(_trail_particles)

	if awakened_flag:
		awakened = true
		awakened_effect = "shader_fire_lotus_ring"
		_build_awakened_fire_lob()

func _build_awakened_fire_lob() -> void:
	var outer := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_LIGHT_01, V2VfxFactory.SHADER_FIRE_FLAME_2D, {
		"core_color": Color(1.0, 0.92, 0.62, 1.0),
		"mid_color": Color(1.0, 0.42, 0.10, 1.0),
		"outer_color": Color(0.72, 0.10, 0.04, 1.0),
		"speed": 4.2,
		"noise_scale": 3.8,
		"flame_shape": 0.0,
		"intensity": 1.15,
		"alpha_limit": 0.78,
		"ring_progress": 0.95,
	}, 52.0)
	add_child(outer)
	var mid := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_LIGHT_01, V2VfxFactory.SHADER_FIRE_FLAME_2D, {
		"core_color": Color(1.0, 0.96, 0.82, 1.0),
		"mid_color": Color(1.0, 0.50, 0.14, 1.0),
		"outer_color": Color(0.80, 0.14, 0.04, 1.0),
		"speed": 5.0,
		"noise_scale": 4.4,
		"flame_shape": 2.0,
		"intensity": 1.25,
		"alpha_limit": 0.92,
	}, 38.0)
	add_child(mid)
	var core := V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_06, 20.0, Color(1.0, 0.96, 0.78, 0.92), true)
	add_child(core)
	_awaken_flames.append({"node": outer, "base": outer.scale, "phase": 0.0, "spin": 2.2})
	_awaken_flames.append({"node": mid, "base": mid.scale, "phase": 1.7, "spin": 0.0})
	_awaken_flames.append({"node": core, "base": core.scale, "phase": 3.1, "spin": -2.4})
	_trail_particles.amount = awakened_particle_amount(10)
	_trail_particles.lifetime = 0.30
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
		"amount": awakened_particle_amount(10),
		"lifetime": 0.38,
		"one_shot": false,
		"local_coords": false,
		"gravity": Vector3(0.0, -70.0, 0.0),
		"vel_min": 22.0,
		"vel_max": 70.0,
		"scale_min": 0.025,
		"scale_max": 0.055,
		"color_start": Color(1.0, 0.88, 0.44, 0.94),
		"color_end": Color(0.95, 0.28, 0.05, 0.0),
	}))
	awaken_layers = 4

static func build_jagged_bolt_points(anchors: PackedVector2Array, subdivisions: int = 3, max_disp: float = 18.0) -> PackedVector2Array:
	if anchors.size() < 2:
		return anchors
	var pts := PackedVector2Array()
	for s in range(anchors.size() - 1):
		var seg := PackedVector2Array([anchors[s], anchors[s + 1]])
		var disp := max_disp
		for _step in range(subdivisions):
			var next_seg := PackedVector2Array([seg[0]])
			for i in range(seg.size() - 1):
				var p1 := seg[i]
				var p2 := seg[i + 1]
				var diff := p2 - p1
				var seg_len := diff.length()
				if seg_len > 1.0:
					var normal := Vector2(-diff.y, diff.x) / seg_len
					var mid := (p1 + p2) * 0.5 + normal * randf_range(-disp, disp)
					next_seg.append(mid)
				next_seg.append(p2)
			seg = next_seg
			disp *= 0.55
		for i in range(seg.size() - 1):
			pts.append(seg[i])
	pts.append(anchors[anchors.size() - 1])
	return pts

func _refresh_lightning_geometry() -> void:
	if _bolt_anchors.size() < 2:
		return
	var jag := build_jagged_bolt_points(_bolt_anchors, 3, 20.0 if awakened else 15.0)
	if _bolt_main != null and is_instance_valid(_bolt_main):
		_bolt_main.points = jag
	if _bolt_core != null and is_instance_valid(_bolt_core):
		_bolt_core.points = jag
	if awakened and _bolt_sky != null and is_instance_valid(_bolt_sky):
		var head := _bolt_anchors[0]
		var top := head - Vector2(0.0, AWAKENED_SKY_HEIGHT)
		var sky_jag := build_jagged_bolt_points(PackedVector2Array([top, head]), 4, 34.0)
		_bolt_sky.points = sky_jag
		if _bolt_sky_core != null and is_instance_valid(_bolt_sky_core):
			_bolt_sky_core.points = sky_jag

func setup_chain_bolt(pts: PackedVector2Array, bolt_col: Color, gold_core: bool = false, awakened_flag: bool = false) -> void:
	mode = Mode.CHAIN_BOLT
	global_position = Vector2.ZERO
	chain_points = pts
	_bolt_anchors = pts
	_bolt_flicker_acc = 0.0
	color = bolt_col
	is_gold_core = gold_core
	duration = 0.36 if awakened_flag else 0.28
	z_index = 6
	awakened = awakened_flag
	if awakened:
		awakened_effect = "gold_core_chain_bolt"

	var core_c := Color(1.0, 0.96, 0.72, 1.0) if is_gold_core else Color(0.94, 0.98, 1.0, 1.0)
	var jag_pts := build_jagged_bolt_points(pts, 3, 20.0 if awakened else 15.0)
	_bolt_main = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 18.0 if awakened else (15.0 if is_gold_core else 13.0), {
		"bolt_color": Color(color.r, color.g, color.b, 0.95),
		"core_color": core_c,
		"speed": 22.0,
		"jitter_amp": 0.16,
		"thickness": 0.14,
		"core_ratio": 0.36 if is_gold_core else 0.30,
		"intensity": 1.85 if is_gold_core else 1.65,
		"taper_ends": 0.10,
	})
	_bolt_main.joint_mode = Line2D.LINE_JOINT_SHARP
	_bolt_main.begin_cap_mode = Line2D.LINE_CAP_NONE
	_bolt_main.end_cap_mode = Line2D.LINE_CAP_NONE
	_bolt_main.points = jag_pts
	add_child(_bolt_main)

	_bolt_core = V2VfxFactory.make_sharp_lightning_line(4.0 if awakened else 2.8, Color(1.0, 0.99, 0.92, 0.98))
	_bolt_core.points = jag_pts
	add_child(_bolt_core)

	if TEX_THUNDER_ARC_STRIP != null and pts.size() >= 2:
		var arc_step := 2 if pts.size() >= 3 else 1
		var max_arc_segs := 4
		var seg_idx := 0
		var spawned := 0
		var arc_tint := bolt_col.lerp(Color.WHITE, 0.55)
		var base_a := 0.68 if (is_gold_core or awakened) else 0.54
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		while seg_idx < pts.size() - 1 and spawned < max_arc_segs:
			var next_idx := mini(seg_idx + arc_step, pts.size() - 1)
			var a := pts[seg_idx]
			var b := pts[next_idx]
			var span := b - a
			var dist := span.length()
			if dist >= 28.0:
				var arc_sp := Sprite2D.new()
				arc_sp.texture = TEX_THUNDER_ARC_STRIP
				arc_sp.hframes = THUNDER_ARC_FRAMES
				arc_sp.frame = (spawned * 2 + randi() % THUNDER_ARC_FRAMES) % THUNDER_ARC_FRAMES
				arc_sp.material = add_mat
				arc_sp.position = (a + b) * 0.5
				arc_sp.rotation = span.angle()
				var sx := dist / 356.0
				var sy := clampf(sx * (0.95 if awakened else 0.78), 0.28, 0.88)
				arc_sp.scale = Vector2(sx, sy)
				arc_sp.modulate = Color(arc_tint.r, arc_tint.g, arc_tint.b, base_a)
				add_child(arc_sp)
				_bolt_arc_sprites.append({"sprite": arc_sp, "base_alpha": base_a})
				spawned += 1
			seg_idx += arc_step

	if pts.size() >= 2:
		var br_count := 3 if (is_gold_core or awakened) else 2
		for bi in range(br_count):
			var seg_idx := clampi(bi % maxi(1, pts.size() - 1), 0, pts.size() - 2)
			var a := pts[seg_idx]
			var b := pts[seg_idx + 1]
			var start_p := a.lerp(b, randf_range(0.28, 0.72))
			var dir_ab := (b - a).normalized() if a.distance_squared_to(b) > 1.0 else Vector2.RIGHT
			var br_dir := dir_ab.rotated(randf_range(-1.15, 1.15))
			var end_p := start_p + br_dir * randf_range(38.0, 74.0)
			var sub := V2VfxFactory.make_sharp_lightning_line(2.8, Color(color.r, color.g, color.b, 0.85), V2VfxFactory.make_taper_curve(0.08, 0.95))
			sub.points = build_jagged_bolt_points(PackedVector2Array([start_p, end_p]), 2, 11.0)
			add_child(sub)
			_bolt_sub_branches.append(sub)

	if is_gold_core and pts.size() >= 2:
		var branch_pts := build_jagged_bolt_points(pts, 2, 22.0)
		_bolt_branch = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 9.0, {
			"bolt_color": Color(1.0, 0.88, 0.42, 0.85),
			"core_color": Color(1.0, 0.98, 0.85, 1.0),
			"speed": 26.0,
			"jitter_amp": 0.22,
			"thickness": 0.12,
			"intensity": 1.55,
			"taper_ends": 0.14,
		})
		_bolt_branch.joint_mode = Line2D.LINE_JOINT_SHARP
		_bolt_branch.points = branch_pts
		add_child(_bolt_branch)

	if awakened and pts.size() >= 2:
		_build_awakened_thunder(pts, core_c)

	var max_hops := mini(pts.size(), 7)
	for i in range(1, max_hops):
		var hop_sp := V2VfxFactory.make_sprite(V2VfxFactory.TEX_SPARK_06, 46.0 if is_gold_core else 36.0, core_c, true)
		hop_sp.position = pts[i]
		add_child(hop_sp)
		if i <= 4:
			var spk := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_05, {
				"amount": 6,
				"lifetime": 0.24,
				"vel_min": 45.0,
				"vel_max": 120.0,
				"scale_min": 0.03,
				"scale_max": 0.06,
				"color_start": core_c,
				"color_end": Color(color.r, color.g, color.b, 0.0),
			})
			spk.position = pts[i]
			add_child(spk)

func _build_awakened_thunder(pts: PackedVector2Array, core_c: Color) -> void:
	var head := pts[0]
	if _bolt_main != null:
		_bolt_main.width = 22.0
		if _bolt_main.material is ShaderMaterial:
			var mm := _bolt_main.material as ShaderMaterial
			mm.set_shader_parameter("thickness", 0.20)
			mm.set_shader_parameter("jitter_amp", 0.24)
			mm.set_shader_parameter("intensity", 2.2)

	var top := head - Vector2(0.0, AWAKENED_SKY_HEIGHT)
	var sky_pts := build_jagged_bolt_points(PackedVector2Array([top, head]), 4, 34.0)
	_bolt_sky = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 28.0, {
		"bolt_color": Color(0.62, 0.52, 0.98, 0.94),
		"core_color": core_c,
		"speed": 28.0,
		"jitter_amp": 0.22,
		"thickness": 0.22,
		"core_ratio": 0.45,
		"intensity": 2.3,
		"taper_ends": 0.06,
	})
	_bolt_sky.joint_mode = Line2D.LINE_JOINT_SHARP
	_bolt_sky.begin_cap_mode = Line2D.LINE_CAP_NONE
	_bolt_sky.end_cap_mode = Line2D.LINE_CAP_NONE
	_bolt_sky.points = sky_pts
	add_child(_bolt_sky)

	_bolt_sky_core = V2VfxFactory.make_sharp_lightning_line(6.0, Color(1.0, 0.98, 0.86, 1.0))
	_bolt_sky_core.points = sky_pts
	add_child(_bolt_sky_core)

	var fork_pts := build_jagged_bolt_points(pts, 3, 28.0)
	_bolt_fork = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 12.0, {
		"bolt_color": Color(0.72, 0.60, 1.0, 0.85),
		"core_color": Color(0.98, 0.96, 1.0, 0.98),
		"speed": 30.0,
		"jitter_amp": 0.24,
		"thickness": 0.14,
		"intensity": 1.9,
		"taper_ends": 0.12,
	})
	_bolt_fork.joint_mode = Line2D.LINE_JOINT_SHARP
	_bolt_fork.points = fork_pts
	add_child(_bolt_fork)

	_bolt_scorch = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_03, V2VfxFactory.SHADER_BURN_DISSOLVE, {
		"primary_color": Color(0.35, 0.24, 0.62, 0.92),
		"burn_color": Color(1.0, 0.96, 0.72, 1.0),
		"dissolve_amount": 0.04,
		"burn_size": 0.22,
		"alpha_limit": 0.44,
	}, 168.0)
	_bolt_scorch.position = head
	_bolt_scorch.z_index = -5
	add_child(_bolt_scorch)

	for i in range(4):
		var ang := TAU * float(i) / 4.0 + 0.3
		var dir_v := Vector2.from_angle(ang)
		var tip := head + dir_v * randf_range(78.0, 124.0)
		var tendril := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 7.5, {
			"bolt_color": Color(0.72, 0.58, 1.0, 0.78),
			"core_color": Color(1.0, 0.98, 0.90, 0.92),
			"speed": 26.0,
			"jitter_amp": 0.25,
			"thickness": 0.12,
			"intensity": 1.65,
			"taper_ends": 0.20,
		})
		tendril.joint_mode = Line2D.LINE_JOINT_SHARP
		tendril.points = build_jagged_bolt_points(PackedVector2Array([head, tip]), 2, 16.0)
		tendril.z_index = -4
		add_child(tendril)
		_bolt_tendrils.append(tendril)

	var spark_burst := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
		"amount": awakened_particle_amount(20),
		"lifetime": 0.40,
		"one_shot": true,
		"explosiveness": 0.95,
		"vel_min": 90.0,
		"vel_max": 280.0,
		"scale_min": 0.035,
		"scale_max": 0.085,
		"color_start": Color(0.96, 0.92, 1.0, 0.96),
		"color_end": Color(0.55, 0.42, 0.98, 0.0),
	})
	spark_burst.position = head
	add_child(spark_burst)
	var scorch_smoke := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_04, {
		"amount": awakened_particle_amount(10),
		"lifetime": 0.52,
		"one_shot": true,
		"explosiveness": 0.9,
		"vel_min": 30.0,
		"vel_max": 90.0,
		"scale_min": 0.05,
		"scale_max": 0.12,
		"additive": false,
		"color_start": Color(0.42, 0.36, 0.58, 0.48),
		"color_end": Color(0.16, 0.12, 0.24, 0.0),
	})
	scorch_smoke.position = head
	add_child(scorch_smoke)
	awaken_layers = 3 + _bolt_tendrils.size()

func setup_ice_shard(
	ctrl: Node,
	origin: Vector2,
	direction: Vector2,
	dmg: float,
	rng: float,
	s_id: int,
	sl_pct: float,
	sl_dur: float,
	shard_col: Color,
	split_perk: bool = false,
	pierce: int = 1,
	awakened_flag: bool = false
) -> void:
	mode = Mode.ICE_SHARD
	controller = ctrl
	global_position = origin
	dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	damage = dmg
	speed = 700.0
	max_range = rng
	shot_id = s_id
	slow_pct = sl_pct
	slow_dur = sl_dur
	color = shard_col
	split_on_hit = split_perk
	pierce_left = pierce
	element = "ice"
	z_index = 4

	_trail_line = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 11.0, {
		"primary_color": Color(color.r, color.g, color.b, 0.72),
		"edge_color": Color(0.92, 0.99, 1.0, 1.0),
		"intensity": 1.35,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.05, 1.0))
	_trail_line.top_level = true
	_trail_line.z_index = 3
	add_child(_trail_line)

	_trail_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_04, {
		"amount": 8,
		"lifetime": 0.25,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 12.0,
		"vel_max": 38.0,
		"scale_min": 0.025,
		"scale_max": 0.05,
		"color_start": Color(0.76, 0.96, 1.0, 0.85),
		"color_end": Color(0.22, 0.74, 0.97, 0.0),
	})
	add_child(_trail_particles)

	_main_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_TRACE_01_ROT, 34.0, Color(color.r, color.g, color.b, 0.95), true)
	_main_sprite.rotation = dir.angle()
	add_child(_main_sprite)

	_glow_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_08, 22.0, Color(0.92, 0.99, 1.0, 0.95), true)
	_glow_sprite.position = dir * 8.0
	add_child(_glow_sprite)

	_mist_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_TWIRL_02, 24.0, Color(0.32, 0.90, 1.0, 0.52), true)
	add_child(_mist_sprite)

	if split_on_hit:
		_perk_sprite = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.35, 0.86, 1.0, 0.72),
			"accent_color": Color(0.95, 0.99, 1.0, 1.0),
			"petal_count": 8.0,
			"spin_speed": 3.5,
			"alpha_limit": 0.58,
			"is_wave": 0.0,
		}, 44.0)
		add_child(_perk_sprite)

	if awakened_flag:
		awakened = true
		awakened_effect = "frost_wheel_shatter"
		_trail_limit = 14
		if _trail_line != null:
			_trail_line.width = 18.0
		_trail_particles.amount = awakened_particle_amount(14)
		for i in range(3):
			var crystal := V2VfxFactory.make_sprite(
				V2VfxFactory.TEX_STAR_08 if i % 2 == 0 else V2VfxFactory.TEX_STAR_06,
				20.0 + float(i) * 6.0,
				Color(0.80, 0.97, 1.0, 0.90),
				true
			)
			add_child(crystal)
			_awaken_orbit.append({"node": crystal, "ang": TAU * float(i) / 3.0, "radius": 30.0 + float(i) * 11.0})
		add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_01, {
			"amount": awakened_particle_amount(10),
			"lifetime": 0.42,
			"one_shot": false,
			"local_coords": false,
			"vel_min": 18.0,
			"vel_max": 52.0,
			"scale_min": 0.05,
			"scale_max": 0.11,
			"additive": false,
			"color_start": Color(0.62, 0.90, 1.0, 0.40),
			"color_end": Color(0.22, 0.66, 0.92, 0.0),
		}))
		awaken_layers = 4

func setup_pulse_ring(
	center: Vector2,
	max_r: float,
	ring_col: Color,
	dur: float = 0.35,
	ground_layer: bool = true,
	style: String = "default",
	area_mult: float = 1.0,
	awakened_flag: bool = false
) -> void:
	mode = Mode.PULSE_RING
	global_position = center
	radius = max_r
	color = ring_col
	pulse_style = style
	_ground_layer = ground_layer
	awakened = awakened_flag
	if awakened:
		match pulse_style:
			"venom", "venom_dual":
				awakened_effect = "ancient_vine_bloom"
			"bell", "bell_echo", "bell_tide":
				awakened_effect = "bagua_echo_shockwave"
			"water_mirror":
				awakened_effect = "double_water_tide"
			"fire_surge":
				awakened_effect = "shader_fire_lotus_ring"
			"fusion_zen_bell":
				awakened_effect = "soul_seal_pandemic_burst"
			_:
				awakened_effect = "fusion_domain"
	area_scale = maxf(0.5, area_mult)
	var base_a := clampf(ring_col.a, 0.25, 0.38) if ground_layer else clampf(ring_col.a, 0.25, 0.85)
	var alpha_cap := alpha_from_scale(base_a, area_scale) if ground_layer else base_a
	effective_alpha_limit = alpha_cap
	if ground_layer:
		color.a = alpha_cap
		z_index = -5
	else:
		z_index = 5
	duration = dur

	var p_alpha_factor := alpha_cap / maxf(0.01, base_a)
	match pulse_style:
		"venom", "venom_dual":
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(color.r, color.g, color.b, 0.95),
				"accent_color": Color(0.55, 0.98, 0.65, 0.95),
				"petal_count": 6.0,
				"spin_speed": 1.8,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, radius * 2.1)
			add_child(_pulse_primary)
			if pulse_style == "venom_dual":
				_pulse_secondary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_01, V2VfxFactory.SHADER_BURN_DISSOLVE, {
					"primary_color": Color(0.06, 0.72, 0.51, 0.90),
					"burn_color": Color(0.52, 0.98, 0.62, 1.0),
					"dissolve_amount": 0.08,
					"alpha_limit": alpha_cap * 0.92,
				}, radius * 2.0)
				add_child(_pulse_secondary)
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
				"amount": 12 if pulse_style == "venom_dual" else 9,
				"lifetime": dur * 1.15,
				"shape": "ring",
				"shape_radius": radius * 0.55,
				"vel_min": 30.0,
				"vel_max": radius * 1.25,
				"scale_min": 0.05,
				"scale_max": 0.11,
				"additive": false,
				"color_start": Color(0.14, 0.86, 0.54, 0.45 * p_alpha_factor),
				"color_end": Color(0.06, 0.45, 0.30, 0.0),
			}))

		"bell_tide":
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(color.r, color.g, color.b, 0.95),
				"accent_color": Color(1.0, 0.94, 0.62, 1.0),
				"petal_count": 8.0,
				"spin_speed": 1.35,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.16,
			}, radius * 2.15)
			add_child(_pulse_primary)
			_pulse_secondary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(1.0, 0.78, 0.22, 0.92),
				"accent_color": Color(1.0, 0.97, 0.78, 1.0),
				"petal_count": 8.0,
				"spin_speed": -1.9,
				"alpha_limit": alpha_cap * 0.90,
				"is_wave": 1.0,
				"ring_width": 0.14,
			}, radius * 2.15)
			add_child(_pulse_secondary)
			for li in range(3):
				var layer := V2VfxFactory.make_shader_sprite(
					V2VfxFactory.TEX_CIRCLE_05 if li % 2 == 0 else V2VfxFactory.TEX_CIRCLE_03,
					V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE,
					{
						"primary_color": Color(0.78, 0.50, 0.10, 0.88),
						"accent_color": Color(1.0, 0.90, 0.46, 1.0),
						"petal_count": 6.0,
						"spin_speed": 1.1 if li % 2 == 0 else -1.4,
						"alpha_limit": alpha_cap * (0.92 - 0.10 * float(li)),
						"is_wave": 1.0,
						"ring_width": 0.12,
					},
					radius * (1.86 + 0.14 * float(li))
				)
				add_child(layer)
				_pulse_layers.append({
					"node": layer,
					"offset": 0.15 * float(li),
					"spin": 1.2 if li % 2 == 0 else -1.5,
				})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_10, {
				"amount": 16,
				"lifetime": dur * 1.25,
				"shape": "ring",
				"shape_radius": radius * 0.42,
				"vel_min": 45.0,
				"vel_max": radius * 1.35,
				"scale_min": 0.07,
				"scale_max": 0.15,
				"additive": false,
				"color_start": Color(0.86, 0.62, 0.18, 0.42 * p_alpha_factor),
				"color_end": Color(0.42, 0.28, 0.06, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_01, {
				"amount": 14,
				"lifetime": dur,
				"shape": "ring",
				"shape_radius": radius * 0.48,
				"vel_min": 55.0,
				"vel_max": radius * 1.5,
				"scale_min": 0.035,
				"scale_max": 0.075,
				"color_start": Color(1.0, 0.90, 0.48, 0.92 * p_alpha_factor),
				"color_end": Color(0.96, 0.62, 0.04, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_06, {
				"amount": 10,
				"lifetime": dur * 0.9,
				"shape": "ring",
				"shape_radius": radius * 0.30,
				"vel_min": 30.0,
				"vel_max": radius * 1.05,
				"scale_min": 0.03,
				"scale_max": 0.06,
				"color_start": Color(1.0, 0.97, 0.80, 0.85 * p_alpha_factor),
				"color_end": Color(1.0, 0.72, 0.18, 0.0),
			}))

		"bell", "bell_echo":
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(color.r, color.g, color.b, 0.95),
				"accent_color": Color(1.0, 0.94, 0.62, 1.0),
				"petal_count": 8.0,
				"spin_speed": 1.4,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.18,
			}, radius * 2.15)
			add_child(_pulse_primary)
			if pulse_style == "bell_echo":
				_pulse_secondary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
					"primary_color": Color(1.0, 0.80, 0.24, 0.90),
					"accent_color": Color(1.0, 0.96, 0.72, 1.0),
					"petal_count": 8.0,
					"spin_speed": -1.8,
					"alpha_limit": alpha_cap * 0.88,
					"is_wave": 1.0,
					"ring_width": 0.16,
				}, radius * 2.15)
				add_child(_pulse_secondary)
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_01, {
				"amount": 12 if pulse_style == "bell_echo" else 8,
				"lifetime": dur,
				"shape": "ring",
				"shape_radius": radius * 0.45,
				"vel_min": 45.0,
				"vel_max": radius * 1.4,
				"scale_min": 0.04,
				"scale_max": 0.08,
				"color_start": Color(1.0, 0.88, 0.42, 0.88 * p_alpha_factor),
				"color_end": Color(0.96, 0.62, 0.04, 0.0),
			}))

		"fusion_zen_bell":
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.20, 0.83, 0.60, 0.95),
				"accent_color": Color(1.0, 0.86, 0.32, 1.0),
				"petal_count": 8.0,
				"spin_speed": 2.0,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.22,
			}, radius * 2.15)
			add_child(_pulse_primary)
			_pulse_secondary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SMOKE_10, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.16, 0.78, 0.56, 0.88),
				"burn_color": Color(0.98, 0.82, 0.28, 1.0),
				"dissolve_amount": 0.06,
				"alpha_limit": alpha_cap * 0.90,
			}, radius * 2.05)
			add_child(_pulse_secondary)
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_04, {
				"amount": 14,
				"lifetime": dur * 1.2,
				"shape": "ring",
				"shape_radius": radius * 0.55,
				"vel_min": 40.0,
				"vel_max": radius * 1.3,
				"scale_min": 0.06,
				"scale_max": 0.13,
				"additive": false,
				"color_start": Color(0.24, 0.88, 0.62, 0.48 * p_alpha_factor),
				"color_end": Color(0.10, 0.55, 0.36, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_09, {
				"amount": 10,
				"lifetime": dur,
				"shape": "ring",
				"shape_radius": radius * 0.65,
				"vel_min": 55.0,
				"vel_max": radius * 1.5,
				"scale_min": 0.04,
				"scale_max": 0.09,
				"color_start": Color(1.0, 0.90, 0.45, 0.90 * p_alpha_factor),
				"color_end": Color(0.20, 0.83, 0.60, 0.0),
			}))

		"water_mirror":
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.24, 0.84, 0.98, 0.92),
				"accent_color": Color(0.84, 0.99, 1.0, 1.0),
				"petal_count": 6.0,
				"spin_speed": 2.4,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.18,
			}, radius * 2.1)
			add_child(_pulse_primary)
			_pulse_secondary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.36, 0.92, 0.90, 0.80),
				"accent_color": Color(0.92, 1.0, 1.0, 0.96),
				"petal_count": 4.0,
				"spin_speed": -3.2,
				"alpha_limit": alpha_cap * 0.85,
				"is_wave": 1.0,
				"ring_width": 0.22,
			}, radius * 1.85)
			add_child(_pulse_secondary)
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_06, {
				"amount": 7,
				"lifetime": dur,
				"shape": "ring",
				"shape_radius": radius * 0.35,
				"vel_min": 35.0,
				"vel_max": radius * 1.4,
				"scale_min": 0.035,
				"scale_max": 0.075,
				"color_start": Color(0.68, 0.96, 1.0, 0.90 * p_alpha_factor),
				"color_end": Color(0.20, 0.78, 0.96, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_01, {
				"amount": 6,
				"lifetime": dur * 1.1,
				"shape": "ring",
				"shape_radius": radius * 0.45,
				"vel_min": 25.0,
				"vel_max": radius * 1.15,
				"scale_min": 0.045,
				"scale_max": 0.095,
				"additive": false,
				"color_start": Color(0.45, 0.92, 0.98, 0.42 * p_alpha_factor),
				"color_end": Color(0.18, 0.72, 0.88, 0.0),
			}))

		_:
			_pulse_primary = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(color.r, color.g, color.b, 0.95),
				"accent_color": Color(1.0, 0.96, 0.85, 1.0),
				"petal_count": 6.0,
				"spin_speed": 1.6,
				"alpha_limit": alpha_cap,
				"is_wave": 1.0,
				"ring_width": 0.18,
			}, radius * 2.05)
			add_child(_pulse_primary)

	if awakened:
		match pulse_style:
			"venom", "venom_dual":
				_build_awakened_venom_ring(p_alpha_factor)
			"bell", "bell_echo", "bell_tide":
				_build_awakened_bell_ring(alpha_cap, p_alpha_factor)
			"water_mirror":
				_build_awakened_water_ring(p_alpha_factor)
			_:
				_build_awakened_ring_glow(alpha_cap, p_alpha_factor)

func _build_awakened_bell_ring(alpha_cap: float, p_alpha_factor: float) -> void:
	var rune_tex: Array[Texture2D] = [V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.TEX_CIRCLE_03, V2VfxFactory.TEX_MAGIC_04]
	for li in range(3):
		var rune := V2VfxFactory.make_shader_sprite(rune_tex[li % rune_tex.size()], V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.98, 0.80, 0.22, 0.94),
			"accent_color": Color(1.0, 0.98, 0.88, 1.0),
			"petal_count": 8.0,
			"spin_speed": 1.35 if li % 2 == 0 else -1.75,
			"alpha_limit": alpha_cap * (0.92 - 0.12 * float(li)),
			"is_wave": 1.0,
			"ring_width": 0.12,
		}, radius * (2.30 + 0.20 * float(li)))
		add_child(rune)
		_pulse_layers.append({"node": rune, "offset": 0.05 + 0.09 * float(li), "spin": 1.0 if li % 2 == 0 else -1.2})
		awaken_layers += 1

	var shock := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_06, {
		"amount": awakened_particle_amount(18),
		"lifetime": duration * 1.15,
		"shape": "ring",
		"shape_radius": radius * 0.30,
		"vel_min": 120.0,
		"vel_max": radius * 2.2,
		"scale_min": 0.035,
		"scale_max": 0.08,
		"color_start": Color(1.0, 0.92, 0.52, 0.95 * p_alpha_factor),
		"color_end": Color(1.0, 0.66, 0.10, 0.0),
	})
	add_child(shock)
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_10, {
		"amount": awakened_particle_amount(14),
		"lifetime": duration * 1.3,
		"shape": "ring",
		"shape_radius": radius * 0.55,
		"vel_min": 55.0,
		"vel_max": radius * 1.55,
		"scale_min": 0.07,
		"scale_max": 0.16,
		"additive": false,
		"color_start": Color(0.82, 0.62, 0.18, 0.40 * p_alpha_factor),
		"color_end": Color(0.42, 0.28, 0.06, 0.0),
	}))
	awaken_layers += 2

func _build_awakened_venom_ring(p_alpha_factor: float) -> void:
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		var thorn := V2VfxFactory.make_sprite(
			V2VfxFactory.TEX_SCRATCH_01,
			30.0 + float(i % 3) * 6.0,
			Color(0.82, 0.98, 0.52, 0.88),
			false
		)
		thorn.rotation = ang + PI * 0.5
		thorn.position = Vector2(cos(ang), sin(ang)) * radius * 0.42
		add_child(thorn)
		_awaken_thorns.append({"node": thorn, "ang": ang, "delay": float(i) * 0.015})
		awaken_layers += 1

	for i in range(4):
		var ang := TAU * float(i) / 4.0 + 0.25
		var dir_v := Vector2.from_angle(ang)
		var pts := PackedVector2Array([Vector2.ZERO])
		for s in range(1, 5):
			var t := float(s) / 4.0
			pts.append(dir_v * radius * t + Vector2(-dir_v.y, dir_v.x) * sin(t * PI) * radius * 0.16)
		var tendril := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 7.0, {
			"primary_color": Color(0.42, 0.92, 0.36, 0.70),
			"edge_color": Color(0.78, 1.0, 0.84, 0.92),
			"ink_strength": 0.45,
			"intensity": 1.35,
			"use_texture_mask": 0.0,
		}, V2VfxFactory.make_taper_curve(0.10, 1.0))
		tendril.points = pts
		add_child(tendril)
		_awaken_tendrils.append(tendril)
		awaken_layers += 1

	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
		"amount": awakened_particle_amount(14),
		"lifetime": duration * 1.1,
		"shape": "ring",
		"shape_radius": radius * 0.55,
		"vel_min": 70.0,
		"vel_max": radius * 1.8,
		"scale_min": 0.03,
		"scale_max": 0.07,
		"color_start": Color(0.86, 1.0, 0.62, 0.92 * p_alpha_factor),
		"color_end": Color(0.36, 0.78, 0.30, 0.0),
	}))
	awaken_layers += 1

func _build_awakened_water_ring(p_alpha_factor: float) -> void:
	for li in range(2):
		var foam_ring := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.56, 0.94, 1.0, 0.90),
			"accent_color": Color(0.98, 1.0, 1.0, 1.0),
			"petal_count": 6.0,
			"spin_speed": 2.2 if li == 0 else -2.6,
			"alpha_limit": 0.40 * p_alpha_factor,
			"is_wave": 1.0,
			"ring_width": 0.10,
		}, radius * (1.55 + 0.35 * float(li)))
		add_child(foam_ring)
		_pulse_layers.append({"node": foam_ring, "offset": 0.10 * float(li), "spin": 1.4})
		awaken_layers += 1

	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_01, {
		"amount": awakened_particle_amount(12),
		"lifetime": duration * 1.2,
		"shape": "ring",
		"shape_radius": radius * 0.62,
		"vel_min": 40.0,
		"vel_max": radius * 1.6,
		"scale_min": 0.05,
		"scale_max": 0.12,
		"additive": false,
		"color_start": Color(0.78, 0.97, 1.0, 0.46 * p_alpha_factor),
		"color_end": Color(0.30, 0.76, 0.94, 0.0),
	}))
	awaken_layers += 1

func _build_awakened_ring_glow(alpha_cap: float, p_alpha_factor: float) -> void:
	var halo := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(color.r, color.g, color.b, 0.90),
		"accent_color": Color(1.0, 0.96, 0.80, 1.0),
		"petal_count": 8.0,
		"spin_speed": -1.6,
		"alpha_limit": alpha_cap * 0.92,
		"is_wave": 0.0,
	}, radius * 2.3)
	add_child(halo)
	_awaken_runes.append({"node": halo, "spin": -1.0})
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_01, {
		"amount": awakened_particle_amount(12),
		"lifetime": duration * 1.1,
		"shape": "ring",
		"shape_radius": radius * 0.45,
		"vel_min": 70.0,
		"vel_max": radius * 1.7,
		"scale_min": 0.035,
		"scale_max": 0.08,
		"color_start": Color(color.r, color.g, color.b, 0.9 * p_alpha_factor),
		"color_end": Color(color.r, color.g, color.b, 0.0),
	}))
	awaken_layers = 2

func setup_fusion_domain(
	ctrl: Node,
	p_node: Node2D,
	center: Vector2,
	kind: String,
	aoe_r: float,
	dmg: float,
	dur: float,
	dom_col: Color,
	chains: int = 0,
	area_mult: float = 1.0
) -> void:
	mode = Mode.FUSION_DOMAIN
	controller = ctrl
	player_node = p_node
	global_position = center
	domain_kind = kind
	radius = aoe_r
	damage = dmg
	duration = dur
	area_scale = maxf(0.5, area_mult)
	var base_a := clampf(dom_col.a, 0.25, 0.34)
	effective_alpha_limit = alpha_from_scale(base_a, area_scale)
	var p_alpha_factor := effective_alpha_limit / maxf(0.01, base_a)
	color = dom_col
	color.a = effective_alpha_limit
	domain_chain_count = chains
	awakened = true
	awakened_effect = "fusion_domain"
	z_index = -5

	if domain_kind == "orbit_burst_array":
		_domain_base = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_02, V2VfxFactory.SHADER_BURN_DISSOLVE, {
			"primary_color": Color(0.95, 0.38, 0.08, 0.95),
			"burn_color": Color(1.0, 0.82, 0.32, 1.0),
			"dissolve_amount": 0.06,
			"burn_size": 0.18,
			"alpha_limit": color.a,
		}, radius * 2.08)
		add_child(_domain_base)

		_domain_ring = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.98, 0.45, 0.09, 0.95),
			"accent_color": Color(1.0, 0.90, 0.48, 1.0),
			"petal_count": 6.0,
			"spin_speed": 1.8,
			"alpha_limit": minf(0.36, color.a + 0.06 * p_alpha_factor),
			"is_wave": 0.0,
		}, radius * 2.05)
		add_child(_domain_ring)

		for i in range(6):
			var sw := Sprite2D.new()
			sw.texture = TEX_JADE_SWORD
			sw.scale = Vector2(0.14, 0.14)
			sw.modulate = Color(1.25, 0.72, 0.35, 0.82 * p_alpha_factor)
			sw.z_index = 1
			var fl := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, 140.0, Color(1.0, 0.65, 0.22, 0.65 * p_alpha_factor), true)
			sw.add_child(fl)
			add_child(sw)
			_domain_swords.append(sw)

		_zone_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_FLAME_04, {
			"amount": 16,
			"lifetime": 0.65,
			"one_shot": false,
			"local_coords": true,
			"shape": "ring",
			"shape_radius": radius * 0.82,
			"shape_inner_radius": radius * 0.35,
			"gravity": Vector3(0.0, -45.0, 0.0),
			"vel_min": 8.0,
			"vel_max": 28.0,
			"scale_min": 0.04,
			"scale_max": 0.09,
			"color_start": Color(1.0, 0.56, 0.16, 0.55 * p_alpha_factor),
			"color_end": Color(0.95, 0.24, 0.05, 0.0),
		})
		add_child(_zone_particles)
	else:
		_domain_base = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.38, 0.65, 0.98, 0.95),
			"accent_color": Color(0.80, 0.96, 1.0, 1.0),
			"petal_count": 8.0,
			"spin_speed": 1.3,
			"alpha_limit": color.a,
			"is_wave": 0.0,
		}, radius * 2.1)
		add_child(_domain_base)

		_domain_ring = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(0.24, 0.78, 0.98, 0.90),
			"accent_color": Color(0.88, 0.94, 1.0, 1.0),
			"petal_count": 8.0,
			"spin_speed": -2.2,
			"alpha_limit": minf(0.34, color.a + 0.04 * p_alpha_factor),
			"is_wave": 0.0,
		}, radius * 1.6)
		add_child(_domain_ring)

		_domain_rim_arc = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 11.0, {
			"bolt_color": Color(0.38, 0.65, 0.98, 0.65 * p_alpha_factor),
			"core_color": Color(0.85, 0.96, 1.0, 0.90 * p_alpha_factor),
			"speed": 18.0,
			"jitter_amp": 0.46,
			"thickness": 0.11,
			"taper_ends": 0.0,
			"fade": 0.45,
		})
		var rim_pts := PackedVector2Array()
		for i in range(24):
			var a := float(i) * TAU / 24.0
			var rj := radius * (0.92 + (0.05 if i % 2 == 0 else -0.04))
			rim_pts.append(Vector2(cos(a), sin(a)) * rj)
		rim_pts.append(rim_pts[0])
		_domain_rim_arc.points = rim_pts
		add_child(_domain_rim_arc)

		_zone_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_04, {
			"amount": 14,
			"lifetime": 0.75,
			"one_shot": false,
			"local_coords": true,
			"shape": "ring",
			"shape_radius": radius * 0.85,
			"tangent_min": 45.0,
			"tangent_max": 85.0,
			"vel_min": 6.0,
			"vel_max": 22.0,
			"scale_min": 0.035,
			"scale_max": 0.07,
			"color_start": Color(0.68, 0.94, 1.0, 0.55 * p_alpha_factor),
			"color_end": Color(0.38, 0.65, 0.98, 0.0),
		})
		add_child(_zone_particles)

		_lotus_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
			"amount": 8,
			"lifetime": 0.45,
			"one_shot": false,
			"local_coords": true,
			"shape": "ring",
			"shape_radius": radius * 0.82,
			"vel_min": 10.0,
			"vel_max": 35.0,
			"scale_min": 0.03,
			"scale_max": 0.06,
			"color_start": Color(0.75, 0.88, 1.0, 0.65 * p_alpha_factor),
			"color_end": Color(0.38, 0.65, 0.98, 0.0),
		})
		add_child(_lotus_particles)

	var rune := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(color.r, color.g, color.b, 0.85),
		"accent_color": Color(1.0, 0.94, 0.66, 1.0),
		"petal_count": 8.0,
		"spin_speed": -1.2,
		"alpha_limit": minf(0.34, color.a + 0.05 * p_alpha_factor),
		"is_wave": 0.0,
	}, radius * 2.42)
	rune.z_index = 1
	add_child(rune)
	_awaken_runes.append({"node": rune, "spin": -0.9})
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_09, {
		"amount": awakened_particle_amount(12),
		"lifetime": 0.9,
		"one_shot": false,
		"local_coords": true,
		"shape": "ring",
		"shape_radius": radius * 0.95,
		"tangent_min": 35.0,
		"tangent_max": 70.0,
		"vel_min": 8.0,
		"vel_max": 26.0,
		"scale_min": 0.03,
		"scale_max": 0.07,
		"color_start": Color(1.0, 0.90, 0.52, 0.70 * p_alpha_factor),
		"color_end": Color(color.r, color.g, color.b, 0.0),
	}))
	awaken_layers = 2

func _physics_process(delta: float) -> void:
	elapsed += delta
	match mode:
		Mode.BOOMERANG:
			_step_boomerang(delta)
		Mode.BURN_LOB:
			_step_burn_lob(delta)
		Mode.CHAIN_BOLT:
			if elapsed >= duration:
				queue_free()
				return
			_bolt_flicker_acc += delta
			if _bolt_flicker_acc >= 0.045:
				_bolt_flicker_acc -= 0.045
				_refresh_lightning_geometry()
				for entry in _bolt_arc_sprites:
					var sp := entry.get("sprite", null) as Sprite2D
					if sp != null and is_instance_valid(sp):
						sp.frame = (sp.frame + 1) % THUNDER_ARC_FRAMES
			var fade := clampf(1.0 - elapsed / duration, 0.0, 1.0)
			for entry in _bolt_arc_sprites:
				var sp := entry.get("sprite", null) as Sprite2D
				if sp != null and is_instance_valid(sp):
					sp.modulate.a = float(entry.get("base_alpha", 0.56)) * fade
			if _bolt_main != null and _bolt_main.material is ShaderMaterial:
				(_bolt_main.material as ShaderMaterial).set_shader_parameter("fade", fade)
			if _bolt_core != null and is_instance_valid(_bolt_core):
				_bolt_core.modulate.a = fade
			if _bolt_sky_core != null and is_instance_valid(_bolt_sky_core):
				_bolt_sky_core.modulate.a = fade
			for sub in _bolt_sub_branches:
				if sub != null and is_instance_valid(sub):
					sub.modulate.a = fade * 0.85
			if _bolt_branch != null and _bolt_branch.material is ShaderMaterial:
				(_bolt_branch.material as ShaderMaterial).set_shader_parameter("fade", fade * 0.85)
			if _bolt_sky != null and _bolt_sky.material is ShaderMaterial:
				(_bolt_sky.material as ShaderMaterial).set_shader_parameter("fade", fade)
			if _bolt_fork != null and _bolt_fork.material is ShaderMaterial:
				(_bolt_fork.material as ShaderMaterial).set_shader_parameter("fade", fade * 0.9)
			for tendril in _bolt_tendrils:
				if tendril != null and tendril.material is ShaderMaterial:
					(tendril.material as ShaderMaterial).set_shader_parameter("fade", fade * 0.8)
			if _bolt_scorch != null and _bolt_scorch.material is ShaderMaterial:
				var smat := _bolt_scorch.material as ShaderMaterial
				smat.set_shader_parameter("dissolve_amount", clampf(elapsed / maxf(0.01, duration), 0.0, 0.85))
				smat.set_shader_parameter("fade", fade)
		Mode.ICE_SHARD:
			_step_ice_shard(delta)
		Mode.PULSE_RING:
			if elapsed >= duration:
				queue_free()
				return
			_step_pulse_ring(delta)
		Mode.FUSION_DOMAIN:
			_step_fusion_domain(delta)
		Mode.WATER_SPLASH:
			_step_water_splash(delta)

func _step_boomerang(delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	var rain_alive := _step_awakened_blade(delta) if awakened else false

	match _sword_phase:
		SwordPhase.RAIN_TRAILING:
			if not rain_alive:
				queue_free()
			return
		SwordPhase.FLYING:
			spin_ang += delta * 18.0
			if _main_sprite != null:
				_main_sprite.rotation = dir.angle() + PI * 0.25
			if _glow_sprite != null:
				_glow_sprite.rotation = -spin_ang * 0.5

			trail.append(global_position)
			if trail.size() > _trail_limit:
				trail.remove_at(0)
			if _trail_line != null and trail.size() >= 2:
				_trail_line.points = PackedVector2Array(trail)
			if _awaken_core != null and trail.size() >= 2:
				_awaken_core.points = PackedVector2Array(trail)

			var step := speed * delta
			global_position += dir * step
			travelled += step
			_hit_nearby_boomerang(hit_out, true)
			if travelled >= max_range or pierce_left <= 0 or elapsed > 2.4:
				_finish_boomerang_flight(rain_alive)

func _finish_boomerang_flight(rain_alive: bool) -> void:
	if not rain_alive:
		queue_free()
		return
	_sword_phase = SwordPhase.RAIN_TRAILING
	if _main_sprite != null:
		_main_sprite.visible = false
	if _glow_sprite != null:
		_glow_sprite.visible = false
	if _trail_line != null:
		_trail_line.visible = false
	if _awaken_core != null:
		_awaken_core.visible = false
	if _trail_particles != null:
		_trail_particles.emitting = false

func _hit_nearby_boomerang(hit_map: Dictionary, dec_pierce: bool) -> void:
	for raw_e in CombatGrid.query(global_position, 28.0):
		var e := raw_e as Enemy
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		var eid := e.get_instance_id()
		if hit_map.has(eid):
			continue
		if global_position.distance_squared_to(e.global_position) > 30.0 * 30.0:
			continue
		hit_map[eid] = true
		controller.call("deal_v2_damage", e, damage, element, {"knockback_dir": dir, "knockback": 75.0})
		if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
			var hit_fx := V2ReactionFx.new()
			get_parent().add_child(hit_fx)
			hit_fx.setup_weapon_burst("sword_cross_burst" if awakened else "sword_hit", e.global_position, dir, 46.0 if awakened else 40.0, color)
		if dec_pierce:
			pierce_left -= 1
			if pierce_left <= 0:
				break

func _step_awakened_blade(delta: float) -> bool:
	if _awaken_formation != null:
		_awaken_formation.rotation += delta * 2.2
		_awaken_formation.modulate.a = clampf(1.0 - maxf(0.0, elapsed - 0.58) / 0.36, 0.0, 1.0)
	var alive := false
	for item in _awaken_swords:
		var sp := item.get("node") as Sprite2D
		var sw_trail := item.get("trail") as Line2D
		if sp == null or not is_instance_valid(sp):
			continue
		var life := float(item.get("life", 0.0)) + delta
		item["life"] = life
		var delay := float(item.get("delay", 0.05))
		var s_dir := item.get("dir", Vector2.RIGHT) as Vector2
		var pos := item.get("pos", Vector2.ZERO) as Vector2
		var base_sc := item.get("base_scale", sp.scale) as Vector2
		if life < delay:
			pos -= s_dir * (48.0 * delta)
			item["pos"] = pos
			sp.global_position = pos
			var charge_t := clampf(life / maxf(0.01, delay), 0.0, 1.0)
			sp.modulate.a = lerpf(0.45, 1.0, charge_t)
			sp.scale = base_sc * lerpf(0.78, 1.12, charge_t)
			alive = true
		elif life < delay + 0.54:
			var fly_t := life - delay
			pos += (item.get("vel", Vector2.ZERO) as Vector2) * delta
			item["pos"] = pos
			sp.global_position = pos
			sp.scale = base_sc
			sp.modulate.a = clampf(1.0 - maxf(0.0, fly_t - 0.34) / 0.20, 0.0, 1.0) * 0.96
			var pts: Array = item.get("pts", [])
			pts.append(pos)
			if pts.size() > 7:
				pts.remove_at(0)
			item["pts"] = pts
			if sw_trail != null and is_instance_valid(sw_trail):
				sw_trail.points = PackedVector2Array(pts)
				if sw_trail.material is ShaderMaterial:
					(sw_trail.material as ShaderMaterial).set_shader_parameter("fade", sp.modulate.a)
			var sword_hits: Dictionary = item.get("hit_ids", {})
			for raw_e in CombatGrid.query(pos, 26.0):
				var e := raw_e as Enemy
				if e == null or not is_instance_valid(e) or e.is_dead:
					continue
				var eid := e.get_instance_id()
				if sword_hits.has(eid):
					continue
				if pos.distance_squared_to(e.global_position) <= 28.0 * 28.0:
					sword_hits[eid] = true
					controller.call("deal_v2_damage", e, damage * 0.22, element, {"knockback_dir": s_dir, "knockback": 35.0})
					if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
						var burst := V2ReactionFx.new()
						get_parent().add_child(burst)
						burst.setup_weapon_burst("sword_cross_burst", e.global_position, s_dir, 42.0, Color(1.0, 0.88, 0.34))
			alive = true
		else:
			sp.visible = false
			if sw_trail != null and is_instance_valid(sw_trail):
				sw_trail.visible = false
	for item in _awaken_flames:
		var fl := item.get("node") as Sprite2D
		if fl == null or not is_instance_valid(fl):
			continue
		var base_sc := item.get("base", Vector2.ONE) as Vector2
		var phase := float(item.get("phase", 0.0))
		var pulse := 1.0 + 0.16 * sin(elapsed * 12.0 + phase)
		fl.scale = base_sc * pulse
		fl.rotation += float(item.get("spin", 0.0)) * delta
	return alive

func _step_burn_lob(delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	if awakened:
		_animate_awakened_fire(delta)
	if not landed:
		var t := clampf(elapsed / fly_dur, 0.0, 1.0)
		var arc := sin(t * PI) * 44.0
		global_position = start_pos.lerp(dest_pos, t) - Vector2(0.0, arc)
		trail.append(global_position)
		if trail.size() > 10:
			trail.remove_at(0)
		if _trail_line != null and trail.size() >= 2:
			_trail_line.points = PackedVector2Array(trail)
		if t >= 1.0:
			landed = true
			elapsed = 0.0
			z_index = -5
			global_position = dest_pos
			_enter_burn_zone_visuals()
			_detonate_burn_impact()
		return

	tick_acc += delta
	if tick_acc >= 0.5:
		tick_acc -= 0.5
		_tick_burn_zone()

	var fade := clampf(1.0 - maxf(0.0, elapsed - (zone_dur - 0.45)) / 0.45, 0.0, 1.0)
	var grow := clampf(elapsed / 0.30, 0.0, 1.0)
	if _scorch_sprite != null and _scorch_sprite.material is ShaderMaterial:
		var smat := _scorch_sprite.material as ShaderMaterial
		smat.set_shader_parameter("progress", grow)
		smat.set_shader_parameter("fade", fade)
	for item in _fire_tongues:
		var tg := item.get("node") as Sprite2D
		if tg == null or not is_instance_valid(tg):
			continue
		var base_sc := item.get("base", Vector2.ONE) as Vector2
		var ph := float(item.get("phase", 0.0))
		var pulse := 1.0 + 0.13 * sin(elapsed * 9.0 + ph) + 0.06 * sin(elapsed * 17.0 + ph * 1.7)
		tg.scale = Vector2(base_sc.x * (0.92 + 0.08 * sin(elapsed * 7.0 + ph)), base_sc.y * pulse) * (0.70 + 0.30 * fade)
		if tg.material is ShaderMaterial:
			(tg.material as ShaderMaterial).set_shader_parameter("fade", fade)
	if _perk_sprite != null:
		_perk_sprite.rotation += delta * 1.8
		if _perk_sprite.material is ShaderMaterial:
			(_perk_sprite.material as ShaderMaterial).set_shader_parameter("fade", fade)

	if elapsed >= zone_dur:
		if implode_perk:
			_detonate_lotus_implosion()
		queue_free()
		return

func _add_fire_tongue(base: Vector2, h_px: float, tall: bool, zone_seed: float, idx: int) -> void:
	var tex: Texture2D = V2VfxFactory.TEX_FLAME_06 if tall else V2VfxFactory.TEX_FLAME_05
	var tongue := V2VfxFactory.make_shader_sprite(tex, V2VfxFactory.SHADER_FLAME_TONGUE, {
		"hot_color": Color(1.0, 0.80, 0.34, 1.0),
		"mid_color": Color(1.0, 0.42, 0.07, 1.0),
		"outer_color": Color(0.55, 0.10, 0.03, 1.0),
		"alpha_limit": clampf(effective_alpha_limit * 2.4, 0.70, 0.95),
		"seed": zone_seed + float(idx) * 3.7,
	}, h_px)
	tongue.position = base + Vector2(0.0, -h_px * 0.12)
	tongue.scale = Vector2(tongue.scale.x * randf_range(0.78, 1.12), tongue.scale.y)
	add_child(tongue)
	_fire_tongues.append({"node": tongue, "base": tongue.scale, "phase": float(idx) * 1.3})

func _enter_burn_zone_visuals() -> void:
	if _main_sprite != null:
		_main_sprite.queue_free()
		_main_sprite = null
	if _glow_sprite != null:
		_glow_sprite.queue_free()
		_glow_sprite = null
	if _trail_line != null:
		_trail_line.queue_free()
		_trail_line = null
	if _trail_particles != null:
		_trail_particles.emitting = false

	if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		var imp := V2ReactionFx.new()
		get_parent().add_child(imp)
		imp.setup_weapon_burst("fire_impact", global_position, Vector2.UP, radius, color)

	if awakened:
		_build_awakened_fire_zone()

	var z_alpha_factor := alpha_from_scale(1.0, area_scale)
	var zone_seed := float(randi() % 1024) * 0.37
	_scorch_sprite = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_03, V2VfxFactory.SHADER_GROUND_SCORCH, {
		"char_color": Color(0.10, 0.075, 0.055, 1.0),
		"ash_color": Color(0.32, 0.29, 0.25, 1.0),
		"progress": 0.0,
		"alpha_limit": clampf(effective_alpha_limit * 1.25, 0.30, 0.48),
		"noise_scale": 5.0,
		"seed": zone_seed,
	}, radius * 2.35)
	_scorch_sprite.z_index = -1
	add_child(_scorch_sprite)

	_fire_tongues.clear()
	var tongue_total := 12
	for i in range(tongue_total):
		var ang := TAU * float(i) / float(tongue_total) + randf_range(-0.16, 0.16)
		var base := Vector2(cos(ang), sin(ang) * 0.78) * radius * 0.92
		var tall := (i % 3) != 1
		var h_px := radius * (randf_range(0.95, 1.35) if tall else randf_range(0.62, 0.85))
		_add_fire_tongue(base, h_px, tall, zone_seed, i)
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + randf_range(-0.35, 0.35)
		var base := Vector2(cos(ang), sin(ang) * 0.78) * radius * randf_range(0.30, 0.52)
		_add_fire_tongue(base, radius * randf_range(0.45, 0.70), false, zone_seed, i + tongue_total)

	_zone_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
		"amount": 18,
		"lifetime": 0.85,
		"one_shot": false,
		"local_coords": true,
		"shape": "sphere",
		"shape_radius": radius * 0.72,
		"gravity": Vector3(0.0, -78.0, 0.0),
		"vel_min": 12.0,
		"vel_max": 34.0,
		"scale_min": 0.03,
		"scale_max": 0.06,
		"color_start": Color(1.0, 0.80, 0.32, 0.90 * z_alpha_factor),
		"color_end": Color(0.88, 0.20, 0.04, 0.0),
	})
	add_child(_zone_particles)

	_smoke_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_08, {
		"amount": 6,
		"lifetime": 1.2,
		"one_shot": false,
		"additive": false,
		"local_coords": true,
		"shape": "sphere",
		"shape_radius": radius * 0.68,
		"gravity": Vector3(0.0, -20.0, 0.0),
		"vel_min": 5.0,
		"vel_max": 16.0,
		"damping_min": 6.0,
		"damping_max": 14.0,
		"scale_min": 0.10,
		"scale_max": 0.22,
		"color_start": Color(0.30, 0.28, 0.26, 0.20 * z_alpha_factor),
		"color_end": Color(0.18, 0.17, 0.16, 0.0),
	})
	_smoke_particles.z_index = -1
	add_child(_smoke_particles)

	if implode_perk:
		_perk_sprite = V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": Color(1.0, 0.48, 0.14, 0.90),
			"accent_color": Color(1.0, 0.88, 0.42, 1.0),
			"petal_count": 8.0,
			"spin_speed": 2.4,
			"alpha_limit": 0.34 * z_alpha_factor,
			"is_wave": 0.0,
		}, radius * 1.5)
		add_child(_perk_sprite)

		_lotus_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_04, {
			"amount": 12,
			"lifetime": 0.48,
			"one_shot": false,
			"local_coords": true,
			"shape": "ring",
			"shape_radius": radius * 0.9,
			"shape_inner_radius": radius * 0.75,
			"radial_min": -110.0,
			"radial_max": -60.0,
			"vel_min": 4.0,
			"vel_max": 16.0,
			"scale_min": 0.03,
			"scale_max": 0.06,
			"color_start": Color(1.0, 0.78, 0.32, 0.72 * z_alpha_factor),
			"color_end": Color(0.98, 0.32, 0.08, 0.0),
		})
		add_child(_lotus_particles)

func _build_awakened_fire_zone() -> void:
	for item in _awaken_flames:
		var old := item.get("node") as Sprite2D
		if old == null or not is_instance_valid(old):
			continue
		old.visible = false
	_awaken_flames.clear()
	var zone_seed := float(randi() % 1024) * 0.31
	for i in range(16):
		var ang := TAU * float(i) / 16.0 + randf_range(-0.12, 0.12)
		var base := Vector2(cos(ang), sin(ang) * 0.78) * radius * 0.94
		var h_px := radius * randf_range(1.05, 1.55)
		var tongue := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_FLAME_06, V2VfxFactory.SHADER_FLAME_TONGUE, {
			"hot_color": Color(1.0, 0.84, 0.40, 1.0),
			"mid_color": Color(1.0, 0.40, 0.06, 1.0),
			"outer_color": Color(0.50, 0.08, 0.02, 1.0),
			"alpha_limit": 0.92,
			"seed": zone_seed + float(i) * 2.9,
		}, h_px)
		tongue.position = base + Vector2(0.0, -h_px * 0.12)
		tongue.scale = Vector2(tongue.scale.x * randf_range(0.8, 1.15), tongue.scale.y)
		add_child(tongue)
		_awaken_flames.append({"node": tongue, "base": tongue.scale, "phase": float(i) * 1.1, "spin": 0.0})

	for i in range(8):
		var ang := TAU * float(i) / 8.0 + randf_range(-0.3, 0.3)
		var base := Vector2(cos(ang), sin(ang) * 0.78) * radius * randf_range(0.25, 0.62)
		var h_px := radius * randf_range(0.65, 1.0)
		var tongue := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_FLAME_05, V2VfxFactory.SHADER_FLAME_TONGUE, {
			"hot_color": Color(1.0, 0.82, 0.38, 1.0),
			"mid_color": Color(1.0, 0.36, 0.05, 1.0),
			"outer_color": Color(0.46, 0.06, 0.02, 1.0),
			"alpha_limit": 0.86,
			"seed": zone_seed + float(i) * 4.3,
		}, h_px)
		tongue.position = base + Vector2(0.0, -h_px * 0.12)
		add_child(tongue)
		_awaken_flames.append({"node": tongue, "base": tongue.scale, "phase": float(i) * 1.7, "spin": 0.0})

	for i in range(3):
		var pa := TAU * float(i) / 3.0 + 0.4
		var h_px := radius * randf_range(1.25, 1.50)
		var pil := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_FLAME_06, V2VfxFactory.SHADER_FLAME_TONGUE, {
			"hot_color": Color(1.0, 0.88, 0.46, 1.0),
			"mid_color": Color(1.0, 0.44, 0.07, 1.0),
			"outer_color": Color(0.54, 0.09, 0.02, 1.0),
			"alpha_limit": 0.95,
			"seed": zone_seed + 11.0 + float(i) * 5.1,
		}, h_px)
		pil.position = Vector2(cos(pa), sin(pa) * 0.76) * radius * 0.50 + Vector2(0.0, -h_px * 0.12)
		add_child(pil)
		_awaken_pillars.append({"node": pil, "base": pil.scale, "life": 0.0, "delay": float(i) * 0.08})

	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
		"amount": awakened_particle_amount(14),
		"lifetime": 0.85,
		"one_shot": false,
		"local_coords": true,
		"shape": "sphere",
		"shape_radius": radius * 0.80,
		"gravity": Vector3(0.0, -68.0, 0.0),
		"vel_min": 10.0,
		"vel_max": 36.0,
		"scale_min": 0.028,
		"scale_max": 0.06,
		"color_start": Color(1.0, 0.88, 0.46, 0.90),
		"color_end": Color(0.95, 0.26, 0.04, 0.0),
	}))
	add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
		"amount": awakened_particle_amount(10),
		"lifetime": 0.65,
		"one_shot": false,
		"local_coords": true,
		"shape": "ring",
		"shape_radius": radius * 0.88,
		"shape_inner_radius": radius * 0.45,
		"gravity": Vector3(0.0, -50.0, 0.0),
		"vel_min": 5.0,
		"vel_max": 18.0,
		"scale_min": 0.03,
		"scale_max": 0.065,
		"color_start": Color(1.0, 0.58, 0.16, 0.78),
		"color_end": Color(0.90, 0.20, 0.04, 0.0),
	}))

	if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		var surge := V2AttackFx.new()
		get_parent().add_child(surge)
		surge.setup_pulse_ring(global_position, radius * 1.24, color, 0.45, true, "fire_surge", area_scale)
	awaken_layers = 5

func _animate_awakened_fire(delta: float) -> void:
	var fade := clampf(1.0 - maxf(0.0, elapsed - (zone_dur - 0.45)) / 0.45, 0.0, 1.0)
	for item in _awaken_flames:
		var fl := item.get("node") as Sprite2D
		if fl == null or not is_instance_valid(fl) or not fl.visible:
			continue
		var base_sc := item.get("base", Vector2.ONE) as Vector2
		var phase := float(item.get("phase", 0.0))
		var wobble := 1.0 + 0.12 * sin(elapsed * 11.0 + phase) + 0.06 * sin(elapsed * 23.0 + phase * 0.7)
		fl.scale = base_sc * wobble
		if fl.material is ShaderMaterial:
			(fl.material as ShaderMaterial).set_shader_parameter("fade", fade)
		var spin_v := float(item.get("spin", 0.0))
		if absf(spin_v) > 0.001:
			fl.rotation += spin_v * delta
	for item in _awaken_pillars:
		var pil := item.get("node") as Sprite2D
		if pil == null or not is_instance_valid(pil):
			continue
		var life := float(item.get("life", 0.0)) + delta
		item["life"] = life
		var delay := float(item.get("delay", 0.0))
		var base_sc := item.get("base", Vector2.ONE) as Vector2
		var grow := clampf((life - delay) / 0.18, 0.0, 1.0)
		var pil_fade := clampf(1.0 - maxf(0.0, life - 0.34) / 0.36, 0.0, 1.0)
		pil.scale = base_sc * (0.4 + 0.6 * grow) * Vector2(1.0, 1.0 + 0.22 * sin(life * 9.0))
		if pil.material is ShaderMaterial:
			(pil.material as ShaderMaterial).set_shader_parameter("fade", clampf(grow, 0.0, 1.0) * pil_fade)
		else:
			pil.modulate.a = clampf(grow, 0.0, 1.0) * pil_fade * 0.88


func _detonate_burn_impact() -> void:
	var dot_m := float(controller.call("get_dot_mult")) if controller.has_method("get_dot_mult") else 1.0
	for e in CombatGrid.query(global_position, radius):
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= radius * radius:
			controller.call("deal_v2_damage", e, damage, element, {})
			if not e.is_dead and burn_dur > 0.0 and e.has_method("apply_dot"):
				e.apply_dot(tick_dps * dot_m, burn_dur, false, "fire")

func _tick_burn_zone() -> void:
	var tick_dmg := tick_dps * 0.5
	var dot_m := float(controller.call("get_dot_mult")) if controller.has_method("get_dot_mult") else 1.0
	for raw_e in CombatGrid.query(global_position, radius):
		var e := raw_e as Enemy
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= radius * radius:
			controller.call("deal_v2_damage", e, tick_dmg, element, {"is_dot": true})
			if not e.is_dead and burn_dur > 0.0 and e.has_method("apply_dot"):
				e.apply_dot(tick_dps * dot_m, burn_dur, false, "fire")
			if implode_perk and e.has_method("apply_knockback"):
				var pull := (global_position - e.global_position).normalized() * 32.0
				e.apply_knockback(pull)

func _detonate_lotus_implosion() -> void:
	if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		var burst_fx := V2ReactionFx.new()
		get_parent().add_child(burst_fx)
		burst_fx.setup_weapon_burst("lotus_implosion", global_position, Vector2.UP, radius, color)
	var burst := damage * 0.8
	for e in CombatGrid.query(global_position, radius * 1.1):
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= (radius * 1.1) * (radius * 1.1):
			controller.call("deal_v2_damage", e, burst, element, {})

func _step_ice_shard(delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	var step := speed * delta
	global_position += dir * step
	travelled += step

	trail.append(global_position)
	if trail.size() > _trail_limit:
		trail.remove_at(0)
	if _trail_line != null and trail.size() >= 2:
		_trail_line.points = PackedVector2Array(trail)
	if _perk_sprite != null:
		_perk_sprite.rotation += delta * 6.0
	if _mist_sprite != null:
		_mist_sprite.rotation -= delta * 7.5
	for item in _awaken_orbit:
		var crystal := item.get("node") as Sprite2D
		if crystal == null or not is_instance_valid(crystal):
			continue
		var ang := float(item.get("ang", 0.0)) + elapsed * 6.0
		crystal.position = Vector2(cos(ang), sin(ang)) * float(item.get("radius", 30.0))
		crystal.rotation -= delta * 4.5

	for raw_e in CombatGrid.query(global_position, 22.0):
		var e := raw_e as Enemy
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		var eid := e.get_instance_id()
		if hit_ids.has(eid):
			continue
		if global_position.distance_squared_to(e.global_position) > 24.0 * 24.0:
			continue
		hit_ids[eid] = true
		if e.has_method("apply_slow") and slow_pct > 0.0:
			e.apply_slow(slow_pct, slow_dur)
		controller.call("deal_v2_damage", e, damage, element, {"shot_id": shot_id, "knockback_dir": dir, "knockback": 45.0})
		if split_on_hit and get_parent() != null:
			split_on_hit = false
			if V2VfxFactory.can_spawn_transient(get_parent()):
				var sh_fx := V2ReactionFx.new()
				get_parent().add_child(sh_fx)
				sh_fx.setup_weapon_burst("frost_wheel_shatter", global_position, dir, 48.0, color)
			for k in [-1, 0, 1]:
				var sub := V2AttackFx.new()
				get_parent().add_child(sub)
				sub.setup_ice_shard(controller, global_position, dir.rotated(float(k) * 0.48), damage * 0.45, 150.0, shot_id, slow_pct * 0.6, 1.2, color, false, 1)
		pierce_left -= 1
		if pierce_left <= 0:
			queue_free()
			return
	if travelled >= max_range:
		queue_free()
		return

func _step_pulse_ring(delta: float) -> void:
	var t := clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	var fade := clampf(1.0 - maxf(0.0, t - 0.5) / 0.5, 0.0, 1.0)
	if _pulse_primary != null and _pulse_primary.material is ShaderMaterial:
		var mat := _pulse_primary.material as ShaderMaterial
		mat.set_shader_parameter("progress", t)
		mat.set_shader_parameter("fade", fade)
	if _pulse_secondary != null and _pulse_secondary.material is ShaderMaterial:
		var mat2 := _pulse_secondary.material as ShaderMaterial
		if pulse_style == "bell_echo":
			var echo_t := clampf((elapsed - 0.12) / maxf(0.001, duration - 0.12), 0.0, 1.0)
			mat2.set_shader_parameter("progress", echo_t)
			mat2.set_shader_parameter("fade", clampf(1.0 - echo_t, 0.0, 1.0) if elapsed >= 0.12 else 0.0)
		elif pulse_style == "venom_dual" or pulse_style == "fusion_zen_bell":
			mat2.set_shader_parameter("dissolve_amount", smoothstep(0.15, 1.0, t))
			mat2.set_shader_parameter("fade", fade)
		else:
			mat2.set_shader_parameter("progress", t)
			mat2.set_shader_parameter("fade", fade)
	for item in _pulse_layers:
		var layer := item.get("node") as Sprite2D
		if layer == null or not is_instance_valid(layer):
			continue
		var offset := float(item.get("offset", 0.0))
		var layer_t := clampf((t - offset) / maxf(0.001, 1.0 - offset), 0.0, 1.0)
		layer.rotation += float(item.get("spin", 1.0)) * delta
		layer.modulate.a = clampf((t - offset) / 0.08, 0.0, 1.0) * (1.0 - smoothstep(0.72, 1.0, layer_t))
		if layer.material is ShaderMaterial:
			var lmat := layer.material as ShaderMaterial
			lmat.set_shader_parameter("progress", layer_t)
			lmat.set_shader_parameter("fade", clampf(1.0 - layer_t * 0.92, 0.0, 1.0))

	for item in _awaken_thorns:
		var thorn := item.get("node") as Sprite2D
		if thorn == null or not is_instance_valid(thorn):
			continue
		var delay := float(item.get("delay", 0.0))
		var th_t := clampf((t - delay) / 0.55, 0.0, 1.0)
		var ang := float(item.get("ang", 0.0))
		thorn.position = Vector2(cos(ang), sin(ang)) * radius * lerpf(0.35, 1.04, th_t)
		thorn.modulate.a = clampf(th_t / 0.14, 0.0, 1.0) * (1.0 - smoothstep(0.68, 1.0, th_t)) * 0.92

	for item in _awaken_runes:
		var rune := item.get("node") as Sprite2D
		if rune == null or not is_instance_valid(rune):
			continue
		rune.rotation += float(item.get("spin", 1.0)) * delta
		rune.modulate.a = clampf(t / 0.12, 0.0, 1.0)
		if rune.material is ShaderMaterial:
			(rune.material as ShaderMaterial).set_shader_parameter("fade", clampf(1.0 - smoothstep(0.5, 1.0, t), 0.0, 1.0))

	for line in _awaken_tendrils:
		if line != null and line.material is ShaderMaterial:
			(line.material as ShaderMaterial).set_shader_parameter("fade", clampf(1.0 - smoothstep(0.55, 1.0, t), 0.0, 1.0))

func setup_water_splash(
	ctrl: Node,
	origin: Vector2,
	target_pos: Vector2,
	impact_dmg: float,
	aoe_r: float,
	sl_pct: float,
	sl_dur: float,
	elem: String,
	wave_col: Color,
	double_tide: bool = false,
	awakened_flag: bool = false
) -> void:
	mode = Mode.WATER_SPLASH
	controller = ctrl
	global_position = origin
	start_pos = origin
	dest_pos = target_pos
	damage = impact_dmg
	radius = aoe_r
	slow_pct = sl_pct
	slow_dur = sl_dur
	element = elem
	color = wave_col
	_water_double_tide = double_tide
	_water_second_done = false
	fly_dur = 0.24
	z_index = 4

	_trail_line = V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 14.0, {
		"primary_color": Color(0.22, 0.86, 0.98, 0.78),
		"edge_color": Color(0.90, 0.99, 1.0, 1.0),
		"intensity": 1.35,
		"use_texture_mask": 0.0,
	}, V2VfxFactory.make_taper_curve(0.06, 1.0))
	_trail_line.top_level = true
	_trail_line.z_index = 3
	add_child(_trail_line)

	_glow_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_LIGHT_01, 38.0, Color(0.45, 0.95, 1.0, 0.88), true)
	add_child(_glow_sprite)
	_main_sprite = V2VfxFactory.make_sprite(V2VfxFactory.TEX_TWIRL_02, 32.0, Color(0.24, 0.88, 0.98, 0.95), true)
	add_child(_main_sprite)
	_trail_particles = V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_06, {
		"amount": 9,
		"lifetime": 0.24,
		"one_shot": false,
		"local_coords": false,
		"vel_min": 14.0,
		"vel_max": 42.0,
		"scale_min": 0.025,
		"scale_max": 0.055,
		"color_start": Color(0.68, 0.97, 1.0, 0.90),
		"color_end": Color(0.16, 0.76, 0.96, 0.0),
	})
	add_child(_trail_particles)

	if awakened_flag:
		awakened = true
		awakened_effect = "double_water_tide"
		_trail_limit = 12
		if _trail_line != null:
			_trail_line.width = 20.0
		_trail_particles.amount = awakened_particle_amount(14)
		for i in range(3):
			var crest := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, 22.0 - float(i) * 4.0, {
				"primary_color": Color(0.30, 0.90, 1.0, 0.95),
				"edge_color": Color(0.86, 1.0, 1.0, 1.0),
				"intensity": 1.6,
				"use_texture_mask": 0.0,
			}, V2VfxFactory.make_taper_curve(0.04, 1.0))
			var pts := PackedVector2Array()
			var rr := 80.0 + float(i) * 30.0
			for s in range(33):
				var a := TAU * float(s) / 32.0
				pts.append(Vector2(cos(a), sin(a)) * rr * (1.0 + 0.035 * sin(a * 5.0 + float(i) * 1.7)))
			crest.points = pts
			crest.visible = false
			crest.z_index = 1
			add_child(crest)
			_awaken_crests.append({"node": crest, "delay": float(i) * 0.06})
		awaken_layers = 3

func _enter_water_impact() -> void:
	for item in _awaken_crests:
		var crest := item.get("node") as Line2D
		if crest == null or not is_instance_valid(crest):
			continue
		crest.visible = true
		crest.scale = Vector2(0.35, 0.35)
		crest.modulate.a = 0.95

	var foam := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_01, {
		"amount": awakened_particle_amount(14),
		"lifetime": 0.55,
		"one_shot": true,
		"explosiveness": 0.9,
		"shape": "ring",
		"shape_radius": radius * 0.55,
		"vel_min": 60.0,
		"vel_max": radius * 1.7,
		"scale_min": 0.06,
		"scale_max": 0.14,
		"additive": false,
		"color_start": Color(0.82, 0.98, 1.0, 0.55),
		"color_end": Color(0.36, 0.80, 0.96, 0.0),
	})
	add_child(foam)
	var spray := V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_06, {
		"amount": awakened_particle_amount(16),
		"lifetime": 0.48,
		"one_shot": true,
		"explosiveness": 0.92,
		"gravity": Vector3(0.0, 180.0, 0.0),
		"vel_min": 90.0,
		"vel_max": radius * 2.2,
		"scale_min": 0.03,
		"scale_max": 0.075,
		"color_start": Color(0.86, 0.99, 1.0, 0.95),
		"color_end": Color(0.30, 0.80, 0.98, 0.0),
	})
	add_child(spray)

	if get_parent() != null and V2VfxFactory.can_spawn_transient(get_parent()):
		for i in range(2):
			var ripple := V2AttackFx.new()
			get_parent().add_child(ripple)
			ripple.setup_pulse_ring(global_position, radius * (0.62 + 0.52 * float(i)), color, 0.46 + 0.10 * float(i), true, "water_mirror", area_scale, true)
	awaken_layers += 2

func _step_water_splash(delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	if not landed:
		var t := clampf(elapsed / fly_dur, 0.0, 1.0)
		var arc := sin(t * PI) * 40.0
		global_position = start_pos.lerp(dest_pos, t) - Vector2(0.0, arc)
		trail.append(global_position)
		if trail.size() > _trail_limit:
			trail.remove_at(0)
		if _trail_line != null and trail.size() >= 2:
			_trail_line.points = PackedVector2Array(trail)
		if _main_sprite != null:
			_main_sprite.rotation += delta * 12.0
		if t >= 1.0:
			landed = true
			elapsed = 0.0
			global_position = dest_pos
			if _main_sprite != null:
				_main_sprite.visible = false
			if _glow_sprite != null:
				_glow_sprite.visible = false
			if _trail_particles != null:
				_trail_particles.emitting = false
			if _trail_line != null:
				_trail_line.clear_points()
			if awakened:
				_enter_water_impact()
			_detonate_water_wave(radius, damage)
		return

	if awakened:
		_step_awakened_water(delta)

	if _water_double_tide and not _water_second_done and elapsed >= 0.18:
		_water_second_done = true
		_detonate_water_wave(radius * 1.25, damage * 0.55)
		if "player" in controller and controller.player != null and is_instance_valid(controller.player) and controller.player.has_method("heal"):
			controller.player.heal(2.0)

	if elapsed >= (0.92 if awakened else (0.38 if _water_double_tide else 0.22)):
		queue_free()

func _step_awakened_water(delta: float) -> void:
	var fade := clampf(1.0 - elapsed / 0.95, 0.0, 1.0)
	for item in _awaken_crests:
		var crest := item.get("node") as Line2D
		if crest == null or not is_instance_valid(crest) or not crest.visible:
			continue
		var delay := float(item.get("delay", 0.0))
		var grow := clampf((elapsed - delay) / 0.46, 0.0, 1.0)
		crest.scale = Vector2.ONE * lerpf(0.35, 1.75, grow)
		crest.modulate.a = clampf(grow * 1.6, 0.0, 1.0) * fade
		crest.rotation += delta * 0.35

func _detonate_water_wave(wave_r: float, wave_dmg: float) -> void:
	if get_parent() != null:
		var wave_fx := V2AttackFx.new()
		get_parent().add_child(wave_fx)
		var w_area_m := float(controller.call("get_area_mult")) if (controller != null and is_instance_valid(controller) and controller.has_method("get_area_mult")) else area_scale
		wave_fx.setup_pulse_ring(global_position, wave_r, color, 0.38, true, "water_mirror", w_area_m, awakened)
	var r2 := wave_r * wave_r
	for raw_e in CombatGrid.query(global_position, wave_r):
		var e := raw_e as Enemy
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= r2:
			if e.has_method("apply_slow") and slow_pct > 0.0:
				e.apply_slow(slow_pct, slow_dur)
			var away := (e.global_position - global_position).normalized()
			if away.length_squared() < 0.001:
				away = Vector2.UP
			controller.call("deal_v2_damage", e, wave_dmg, element, {"knockback_dir": away, "knockback": 65.0})

func _step_fusion_domain(delta: float) -> void:
	if controller == null or not is_instance_valid(controller):
		queue_free()
		return
	if player_node != null and is_instance_valid(player_node) and domain_kind == "frost_wheel_auto_lightning":
		global_position = global_position.lerp(player_node.global_position, minf(1.0, delta * 3.0))

	var fade := clampf(1.0 - maxf(0.0, elapsed - (duration - 0.35)) / 0.35, 0.0, 1.0)
	if _domain_base != null and _domain_base.material is ShaderMaterial:
		var bmat := _domain_base.material as ShaderMaterial
		if domain_kind == "orbit_burst_array":
			bmat.set_shader_parameter("dissolve_amount", clampf(maxf(0.0, elapsed - (duration - 0.45)) / 0.45, 0.0, 1.0))
		bmat.set_shader_parameter("fade", fade)
	if _domain_ring != null:
		_domain_ring.rotation += delta * (1.6 if domain_kind == "orbit_burst_array" else -1.8)
		if _domain_ring.material is ShaderMaterial:
			(_domain_ring.material as ShaderMaterial).set_shader_parameter("fade", fade)

	for i in range(_domain_swords.size()):
		var sw := _domain_swords[i]
		var a := elapsed * 2.8 + float(i) * TAU / float(maxi(1, _domain_swords.size()))
		sw.position = Vector2(cos(a), sin(a)) * (radius * 0.72)
		sw.rotation = a + PI * 0.5
		sw.modulate.a = 0.82 * (effective_alpha_limit / 0.34) * fade

	if _domain_flash_timer > 0.0:
		_domain_flash_timer = maxf(0.0, _domain_flash_timer - delta)
	if _domain_rim_arc != null and _domain_rim_arc.material is ShaderMaterial:
		var arc_fade := (0.42 + 0.58 * (_domain_flash_timer / 0.22)) * fade
		(_domain_rim_arc.material as ShaderMaterial).set_shader_parameter("fade", arc_fade)
	for item in _awaken_runes:
		var rune := item.get("node") as Sprite2D
		if rune == null or not is_instance_valid(rune):
			continue
		rune.rotation += float(item.get("spin", 1.0)) * delta
		rune.modulate.a = fade

	domain_tick_acc += delta
	var interval := 0.35 if domain_kind == "orbit_burst_array" else 0.45
	if domain_tick_acc >= interval:
		domain_tick_acc -= interval
		var elem_use := ("fire" if int(elapsed * 4.0) % 2 == 0 else "metal") if domain_kind == "orbit_burst_array" else ("thunder" if int(elapsed * 3.0) % 2 == 0 else "ice")
		var hit_any: Array = []
		for e in CombatGrid.query(global_position, radius):
			if e == null or not is_instance_valid(e) or e.is_dead:
				continue
			if global_position.distance_squared_to(e.global_position) <= radius * radius:
				hit_any.append(e)
				if domain_kind == "frost_wheel_auto_lightning" and e.has_method("apply_slow"):
					e.apply_slow(0.45, 1.8)
				controller.call("deal_v2_damage", e, damage * 0.32, elem_use, {})
		if domain_kind == "frost_wheel_auto_lightning" and not hit_any.is_empty():
			_domain_flash_timer = 0.22
			controller.call("spawn_chain_from_targets", hit_any, damage * 0.55, "thunder", maxi(2, domain_chain_count), 170.0, color)

	if elapsed >= duration:
		queue_free()
		return
