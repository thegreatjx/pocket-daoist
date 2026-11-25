class_name V2VfxFactory
extends RefCounted

const SHADER_BURN_DISSOLVE: Shader = preload("res://shaders/burn_dissolve.gdshader")
const SHADER_ELECTRIC_ARC: Shader = preload("res://shaders/electric_arc.gdshader")
const SHADER_SWORD_GLINT_TRAIL: Shader = preload("res://shaders/sword_glint_trail.gdshader")
const SHADER_BAGUA_DOMAIN_WAVE: Shader = preload("res://shaders/bagua_domain_wave.gdshader")
const SHADER_BOSS_SHOCKWAVE: Shader = preload("res://shaders/boss_shockwave_ring.gdshader")
const SHADER_FIRE_FLAME_2D: Shader = preload("res://shaders/fire_flame_2d.gdshader")
const SHADER_GROUND_SCORCH: Shader = preload("res://shaders/ground_scorch.gdshader")
const SHADER_FLAME_TONGUE: Shader = preload("res://shaders/flame_tongue.gdshader")

const TEX_FIRE_01: Texture2D = preload("res://addons/kenney_particle_pack/fire_01.png")
const TEX_FIRE_02: Texture2D = preload("res://addons/kenney_particle_pack/fire_02.png")
const TEX_FLAME_01: Texture2D = preload("res://addons/kenney_particle_pack/flame_01.png")
const TEX_FLAME_02: Texture2D = preload("res://addons/kenney_particle_pack/flame_02.png")
const TEX_FLAME_03: Texture2D = preload("res://addons/kenney_particle_pack/flame_03.png")
const TEX_FLAME_04: Texture2D = preload("res://addons/kenney_particle_pack/flame_04.png")
const TEX_FLAME_05: Texture2D = preload("res://addons/kenney_particle_pack/flame_05.png")
const TEX_FLAME_06: Texture2D = preload("res://addons/kenney_particle_pack/flame_06.png")
const TEX_SCORCH_01: Texture2D = preload("res://addons/kenney_particle_pack/scorch_01.png")
const TEX_SCORCH_02: Texture2D = preload("res://addons/kenney_particle_pack/scorch_02.png")
const TEX_SCORCH_03: Texture2D = preload("res://addons/kenney_particle_pack/scorch_03.png")
const TEX_SPARK_01: Texture2D = preload("res://addons/kenney_particle_pack/spark_01.png")
const TEX_SPARK_02: Texture2D = preload("res://addons/kenney_particle_pack/spark_02.png")
const TEX_SPARK_04: Texture2D = preload("res://addons/kenney_particle_pack/spark_04.png")
const TEX_SPARK_05: Texture2D = preload("res://addons/kenney_particle_pack/spark_05.png")
const TEX_SPARK_06: Texture2D = preload("res://addons/kenney_particle_pack/spark_06.png")
const TEX_SPARK_07: Texture2D = preload("res://addons/kenney_particle_pack/spark_07.png")
const TEX_SLASH_01: Texture2D = preload("res://addons/kenney_particle_pack/slash_01.png")
const TEX_SLASH_02: Texture2D = preload("res://addons/kenney_particle_pack/slash_02.png")
const TEX_SLASH_03: Texture2D = preload("res://addons/kenney_particle_pack/slash_03.png")
const TEX_SLASH_04: Texture2D = preload("res://addons/kenney_particle_pack/slash_04.png")
const TEX_SCRATCH_01: Texture2D = preload("res://addons/kenney_particle_pack/scratch_01.png")
const TEX_TRACE_01: Texture2D = preload("res://addons/kenney_particle_pack/trace_01.png")
const TEX_TRACE_05: Texture2D = preload("res://addons/kenney_particle_pack/trace_05.png")
const TEX_TRACE_01_ROT: Texture2D = preload("res://addons/kenney_particle_pack/rotated/trace_01_rotated.png")
const TEX_STAR_01: Texture2D = preload("res://addons/kenney_particle_pack/star_01.png")
const TEX_STAR_04: Texture2D = preload("res://addons/kenney_particle_pack/star_04.png")
const TEX_STAR_06: Texture2D = preload("res://addons/kenney_particle_pack/star_06.png")
const TEX_STAR_08: Texture2D = preload("res://addons/kenney_particle_pack/star_08.png")
const TEX_STAR_09: Texture2D = preload("res://addons/kenney_particle_pack/star_09.png")
const TEX_FLARE_01: Texture2D = preload("res://addons/kenney_particle_pack/flare_01.png")
const TEX_LIGHT_01: Texture2D = preload("res://addons/kenney_particle_pack/light_01.png")
const TEX_SMOKE_01: Texture2D = preload("res://addons/kenney_particle_pack/smoke_01.png")
const TEX_SMOKE_04: Texture2D = preload("res://addons/kenney_particle_pack/smoke_04.png")
const TEX_SMOKE_07: Texture2D = preload("res://addons/kenney_particle_pack/smoke_07.png")
const TEX_SMOKE_08: Texture2D = preload("res://addons/kenney_particle_pack/smoke_08.png")
const TEX_SMOKE_10: Texture2D = preload("res://addons/kenney_particle_pack/smoke_10.png")
const TEX_DIRT_02: Texture2D = preload("res://addons/kenney_particle_pack/dirt_02.png")
const TEX_MAGIC_02: Texture2D = preload("res://addons/kenney_particle_pack/magic_02.png")
const TEX_MAGIC_03: Texture2D = preload("res://addons/kenney_particle_pack/magic_03.png")
const TEX_MAGIC_04: Texture2D = preload("res://addons/kenney_particle_pack/magic_04.png")
const TEX_MAGIC_05: Texture2D = preload("res://addons/kenney_particle_pack/magic_05.png")
const TEX_CIRCLE_02: Texture2D = preload("res://addons/kenney_particle_pack/circle_02.png")
const TEX_CIRCLE_03: Texture2D = preload("res://addons/kenney_particle_pack/circle_03.png")
const TEX_CIRCLE_05: Texture2D = preload("res://addons/kenney_particle_pack/circle_05.png")
const TEX_TWIRL_01: Texture2D = preload("res://addons/kenney_particle_pack/twirl_01.png")
const TEX_TWIRL_02: Texture2D = preload("res://addons/kenney_particle_pack/twirl_02.png")
const TEX_TWIRL_03: Texture2D = preload("res://addons/kenney_particle_pack/twirl_03.png")

const MAX_ACTIVE_TRANSIENT := 36
const MAX_ACTIVE_HIT_SPARK := 28
const MAX_ACTIVE_DEATH_VFX := 56

const HIT_VFX_TABLE := {
	"default": {"color": "#FFF5D6", "duration": 0.055, "boost": 1.75},
	"metal": {"color": "#FFF3C4", "duration": 0.045, "boost": 1.80},
	"fire": {"color": "#FF5A2A", "duration": 0.060, "boost": 1.85},
	"thunder": {"color": "#9E9BFF", "duration": 0.040, "boost": 1.90},
	"ice": {"color": "#48D8FF", "duration": 0.070, "boost": 1.80},
	"water": {"color": "#22E4EE", "duration": 0.065, "boost": 1.80},
	"wood": {"color": "#4ADE80", "duration": 0.060, "boost": 1.75},
	"venom": {"color": "#34E87A", "duration": 0.060, "boost": 1.75},
	"reaction": {"color": "#FFFFFF", "duration": 0.085, "boost": 2.20},
}

static func get_hit_vfx_spec(element: String, reaction_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Dictionary:
	if reaction_color.a > 0.01:
		var rx_entry: Dictionary = HIT_VFX_TABLE["reaction"]
		var boost := float(rx_entry.get("boost", 2.20))
		return {
			"key": "reaction",
			"base_color": reaction_color,
			"flash_color": Color(reaction_color.r * boost, reaction_color.g * boost, reaction_color.b * boost, 1.0),
			"duration": float(rx_entry.get("duration", 0.085)),
			"boost": boost,
		}
	var key := element if HIT_VFX_TABLE.has(element) else "default"
	var entry: Dictionary = HIT_VFX_TABLE[key]
	var base_c := Color.from_string(String(entry.get("color", "#FFF5D6")), Color(1.0, 0.96, 0.84, 1.0))
	var boost := float(entry.get("boost", 1.75))
	return {
		"key": key,
		"base_color": base_c,
		"flash_color": Color(base_c.r * boost, base_c.g * boost, base_c.b * boost, 1.0),
		"duration": float(entry.get("duration", 0.055)),
		"boost": boost,
	}

static func get_line_stretch_tex() -> Texture2D:
	return TEX_LIGHT_01

static func make_additive_mat() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return mat

static func make_shader_mat(shader: Shader, params: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for k in params.keys():
		mat.set_shader_parameter(String(k), params[k])
	return mat

static func make_sprite(tex: Texture2D, diameter_px: float, tint: Color = Color.WHITE, additive: bool = false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.modulate = tint
	if tex != null:
		var sz := tex.get_size()
		var max_dim := maxf(1.0, maxf(sz.x, sz.y))
		var sc := diameter_px / max_dim
		sp.scale = Vector2(sc, sc)
	if additive:
		sp.material = make_additive_mat()
	return sp

static func make_shader_sprite(tex: Texture2D, shader: Shader, params: Dictionary, diameter_px: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.material = make_shader_mat(shader, params)
	if tex != null:
		var sz := tex.get_size()
		var max_dim := maxf(1.0, maxf(sz.x, sz.y))
		var sc := diameter_px / max_dim
		sp.scale = Vector2(sc, sc)
	return sp

static func make_shader_line(shader: Shader, width: float, params: Dictionary, width_curve: Curve = null) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.texture = get_line_stretch_tex()
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	if width_curve != null:
		line.width_curve = width_curve
	line.material = make_shader_mat(shader, params)
	return line

static func make_sharp_lightning_line(width: float, default_col: Color, width_curve: Curve = null, additive: bool = true) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = default_col
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.antialiased = true
	if width_curve != null:
		line.width_curve = width_curve
	if additive:
		line.material = make_additive_mat()
	return line

static func make_taper_curve(tail_ratio: float = 0.08, head_ratio: float = 1.0) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, tail_ratio))
	c.add_point(Vector2(0.65, lerpf(tail_ratio, head_ratio, 0.72)))
	c.add_point(Vector2(1.0, head_ratio))
	return c

static func make_gpu_particles(tex: Texture2D, cfg: Dictionary) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = maxi(1, int(cfg.get("amount", 12)))
	p.lifetime = maxf(0.08, float(cfg.get("lifetime", 0.45)))
	p.one_shot = bool(cfg.get("one_shot", true))
	p.explosiveness = clampf(float(cfg.get("explosiveness", 0.9 if p.one_shot else 0.0)), 0.0, 1.0)
	p.local_coords = bool(cfg.get("local_coords", false))
	p.preprocess = float(cfg.get("preprocess", 0.0))

	if bool(cfg.get("additive", true)):
		p.material = make_additive_mat()

	var mat := ParticleProcessMaterial.new()
	var dir_v: Vector2 = cfg.get("direction", Vector2(0.0, -1.0))
	mat.direction = Vector3(dir_v.x, dir_v.y, 0.0)
	mat.spread = float(cfg.get("spread", 180.0))
	mat.gravity = cfg.get("gravity", Vector3.ZERO)

	mat.initial_velocity_min = float(cfg.get("vel_min", 40.0))
	mat.initial_velocity_max = float(cfg.get("vel_max", 110.0))
	mat.radial_accel_min = float(cfg.get("radial_min", 0.0))
	mat.radial_accel_max = float(cfg.get("radial_max", 0.0))
	mat.tangential_accel_min = float(cfg.get("tangent_min", 0.0))
	mat.tangential_accel_max = float(cfg.get("tangent_max", 0.0))
	mat.angular_velocity_min = float(cfg.get("ang_vel_min", -120.0))
	mat.angular_velocity_max = float(cfg.get("ang_vel_max", 120.0))
	mat.angle_min = float(cfg.get("angle_min", 0.0))
	mat.angle_max = float(cfg.get("angle_max", 360.0))
	mat.damping_min = float(cfg.get("damping_min", 40.0))
	mat.damping_max = float(cfg.get("damping_max", 80.0))

	var sc_min := float(cfg.get("scale_min", 0.04))
	var sc_max := float(cfg.get("scale_max", 0.09))
	mat.scale_min = sc_min
	mat.scale_max = maxf(sc_min, sc_max)

	var shape := String(cfg.get("shape", "point"))
	if shape == "sphere":
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = maxf(1.0, float(cfg.get("shape_radius", 24.0)))
	elif shape == "ring":
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		var outer_r := maxf(2.0, float(cfg.get("shape_radius", 40.0)))
		mat.emission_ring_radius = outer_r
		mat.emission_ring_inner_radius = clampf(float(cfg.get("shape_inner_radius", outer_r * 0.72)), 0.0, outer_r)
		mat.emission_ring_height = 0.0
		mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)

	var col_start: Color = cfg.get("color_start", Color.WHITE)
	var col_end: Color = cfg.get("color_end", Color(col_start.r, col_start.g, col_start.b, 0.0))
	var grad := Gradient.new()
	grad.set_color(0, col_start)
	grad.add_point(0.35, Color(lerpf(col_start.r, col_end.r, 0.35), lerpf(col_start.g, col_end.g, 0.35), lerpf(col_start.b, col_end.b, 0.35), col_start.a * 0.85))
	grad.set_color(grad.get_point_count() - 1, col_end)
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	var sc_curve := Curve.new()
	sc_curve.add_point(Vector2(0.0, float(cfg.get("curve_start", 0.75))))
	sc_curve.add_point(Vector2(0.32, float(cfg.get("curve_mid", 1.0))))
	sc_curve.add_point(Vector2(1.0, float(cfg.get("curve_end", 0.15))))
	var sc_tex := CurveTexture.new()
	sc_tex.curve = sc_curve
	mat.scale_curve = sc_tex

	p.process_material = mat
	p.emitting = bool(cfg.get("emitting", true))
	return p

static func can_spawn_transient(parent: Node, limit: int = MAX_ACTIVE_TRANSIENT) -> bool:
	if parent == null or not is_instance_valid(parent):
		return false
	var tree := parent.get_tree()
	if tree == null:
		return false
	return tree.get_nodes_in_group("v2_transient_vfx").size() < limit

static func elem_glyph_texture(elem: String) -> Texture2D:
	match elem:
		"fire": return TEX_FIRE_01
		"ice": return TEX_STAR_08
		"water": return TEX_CIRCLE_02
		"thunder": return TEX_SPARK_05
		"wood": return TEX_TWIRL_02
		"venom": return TEX_SMOKE_07
		"metal": return TEX_SLASH_01
		_: return TEX_FLARE_01

static func spawn_hit_spark(parent: Node, world_pos: Vector2, element: String = "", is_crit: bool = false, reaction_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	if not can_spawn_transient(parent, MAX_ACTIVE_HIT_SPARK):
		return
	var spec := get_hit_vfx_spec(element, reaction_color)
	var base_c: Color = spec.get("base_color", Color(1.0, 0.94, 0.78, 1.0)) as Color
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 7
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var flash_tex := TEX_SLASH_02 if (is_crit or element == "metal") else elem_glyph_texture(element)
	var dia := 52.0 if is_crit else 34.0
	var sp := make_sprite(flash_tex, dia, Color(base_c.r, base_c.g, base_c.b, 0.92), true)
	sp.rotation = randf() * TAU
	root.add_child(sp)

	var gp := make_gpu_particles(TEX_SPARK_01, {
		"amount": 8 if is_crit else 4,
		"lifetime": 0.22 if is_crit else 0.16,
		"one_shot": true,
		"explosiveness": 0.96,
		"vel_min": 65.0 if is_crit else 42.0,
		"vel_max": 165.0 if is_crit else 110.0,
		"scale_min": 0.030,
		"scale_max": 0.062 if is_crit else 0.045,
		"color_start": Color(base_c.r, base_c.g, base_c.b, 0.95),
		"color_end": Color(base_c.r, base_c.g, base_c.b, 0.0),
	})
	root.add_child(gp)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", sp.scale * (1.55 if is_crit else 1.35), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, 0.15)
	tw.chain().tween_interval(0.14)
	tw.chain().tween_callback(root.queue_free)

static func spawn_enemy_death_vfx(parent: Node, world_pos: Vector2, accent_col: Color, is_elite: bool = false, is_boss: bool = false) -> void:
	if not is_boss and not is_elite and not can_spawn_transient(parent, MAX_ACTIVE_DEATH_VFX):
		return
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 6
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var scale_m := 2.4 if is_boss else (1.55 if is_elite else 1.0)
	var flare := make_sprite(TEX_SCORCH_01 if (is_elite or is_boss) else TEX_FLARE_01, 66.0 * scale_m, Color(accent_col.r, accent_col.g, accent_col.b, 0.90), true)
	flare.rotation = randf() * TAU
	root.add_child(flare)

	var mist := make_gpu_particles(TEX_SMOKE_07, {
		"amount": 16 if is_boss else (10 if is_elite else 6),
		"lifetime": 0.42 * scale_m,
		"one_shot": true,
		"explosiveness": 0.92,
		"additive": false,
		"vel_min": 28.0 * scale_m,
		"vel_max": 95.0 * scale_m,
		"scale_min": 0.055 * scale_m,
		"scale_max": 0.115 * scale_m,
		"color_start": Color(accent_col.r * 0.55, accent_col.g * 0.55, accent_col.b * 0.55, 0.65),
		"color_end": Color(0.10, 0.12, 0.14, 0.0),
	})
	root.add_child(mist)

	var wisps := make_gpu_particles(TEX_STAR_04 if (is_elite or is_boss) else TEX_SPARK_04, {
		"amount": 22 if is_boss else (12 if is_elite else 7),
		"lifetime": 0.36 * scale_m,
		"one_shot": true,
		"explosiveness": 0.95,
		"vel_min": 55.0 * scale_m,
		"vel_max": 160.0 * scale_m,
		"gravity": Vector3(0.0, -90.0, 0.0),
		"scale_min": 0.032 * scale_m,
		"scale_max": 0.068 * scale_m,
		"color_start": Color(1.0, 0.96, 0.85, 0.95),
		"color_end": Color(accent_col.r, accent_col.g, accent_col.b, 0.0),
	})
	root.add_child(wisps)

	var wave_sp: Sprite2D = null
	if is_elite or is_boss:
		wave_sp = make_shader_sprite(TEX_MAGIC_04, SHADER_BAGUA_DOMAIN_WAVE, {
			"primary_color": accent_col,
			"accent_color": Color(1.0, 0.94, 0.68, 1.0),
			"progress": 0.05,
			"ring_width": 0.18,
			"petal_count": 8.0,
			"spin_speed": 2.4,
			"alpha_limit": 0.72,
			"is_wave": 1.0,
			"fade": 1.0,
		}, 180.0 * scale_m)
		wave_sp.material.set_shader_parameter("progress", 0.05)
		root.add_child(wave_sp)

	var dur := 0.45 * scale_m
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flare, "scale", flare.scale * 1.85, 0.22)
	tw.tween_property(flare, "modulate:a", 0.0, 0.24)
	if wave_sp != null:
		var wmat := wave_sp.material as ShaderMaterial
		tw.tween_method(func(v: float) -> void:
			wmat.set_shader_parameter("progress", v)
			wmat.set_shader_parameter("fade", 1.0 - v * v)
		, 0.05, 1.0, dur * 0.85)
	tw.chain().tween_interval(dur)
	tw.chain().tween_callback(root.queue_free)

static func spawn_slam_explosion(parent: Node, world_pos: Vector2, radius: float, primary_col: Color, accent_col: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 6
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var dia := maxf(84.0, radius * 2.25)
	var wave := make_shader_sprite(TEX_MAGIC_04, SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": primary_col,
		"accent_color": accent_col,
		"progress": 0.08,
		"ring_width": 0.22,
		"petal_count": 6.0,
		"spin_speed": 3.0,
		"alpha_limit": 0.78,
		"is_wave": 1.0,
		"fade": 1.0,
	}, dia)
	wave.scale.y *= 0.80
	root.add_child(wave)

	var blast := make_sprite(TEX_SCORCH_02, dia * 0.72, Color(primary_col.r, primary_col.g, primary_col.b, 0.92), true)
	blast.scale.y *= 0.80
	blast.rotation = randf() * TAU
	root.add_child(blast)

	var sparks := make_gpu_particles(TEX_FIRE_01, {
		"amount": clampi(int(radius * 0.18), 10, 22),
		"lifetime": 0.36,
		"one_shot": true,
		"explosiveness": 0.95,
		"shape": "ring",
		"shape_radius": radius * 0.42,
		"vel_min": 65.0,
		"vel_max": maxf(130.0, radius * 1.9),
		"scale_min": 0.045,
		"scale_max": 0.095,
		"color_start": accent_col,
		"color_end": Color(primary_col.r, primary_col.g, primary_col.b, 0.0),
	})
	root.add_child(sparks)

	var smoke := make_gpu_particles(TEX_SMOKE_08, {
		"amount": 10,
		"lifetime": 0.45,
		"one_shot": true,
		"explosiveness": 0.92,
		"additive": false,
		"vel_min": 35.0,
		"vel_max": maxf(90.0, radius * 1.1),
		"scale_min": 0.07,
		"scale_max": 0.14,
		"color_start": Color(primary_col.r * 0.55, primary_col.g * 0.45, primary_col.b * 0.45, 0.58),
		"color_end": Color(0.08, 0.06, 0.08, 0.0),
	})
	root.add_child(smoke)

	var wmat := wave.material as ShaderMaterial
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		wmat.set_shader_parameter("progress", v)
		wmat.set_shader_parameter("fade", 1.0 - v * v)
	, 0.08, 1.0, 0.32)
	tw.tween_property(blast, "scale", blast.scale * 1.48, 0.24)
	tw.tween_property(blast, "modulate:a", 0.0, 0.26)
	tw.chain().tween_interval(0.32)
	tw.chain().tween_callback(root.queue_free)

static func spawn_boss_shockwave(parent: Node, world_pos: Vector2, radius: float, primary_col: Color, accent_col: Color, dur: float = 0.42) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 6
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var dia := maxf(110.0, radius * 2.4)
	var ring := make_shader_sprite(TEX_CIRCLE_05, SHADER_BOSS_SHOCKWAVE, {
		"primary_color": primary_col,
		"accent_color": accent_col,
		"progress": 0.05,
		"ring_width": 0.14,
		"noise_intensity": 0.048,
		"twist_speed": 3.8,
		"fade": 1.0,
	}, dia)
	ring.scale.y *= 0.80
	root.add_child(ring)

	var core_sp := make_sprite(TEX_SCORCH_03, dia * 0.56, Color(accent_col.r, accent_col.g, accent_col.b, 0.88), true)
	core_sp.scale.y *= 0.80
	core_sp.rotation = randf() * TAU
	root.add_child(core_sp)

	var embers := make_gpu_particles(TEX_FLAME_01, {
		"amount": clampi(int(radius * 0.22), 14, 28),
		"lifetime": dur,
		"one_shot": true,
		"explosiveness": 0.96,
		"shape": "ring",
		"shape_radius": radius * 0.36,
		"vel_min": 80.0,
		"vel_max": maxf(160.0, radius * 2.2),
		"scale_min": 0.05,
		"scale_max": 0.11,
		"color_start": accent_col,
		"color_end": Color(primary_col.r, primary_col.g, primary_col.b, 0.0),
	})
	root.add_child(embers)

	var sparks := make_gpu_particles(TEX_SPARK_05, {
		"amount": 16,
		"lifetime": dur * 0.85,
		"one_shot": true,
		"explosiveness": 0.98,
		"vel_min": 110.0,
		"vel_max": maxf(190.0, radius * 2.5),
		"scale_min": 0.04,
		"scale_max": 0.085,
		"color_start": Color(1.0, 0.95, 0.78, 1.0),
		"color_end": Color(primary_col.r, primary_col.g, primary_col.b, 0.0),
	})
	root.add_child(sparks)

	var mat := ring.material as ShaderMaterial
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("progress", v)
		mat.set_shader_parameter("fade", 1.0 - v * v)
	, 0.05, 1.0, dur * 0.88)
	tw.tween_property(core_sp, "scale", core_sp.scale * 1.6, dur * 0.55)
	tw.tween_property(core_sp, "modulate:a", 0.0, dur * 0.60)
	tw.chain().tween_interval(dur)
	tw.chain().tween_callback(root.queue_free)

static func spawn_boss_charge_aura(parent: Node, world_pos: Vector2, radius: float, col: Color, dur: float = 0.52) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 5
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var swirl := make_sprite(TEX_TWIRL_02, radius * 2.1, Color(col.r, col.g, col.b, 0.78), true)
	root.add_child(swirl)

	var sparks := make_gpu_particles(TEX_SPARK_04, {
		"amount": 12,
		"lifetime": dur * 0.9,
		"one_shot": true,
		"explosiveness": 0.80,
		"shape": "ring",
		"shape_radius": radius * 0.9,
		"vel_min": 18.0,
		"vel_max": 52.0,
		"gravity": Vector3(0.0, -110.0, 0.0),
		"scale_min": 0.035,
		"scale_max": 0.07,
		"color_start": Color(1.0, 0.94, 0.70, 0.95),
		"color_end": Color(col.r, col.g, col.b, 0.0),
	})
	root.add_child(sparks)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(swirl, "rotation", TAU * 0.75, dur)
	tw.tween_property(swirl, "scale", swirl.scale * 0.42, dur)
	tw.tween_property(swirl, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(root.queue_free)

static func spawn_boss_dash_ghost(parent: Node, world_pos: Vector2, tex: Texture2D, src_rect: Rect2, draw_rect: Rect2, facing_x: float, tint: Color) -> void:
	if parent == null or not is_instance_valid(parent) or tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.region_enabled = true
	sp.region_rect = src_rect
	sp.global_position = world_pos
	sp.z_index = 4
	var sc_x := (draw_rect.size.x / maxf(1.0, src_rect.size.x)) * (-1.0 if facing_x < 0.0 else 1.0)
	var sc_y := draw_rect.size.y / maxf(1.0, src_rect.size.y)
	sp.scale = Vector2(sc_x, sc_y)
	sp.offset = Vector2(0.0, draw_rect.position.y + draw_rect.size.y * 0.5) / maxf(0.01, sc_y)
	sp.modulate = Color(tint.r, tint.g, tint.b, 0.52)
	sp.material = make_additive_mat()
	sp.add_to_group("v2_transient_vfx")
	parent.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.18)
	tw.tween_callback(sp.queue_free)

static func spawn_qiankun_vortex(parent: Node, world_pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 7
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var flash := make_sprite(TEX_LIGHT_01, 1700.0, Color(1.0, 0.86, 0.42, 0.34), true)
	root.add_child(flash)

	for i in range(3):
		var swirl := make_sprite(TEX_TWIRL_01 if i % 2 == 0 else TEX_TWIRL_03, 620.0 + float(i) * 220.0, Color(1.0, 0.82, 0.32, 0.50 - float(i) * 0.08), true)
		swirl.rotation = float(i) * 0.9
		swirl.scale.y *= 0.74
		root.add_child(swirl)
		var sw_tw := root.create_tween()
		sw_tw.set_parallel(true)
		sw_tw.tween_property(swirl, "rotation", swirl.rotation + TAU * (1.15 if i % 2 == 0 else -1.15), 0.80)
		sw_tw.tween_property(swirl, "scale", swirl.scale * 0.24, 0.82)
		sw_tw.tween_property(swirl, "modulate:a", 0.0, 0.86)

	var ring := make_shader_sprite(TEX_CIRCLE_05, SHADER_BOSS_SHOCKWAVE, {
		"primary_color": Color(1.0, 0.82, 0.30, 0.70),
		"accent_color": Color(1.0, 0.96, 0.72, 0.95),
		"progress": 0.04,
		"ring_width": 0.18,
		"noise_intensity": 0.035,
		"twist_speed": 5.2,
		"fade": 1.0,
	}, 420.0)
	ring.scale.y *= 0.70
	root.add_child(ring)
	var rmat := ring.material as ShaderMaterial
	var r_tw := root.create_tween()
	r_tw.set_parallel(true)
	r_tw.tween_method(func(v: float) -> void:
		rmat.set_shader_parameter("progress", v)
		rmat.set_shader_parameter("fade", 1.0 - v * v)
	, 0.04, 1.0, 0.72)
	r_tw.tween_property(ring, "scale", ring.scale * 3.6, 0.76)

	var embers := make_gpu_particles(TEX_SPARK_06, {
		"amount": 42,
		"lifetime": 0.78,
		"one_shot": true,
		"explosiveness": 0.96,
		"shape": "ring",
		"shape_radius": 300.0,
		"vel_min": 60.0,
		"vel_max": 180.0,
		"gravity": Vector3(0.0, -130.0, 0.0),
		"scale_min": 0.05,
		"scale_max": 0.11,
		"color_start": Color(1.0, 0.92, 0.56, 0.95),
		"color_end": Color(1.0, 0.62, 0.16, 0.0),
	})
	root.add_child(embers)

	var gather := make_gpu_particles(TEX_STAR_04, {
		"amount": 28,
		"lifetime": 0.62,
		"one_shot": true,
		"explosiveness": 0.90,
		"shape": "ring",
		"shape_radius": 150.0,
		"shape_inner_radius": 40.0,
		"radial_min": -260.0,
		"radial_max": -150.0,
		"vel_min": 20.0,
		"vel_max": 70.0,
		"scale_min": 0.04,
		"scale_max": 0.09,
		"color_start": Color(1.0, 0.97, 0.78, 0.98),
		"color_end": Color(1.0, 0.72, 0.24, 0.0),
	})
	root.add_child(gather)

	var tw := root.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.16)
	tw.chain().tween_interval(0.72)
	tw.chain().tween_callback(root.queue_free)

static func spawn_taixu_domain(parent: Node, world_pos: Vector2, radius: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = 7
	root.add_to_group("v2_transient_vfx")
	parent.add_child(root)

	var flash := make_sprite(TEX_LIGHT_01, 1900.0, Color(0.70, 0.94, 1.0, 0.26), true)
	root.add_child(flash)

	var wave := make_shader_sprite(TEX_MAGIC_04, SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(0.48, 0.90, 0.98, 0.72),
		"accent_color": Color(1.0, 0.86, 0.46, 0.95),
		"progress": 0.04,
		"ring_width": 0.17,
		"petal_count": 8.0,
		"spin_speed": 1.8,
		"alpha_limit": 0.72,
		"is_wave": 1.0,
		"fade": 1.0,
	}, radius * 1.10)
	wave.scale.y *= 0.64
	root.add_child(wave)
	var wmat := wave.material as ShaderMaterial
	var w_tw := root.create_tween()
	w_tw.set_parallel(true)
	w_tw.tween_method(func(v: float) -> void:
		wmat.set_shader_parameter("progress", v)
		wmat.set_shader_parameter("fade", 1.0 - v * v)
	, 0.04, 1.0, 0.90)
	w_tw.tween_property(wave, "scale", wave.scale * 1.82, 0.94)

	var inner := make_shader_sprite(TEX_CIRCLE_02, SHADER_BAGUA_DOMAIN_WAVE, {
		"primary_color": Color(0.74, 0.97, 1.0, 0.62),
		"accent_color": Color(1.0, 0.90, 0.56, 0.90),
		"progress": 0.10,
		"ring_width": 0.26,
		"petal_count": 6.0,
		"spin_speed": -1.2,
		"alpha_limit": 0.55,
		"is_wave": 1.0,
		"fade": 1.0,
	}, radius * 0.46)
	inner.scale.y *= 0.64
	root.add_child(inner)
	var imat := inner.material as ShaderMaterial
	var i_tw := root.create_tween()
	i_tw.set_parallel(true)
	i_tw.tween_method(func(v: float) -> void:
		imat.set_shader_parameter("progress", v)
		imat.set_shader_parameter("fade", 1.0 - v)
	, 0.10, 1.0, 0.62)
	i_tw.tween_property(inner, "scale", inner.scale * 2.4, 0.70)

	var gold_ring := make_shader_sprite(TEX_CIRCLE_05, SHADER_BOSS_SHOCKWAVE, {
		"primary_color": Color(0.90, 0.72, 0.34, 0.62),
		"accent_color": Color(0.88, 0.98, 1.0, 0.95),
		"progress": 0.02,
		"ring_width": 0.08,
		"noise_intensity": 0.02,
		"twist_speed": 0.8,
		"fade": 1.0,
	}, radius * 0.62)
	gold_ring.scale.y *= 0.64
	root.add_child(gold_ring)
	var gmat := gold_ring.material as ShaderMaterial
	var g_tw := root.create_tween()
	g_tw.set_parallel(true)
	g_tw.tween_method(func(v: float) -> void:
		gmat.set_shader_parameter("progress", v)
		gmat.set_shader_parameter("fade", 1.0 - v * v)
	, 0.02, 1.0, 0.86)
	g_tw.tween_property(gold_ring, "scale", gold_ring.scale * 2.9, 0.90)

	var motes := make_gpu_particles(TEX_STAR_08, {
		"amount": 34,
		"lifetime": 0.86,
		"one_shot": true,
		"explosiveness": 0.94,
		"shape": "ring",
		"shape_radius": 210.0,
		"vel_min": 16.0,
		"vel_max": 62.0,
		"gravity": Vector3(0.0, -26.0, 0.0),
		"scale_min": 0.035,
		"scale_max": 0.08,
		"color_start": Color(0.80, 0.98, 1.0, 0.92),
		"color_end": Color(1.0, 0.88, 0.48, 0.0),
	})
	root.add_child(motes)

	var ink := make_gpu_particles(TEX_SMOKE_04, {
		"amount": 16,
		"lifetime": 0.96,
		"one_shot": true,
		"explosiveness": 0.85,
		"additive": false,
		"shape": "ring",
		"shape_radius": maxf(120.0, radius * 0.42),
		"vel_min": 22.0,
		"vel_max": 66.0,
		"scale_min": 0.10,
		"scale_max": 0.20,
		"color_start": Color(0.62, 0.90, 0.96, 0.30),
		"color_end": Color(0.42, 0.68, 0.72, 0.0),
	})
	root.add_child(ink)

	var tw := root.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.20)
	tw.chain().tween_interval(0.92)
	tw.chain().tween_callback(root.queue_free)
