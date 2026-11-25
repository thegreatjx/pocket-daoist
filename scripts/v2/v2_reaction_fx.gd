class_name V2ReactionFx
extends Node2D

var duration: float = 0.55
var elapsed: float = 0.0

var _anim_sprites: Array[Dictionary] = []
var _anim_lines: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("v2_transient_vfx")

func setup_reaction(rx_id: String, center: Vector2, aoe_r: float, rx_col: Color, extra: Dictionary = {}) -> void:
	global_position = center
	var r := maxf(36.0, aoe_r)
	match rx_id:
		"react_thunder_fire":
			duration = 0.56
			z_index = 5
			var crater := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_02, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(rx_col.r, rx_col.g, rx_col.b, 0.38),
				"burn_color": Color(1.0, 0.85, 0.35, 1.0),
				"dissolve_amount": 0.05,
				"burn_size": 0.22,
				"alpha_limit": 0.36,
			}, r * 2.05)
			crater.z_index = -5
			crater.top_level = true
			crater.global_position = center
			add_child(crater)
			_anim_sprites.append({"node": crater, "mode": "burn", "s0": crater.scale, "s1": crater.scale * 1.15, "spin": 1.4})

			for i in range(3):
				var ang := float(i) * TAU / 3.0 + randf_range(-0.35, 0.35)
				var arc := _build_radial_arc(r * 0.92, ang, rx_col, Color(1.0, 0.94, 0.65, 1.0), 16.0)
				add_child(arc)
				_anim_lines.append({"node": arc})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_FIRE_02, {
				"amount": 16, "lifetime": 0.42, "vel_min": 55.0, "vel_max": r * 1.8,
				"scale_min": 0.06, "scale_max": 0.13,
				"color_start": Color(1.0, 0.56, 0.18, 0.90), "color_end": Color(0.95, 0.25, 0.05, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_05, {
				"amount": 12, "lifetime": 0.32, "vel_min": 90.0, "vel_max": r * 2.4,
				"scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(0.85, 0.82, 1.0, 0.95), "color_end": Color(0.51, 0.55, 0.97, 0.0),
			}))

		"react_melt":
			duration = 0.58
			z_index = 5
			var swirl := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.22, 0.74, 0.97, 0.55),
				"accent_color": Color(1.0, 0.58, 0.20, 0.95),
				"petal_count": 6.0,
				"spin_speed": 3.4,
				"alpha_limit": 0.42,
				"is_wave": 1.0,
				"ring_width": 0.22,
			}, r * 2.2)
			swirl.z_index = -5
			swirl.top_level = true
			swirl.global_position = center
			add_child(swirl)
			_anim_sprites.append({"node": swirl, "mode": "wave", "s0": swirl.scale * 0.75, "s1": swirl.scale * 1.15, "spin": -2.2})

			var flash := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, r * 1.4, Color(0.82, 0.96, 1.0, 0.88), true)
			add_child(flash)
			_anim_sprites.append({"node": flash, "mode": "flash", "s0": flash.scale * 0.4, "s1": flash.scale * 1.25, "spin": 2.0})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_04, {
				"amount": 14, "lifetime": 0.55, "direction": Vector2(0.0, -1.0), "spread": 75.0,
				"vel_min": 35.0, "vel_max": 95.0, "gravity": Vector3(0.0, -120.0, 0.0),
				"scale_min": 0.06, "scale_max": 0.14, "additive": false,
				"color_start": Color(0.86, 0.95, 1.0, 0.48), "color_end": Color(0.95, 0.98, 1.0, 0.0),
			}))

		"react_toxic_burn":
			duration = 0.55
			z_index = 5
			var burst := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_01, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.52, 0.80, 0.09, 0.36),
				"burn_color": Color(1.0, 0.52, 0.12, 1.0),
				"dissolve_amount": 0.08,
				"burn_size": 0.20,
				"alpha_limit": 0.35,
			}, r * 2.0)
			burst.z_index = -5
			burst.top_level = true
			burst.global_position = center
			add_child(burst)
			_anim_sprites.append({"node": burst, "mode": "burn", "s0": burst.scale * 0.7, "s1": burst.scale * 1.15, "spin": 1.0})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_08, {
				"amount": 12, "lifetime": 0.52, "vel_min": 40.0, "vel_max": r * 1.35,
				"scale_min": 0.07, "scale_max": 0.15, "additive": false,
				"color_start": Color(0.52, 0.88, 0.16, 0.52), "color_end": Color(0.20, 0.45, 0.12, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_FLAME_01, {
				"amount": 12, "lifetime": 0.40, "vel_min": 55.0, "vel_max": r * 1.65,
				"scale_min": 0.05, "scale_max": 0.11,
				"color_start": Color(1.0, 0.58, 0.14, 0.85), "color_end": Color(0.64, 0.90, 0.15, 0.0),
			}))

		"react_superconduct":
			duration = 0.58
			z_index = 5
			var ring := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.51, 0.55, 0.97, 0.48),
				"accent_color": Color(0.56, 0.90, 1.0, 0.95),
				"petal_count": 8.0,
				"spin_speed": 2.4,
				"alpha_limit": 0.36,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, r * 2.15)
			ring.z_index = -5
			ring.top_level = true
			ring.global_position = center
			add_child(ring)
			_anim_sprites.append({"node": ring, "mode": "wave", "s0": ring.scale * 0.72, "s1": ring.scale * 1.08, "spin": 1.8})

			var hex := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, 13.0, {
				"bolt_color": rx_col,
				"core_color": Color(0.82, 0.96, 1.0, 1.0),
				"speed": 20.0,
				"jitter_amp": 0.48,
				"thickness": 0.12,
				"taper_ends": 0.0,
			})
			var hex_pts := PackedVector2Array()
			for i in range(18):
				var a := float(i) * TAU / 18.0
				var rad_j := r * (0.72 + (0.08 if i % 2 == 0 else -0.05))
				hex_pts.append(Vector2(cos(a), sin(a)) * rad_j)
			hex_pts.append(hex_pts[0])
			hex.points = hex_pts
			add_child(hex)
			_anim_lines.append({"node": hex})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
				"amount": 10, "lifetime": 0.38, "shape": "ring", "shape_radius": r * 0.7,
				"vel_min": 25.0, "vel_max": 75.0, "scale_min": 0.05, "scale_max": 0.10,
				"color_start": Color(0.65, 0.72, 1.0, 0.92), "color_end": Color(0.38, 0.78, 1.0, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_08, {
				"amount": 8, "lifetime": 0.42, "vel_min": 35.0, "vel_max": r * 1.2,
				"scale_min": 0.04, "scale_max": 0.08,
				"color_start": Color(0.68, 0.94, 1.0, 0.90), "color_end": Color(0.51, 0.55, 0.97, 0.0),
			}))

		"react_shatter":
			duration = 0.42
			z_index = 6
			for idx in range(2):
				var slash_tex := V2VfxFactory.TEX_SLASH_02 if idx == 0 else V2VfxFactory.TEX_SCRATCH_01
				var cut := V2VfxFactory.make_shader_sprite(slash_tex, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
					"primary_color": Color(0.40, 0.91, 0.98, 0.95),
					"edge_color": Color(0.95, 0.99, 1.0, 1.0),
					"use_texture_mask": 1.0,
					"intensity": 1.55,
				}, r * 2.1)
				cut.rotation = (-0.65 if idx == 0 else 0.65) + randf_range(-0.2, 0.2)
				add_child(cut)
				_anim_sprites.append({"node": cut, "mode": "slash", "s0": cut.scale * 0.78, "s1": cut.scale * 1.12, "spin": 0.0})

			var burst_star := V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_09, r * 1.5, Color(0.75, 0.96, 1.0, 0.85), true)
			add_child(burst_star)
			_anim_sprites.append({"node": burst_star, "mode": "flash", "s0": burst_star.scale * 0.4, "s1": burst_star.scale * 1.2, "spin": 3.0})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_08, {
				"amount": 14, "lifetime": 0.36, "vel_min": 95.0, "vel_max": r * 2.8,
				"scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(0.78, 0.97, 1.0, 0.95), "color_end": Color(0.24, 0.78, 0.98, 0.0),
			}))

		"react_lightning_blade":
			duration = 0.44
			z_index = 6
			var arc_slash := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SLASH_03, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
				"primary_color": Color(0.65, 0.55, 0.98, 0.95),
				"edge_color": Color(1.0, 0.94, 0.62, 1.0),
				"use_texture_mask": 1.0,
				"intensity": 1.65,
			}, 170.0)
			arc_slash.rotation = randf_range(-PI, PI)
			add_child(arc_slash)
			_anim_sprites.append({"node": arc_slash, "mode": "slash", "s0": arc_slash.scale * 0.8, "s1": arc_slash.scale * 1.18, "spin": 1.2})

			var cross_bolt := _build_radial_arc(95.0, arc_slash.rotation + PI * 0.5, rx_col, Color(1.0, 0.94, 0.62, 1.0), 18.0)
			add_child(cross_bolt)
			_anim_lines.append({"node": cross_bolt})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_04, {
				"amount": 10, "lifetime": 0.34, "vel_min": 80.0, "vel_max": 190.0,
				"scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(0.85, 0.78, 1.0, 0.95), "color_end": Color(0.65, 0.55, 0.98, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_TRACE_05, {
				"amount": 8, "lifetime": 0.30, "vel_min": 100.0, "vel_max": 220.0,
				"scale_min": 0.04, "scale_max": 0.08,
				"color_start": Color(1.0, 0.92, 0.55, 0.95), "color_end": Color(0.65, 0.55, 0.98, 0.0),
			}))

		"react_frost_blight":
			duration = 0.78
			z_index = 4
			var seal := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.18, 0.83, 0.75, 0.45),
				"accent_color": Color(0.56, 0.94, 0.98, 0.88),
				"petal_count": 8.0,
				"spin_speed": 0.8,
				"alpha_limit": 0.35,
				"is_wave": 0.0,
			}, r * 2.05)
			seal.z_index = -5
			seal.top_level = true
			seal.global_position = center
			add_child(seal)
			_anim_sprites.append({"node": seal, "mode": "wave", "s0": seal.scale * 0.85, "s1": seal.scale, "spin": 0.6})

			var miasma := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SMOKE_07, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.14, 0.76, 0.64, 0.34),
				"burn_color": Color(0.45, 0.95, 0.92, 0.90),
				"dissolve_amount": 0.1,
				"alpha_limit": 0.32,
			}, r * 1.9)
			miasma.z_index = -5
			miasma.top_level = true
			miasma.global_position = center
			add_child(miasma)
			_anim_sprites.append({"node": miasma, "mode": "burn", "s0": miasma.scale * 0.75, "s1": miasma.scale * 1.05, "spin": -0.9})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_04, {
				"amount": 12, "lifetime": 0.68, "shape": "sphere", "shape_radius": r * 0.65,
				"vel_min": 14.0, "vel_max": 45.0, "scale_min": 0.04, "scale_max": 0.08,
				"color_start": Color(0.42, 0.95, 0.88, 0.85), "color_end": Color(0.14, 0.68, 0.56, 0.0),
			}))

		"react_corrode_execute":
			var executed := bool(extra.get("executed", false))
			var sc_mult := 1.42 if executed else 1.0
			duration = 0.48
			z_index = 6
			var acid := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_03, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.06, 0.72, 0.51, 0.38),
				"burn_color": Color(0.45, 0.98, 0.68, 1.0),
				"dissolve_amount": 0.05,
				"alpha_limit": 0.36,
			}, 115.0 * sc_mult)
			acid.z_index = -5
			acid.top_level = true
			acid.global_position = center
			add_child(acid)
			_anim_sprites.append({"node": acid, "mode": "burn", "s0": acid.scale * 0.7, "s1": acid.scale * 1.15, "spin": 1.2})

			for idx in range(2):
				var tex := V2VfxFactory.TEX_SLASH_01 if idx == 0 else V2VfxFactory.TEX_SLASH_04
				var slash := V2VfxFactory.make_shader_sprite(tex, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
					"primary_color": Color(0.08, 0.84, 0.56, 0.95),
					"edge_color": Color(0.85, 1.0, 0.90, 1.0),
					"ink_strength": 0.65,
					"use_texture_mask": 1.0,
					"intensity": 1.65,
				}, 150.0 * sc_mult)
				slash.rotation = -0.78 if idx == 0 else 0.78
				add_child(slash)
				_anim_sprites.append({"node": slash, "mode": "slash", "s0": slash.scale * 0.75, "s1": slash.scale * 1.2, "spin": 0.0})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_02, {
				"amount": 14 if executed else 9, "lifetime": 0.38, "vel_min": 65.0, "vel_max": 175.0 * sc_mult,
				"scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(0.32, 0.96, 0.68, 0.95), "color_end": Color(0.06, 0.68, 0.45, 0.0),
			}))

		"react_molten_forge":
			duration = 0.55
			z_index = 5
			var molten := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SCORCH_02, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.98, 0.57, 0.24, 0.40),
				"burn_color": Color(1.0, 0.88, 0.36, 1.0),
				"dissolve_amount": 0.05,
				"alpha_limit": 0.36,
			}, r * 2.0)
			molten.z_index = -5
			molten.top_level = true
			molten.global_position = center
			add_child(molten)
			_anim_sprites.append({"node": molten, "mode": "burn", "s0": molten.scale * 0.75, "s1": molten.scale * 1.1, "spin": 0.8})

			var anvil_wave := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.98, 0.76, 0.28, 0.55),
				"accent_color": Color(1.0, 0.94, 0.68, 1.0),
				"petal_count": 4.0,
				"spin_speed": 2.0,
				"alpha_limit": 0.38,
				"is_wave": 1.0,
				"ring_width": 0.18,
			}, r * 2.2)
			anvil_wave.z_index = -5
			anvil_wave.top_level = true
			anvil_wave.global_position = center
			add_child(anvil_wave)
			_anim_sprites.append({"node": anvil_wave, "mode": "wave", "s0": anvil_wave.scale * 0.7, "s1": anvil_wave.scale * 1.12, "spin": 0.0})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
				"amount": 14, "lifetime": 0.48, "direction": Vector2(0.0, -1.0), "spread": 140.0,
				"vel_min": 80.0, "vel_max": 210.0, "gravity": Vector3(0.0, 320.0, 0.0),
				"scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(1.0, 0.88, 0.35, 0.98), "color_end": Color(0.98, 0.45, 0.12, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_FLAME_02, {
				"amount": 8, "lifetime": 0.38, "vel_min": 35.0, "vel_max": 95.0,
				"scale_min": 0.05, "scale_max": 0.10,
				"color_start": Color(1.0, 0.65, 0.18, 0.85), "color_end": Color(0.95, 0.32, 0.08, 0.0),
			}))

		"react_miasma_arc":
			duration = 0.54
			z_index = 5
			var pulse := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.64, 0.90, 0.21, 0.48),
				"accent_color": Color(0.92, 1.0, 0.48, 0.95),
				"petal_count": 6.0,
				"spin_speed": 2.8,
				"alpha_limit": 0.36,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, r * 2.1)
			pulse.z_index = -5
			pulse.top_level = true
			pulse.global_position = center
			add_child(pulse)
			_anim_sprites.append({"node": pulse, "mode": "wave", "s0": pulse.scale * 0.72, "s1": pulse.scale * 1.12, "spin": 1.6})

			for i in range(3):
				var ang := float(i) * TAU / 3.0 + randf_range(-0.3, 0.3)
				var tendril := _build_radial_arc(r * 0.88, ang, rx_col, Color(0.94, 1.0, 0.62, 1.0), 14.0)
				add_child(tendril)
				_anim_lines.append({"node": tendril})

			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_01, {
				"amount": 10, "lifetime": 0.48, "vel_min": 35.0, "vel_max": r * 1.25,
				"scale_min": 0.06, "scale_max": 0.13, "additive": false,
				"color_start": Color(0.58, 0.90, 0.22, 0.50), "color_end": Color(0.28, 0.55, 0.14, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_07, {
				"amount": 10, "lifetime": 0.35, "vel_min": 65.0, "vel_max": r * 1.8,
				"scale_min": 0.04, "scale_max": 0.08,
				"color_start": Color(0.86, 1.0, 0.45, 0.95), "color_end": Color(0.55, 0.85, 0.20, 0.0),
			}))

		"react_vaporize":
			duration = 0.56
			z_index = 5
			var steam_ring := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.22, 0.78, 0.98, 0.50),
				"accent_color": Color(1.0, 0.62, 0.24, 0.92),
				"petal_count": 6.0,
				"spin_speed": 3.0,
				"alpha_limit": 0.40,
				"is_wave": 1.0,
				"ring_width": 0.22,
			}, r * 2.15)
			steam_ring.z_index = -5
			steam_ring.top_level = true
			steam_ring.global_position = center
			add_child(steam_ring)
			_anim_sprites.append({"node": steam_ring, "mode": "wave", "s0": steam_ring.scale * 0.72, "s1": steam_ring.scale * 1.18, "spin": -1.8})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_04, {
				"amount": 16, "lifetime": 0.54, "direction": Vector2(0.0, -1.0), "spread": 95.0,
				"vel_min": 40.0, "vel_max": 110.0, "gravity": Vector3(0.0, -110.0, 0.0),
				"scale_min": 0.06, "scale_max": 0.14, "additive": false,
				"color_start": Color(0.84, 0.96, 1.0, 0.52), "color_end": Color(0.96, 0.99, 1.0, 0.0),
			}))

		"react_electro_charged":
			duration = 0.52
			z_index = 5
			var ec_ring := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.14, 0.82, 0.95, 0.48),
				"accent_color": Color(0.62, 0.74, 1.0, 0.95),
				"petal_count": 8.0,
				"spin_speed": 3.2,
				"alpha_limit": 0.36,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, r * 2.05)
			ec_ring.z_index = -5
			ec_ring.top_level = true
			ec_ring.global_position = center
			add_child(ec_ring)
			_anim_sprites.append({"node": ec_ring, "mode": "wave", "s0": ec_ring.scale * 0.74, "s1": ec_ring.scale * 1.12, "spin": 2.0})
			for i in range(3):
				var ang := float(i) * TAU / 3.0 + randf_range(-0.35, 0.35)
				var arc := _build_radial_arc(r * 0.88, ang, Color(0.14, 0.82, 0.96), Color(0.88, 0.96, 1.0, 1.0), 14.0)
				add_child(arc)
				_anim_lines.append({"node": arc})

		"react_flash_freeze":
			duration = 0.68
			z_index = 4
			var fr_seal := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_04, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.32, 0.88, 0.98, 0.46),
				"accent_color": Color(0.82, 0.97, 1.0, 0.92),
				"petal_count": 6.0,
				"spin_speed": 1.2,
				"alpha_limit": 0.36,
				"is_wave": 0.0,
			}, r * 2.05)
			fr_seal.z_index = -5
			fr_seal.top_level = true
			fr_seal.global_position = center
			add_child(fr_seal)
			_anim_sprites.append({"node": fr_seal, "mode": "wave", "s0": fr_seal.scale * 0.82, "s1": fr_seal.scale * 1.05, "spin": 0.8})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_08, {
				"amount": 12, "lifetime": 0.52, "shape": "ring", "shape_radius": r * 0.65,
				"vel_min": 20.0, "vel_max": 70.0, "scale_min": 0.04, "scale_max": 0.09,
				"color_start": Color(0.74, 0.97, 1.0, 0.94), "color_end": Color(0.18, 0.78, 0.96, 0.0),
			}))

		"react_toxic_mire":
			duration = 0.58
			z_index = 4
			var mire := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SMOKE_07, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.08, 0.72, 0.65, 0.36),
				"burn_color": Color(0.24, 0.92, 0.72, 0.92),
				"dissolve_amount": 0.08,
				"alpha_limit": 0.34,
			}, r * 2.05)
			mire.z_index = -5
			mire.top_level = true
			mire.global_position = center
			add_child(mire)
			_anim_sprites.append({"node": mire, "mode": "burn", "s0": mire.scale * 0.76, "s1": mire.scale * 1.10, "spin": -1.1})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_08, {
				"amount": 12, "lifetime": 0.50, "vel_min": 30.0, "vel_max": r * 1.15,
				"scale_min": 0.06, "scale_max": 0.13, "additive": false,
				"color_start": Color(0.12, 0.78, 0.66, 0.52), "color_end": Color(0.06, 0.42, 0.38, 0.0),
			}))

		"react_sharp_tide":
			duration = 0.44
			z_index = 6
			var tide_wave := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.04, 0.74, 0.86, 0.52),
				"accent_color": Color(0.95, 0.86, 0.44, 0.95),
				"petal_count": 4.0,
				"spin_speed": 2.6,
				"alpha_limit": 0.38,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, r * 2.1)
			tide_wave.z_index = -5
			tide_wave.top_level = true
			tide_wave.global_position = center
			add_child(tide_wave)
			_anim_sprites.append({"node": tide_wave, "mode": "wave", "s0": tide_wave.scale * 0.72, "s1": tide_wave.scale * 1.15, "spin": 1.5})
			var cut := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SLASH_02, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
				"primary_color": Color(0.10, 0.86, 0.94, 0.95),
				"edge_color": Color(0.98, 0.96, 0.80, 1.0),
				"use_texture_mask": 1.0,
				"intensity": 1.55,
			}, r * 1.95)
			cut.rotation = randf_range(-PI, PI)
			add_child(cut)
			_anim_sprites.append({"node": cut, "mode": "slash", "s0": cut.scale * 0.76, "s1": cut.scale * 1.15, "spin": 0.0})

		_:
			setup_weapon_burst("pulse", center, Vector2.RIGHT, r, rx_col, extra)

func setup_weapon_burst(kind: String, pos: Vector2, dir: Vector2, radius: float, col: Color, extra: Dictionary = {}) -> void:
	global_position = pos
	var r := maxf(24.0, radius)
	var d := dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	match kind:
		"sword_cross_burst":
			duration = 0.30
			z_index = 6
			var gold := Color(1.0, 0.88, 0.38, 1.0)
			var flash := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, r * 2.1, Color(gold.r, gold.g, gold.b, 0.85), true)
			add_child(flash)
			_anim_sprites.append({"node": flash, "mode": "flash", "s0": flash.scale * 0.45, "s1": flash.scale * 1.2, "spin": 2.4})
			for i in range(2):
				var cross := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SLASH_02, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
					"primary_color": Color(col.r, col.g, col.b, 0.95),
					"edge_color": Color(1.0, 1.0, 0.94, 1.0),
					"ink_strength": 0.55,
					"use_texture_mask": 1.0,
					"intensity": 1.85,
				}, 108.0)
				cross.rotation = d.angle() + (PI * 0.5 if i == 1 else 0.0)
				add_child(cross)
				_anim_sprites.append({"node": cross, "mode": "slash", "s0": cross.scale * 0.62, "s1": cross.scale * 1.35, "spin": 0.0})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_04, {
				"amount": 12, "lifetime": 0.26, "one_shot": true, "explosiveness": 0.95,
				"vel_min": 90.0, "vel_max": 210.0, "scale_min": 0.03, "scale_max": 0.07,
				"color_start": Color(1.0, 0.95, 0.62, 0.96), "color_end": Color(col.r, col.g, col.b, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SLASH_04, {
				"amount": 6, "lifetime": 0.22, "one_shot": true, "explosiveness": 1.0,
				"vel_min": 40.0, "vel_max": 120.0, "scale_min": 0.05, "scale_max": 0.11,
				"color_start": Color(1.0, 0.99, 0.90, 0.92), "color_end": Color(0.30, 0.92, 0.84, 0.0),
			}))

		"sword_hit":
			duration = 0.24
			z_index = 6
			var glint := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SLASH_01, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
				"primary_color": Color(col.r, col.g, col.b, 0.92),
				"edge_color": Color(0.95, 1.0, 1.0, 1.0),
				"use_texture_mask": 1.0,
				"intensity": 1.5,
			}, 74.0)
			glint.rotation = d.angle() + randf_range(-0.35, 0.35)
			add_child(glint)
			_anim_sprites.append({"node": glint, "mode": "slash", "s0": glint.scale * 0.75, "s1": glint.scale * 1.15, "spin": 0.0})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_04, {
				"amount": 6, "lifetime": 0.22, "direction": -d, "spread": 95.0,
				"vel_min": 60.0, "vel_max": 140.0, "scale_min": 0.03, "scale_max": 0.06,
				"color_start": Color(col.r, col.g, col.b, 0.95), "color_end": Color(col.r, col.g, col.b, 0.0),
			}))

		"sword_double_slash":
			duration = 0.28
			z_index = 6
			var sweep := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SLASH_03, V2VfxFactory.SHADER_SWORD_GLINT_TRAIL, {
				"primary_color": Color(col.r, col.g, col.b, 0.90),
				"edge_color": Color(0.95, 1.0, 0.98, 1.0),
				"ink_strength": 0.55,
				"use_texture_mask": 1.0,
				"intensity": 1.45,
			}, 115.0)
			sweep.rotation = d.angle()
			add_child(sweep)
			_anim_sprites.append({"node": sweep, "mode": "slash", "s0": sweep.scale * 0.78, "s1": sweep.scale * 1.15, "spin": 0.6})

		"fire_impact":
			duration = 0.28
			z_index = 5
			var ring_fx := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_LIGHT_01, V2VfxFactory.SHADER_FIRE_FLAME_2D, {
				"core_color": Color(1.0, 0.94, 0.60, 1.0),
				"mid_color": Color(1.0, 0.48, 0.10, 1.0),
				"outer_color": Color(0.72, 0.14, 0.04, 1.0),
				"speed": 4.2,
				"noise_scale": 3.6,
				"flame_shape": 0.0,
				"intensity": 1.15,
				"alpha_limit": 0.76,
				"ring_progress": 0.95,
			}, r * 2.08)
			add_child(ring_fx)
			_anim_sprites.append({"node": ring_fx, "mode": "fire_ring", "s0": ring_fx.scale * 0.55, "s1": ring_fx.scale * 1.08, "spin": 0.4})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
				"amount": 8, "lifetime": 0.24, "vel_min": 65.0, "vel_max": r * 1.6,
				"scale_min": 0.028, "scale_max": 0.058,
				"color_start": Color(1.0, 0.90, 0.44, 0.94), "color_end": Color(0.92, 0.25, 0.04, 0.0),
			}))

		"lotus_implosion":
			duration = 0.36
			z_index = 5
			var lotus_ring := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_LIGHT_01, V2VfxFactory.SHADER_FIRE_FLAME_2D, {
				"core_color": Color(1.0, 0.96, 0.68, 1.0),
				"mid_color": Color(1.0, 0.40, 0.12, 1.0),
				"outer_color": Color(0.68, 0.08, 0.04, 1.0),
				"speed": 5.0,
				"noise_scale": 4.0,
				"flame_shape": 0.0,
				"intensity": 1.2,
				"alpha_limit": 0.84,
				"ring_progress": 1.0,
			}, r * 2.2)
			lotus_ring.z_index = -5
			lotus_ring.top_level = true
			lotus_ring.global_position = pos
			add_child(lotus_ring)
			_anim_sprites.append({"node": lotus_ring, "mode": "fire_ring", "s0": lotus_ring.scale * 1.12, "s1": lotus_ring.scale * 0.42, "spin": 1.6})
			var core_flash := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, r * 0.95, Color(1.0, 0.86, 0.40, 0.80), true)
			add_child(core_flash)
			_anim_sprites.append({"node": core_flash, "mode": "flash", "s0": core_flash.scale * 0.45, "s1": core_flash.scale * 1.15, "spin": 1.8})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_01, {
				"amount": 12, "lifetime": 0.32, "vel_min": 80.0, "vel_max": r * 1.9,
				"scale_min": 0.03, "scale_max": 0.068,
				"color_start": Color(1.0, 0.88, 0.42, 0.95), "color_end": Color(0.95, 0.22, 0.05, 0.0),
			}))

		"frost_wheel_shatter":
			duration = 0.38
			z_index = 6
			var wheel := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_STAR_06, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.24, 0.78, 0.98, 0.65),
				"accent_color": Color(0.92, 0.99, 1.0, 1.0),
				"petal_count": 8.0,
				"spin_speed": 4.0,
				"alpha_limit": 0.55,
				"is_wave": 1.0,
				"ring_width": 0.22,
			}, 96.0)
			add_child(wheel)
			_anim_sprites.append({"node": wheel, "mode": "wave", "s0": wheel.scale * 0.5, "s1": wheel.scale * 1.25, "spin": 4.2})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_08, {
				"amount": 10, "lifetime": 0.32, "vel_min": 70.0, "vel_max": 165.0,
				"scale_min": 0.04, "scale_max": 0.08,
				"color_start": Color(0.75, 0.96, 1.0, 0.95), "color_end": Color(0.22, 0.74, 0.97, 0.0),
			}))

		"corpse_miasma_pop":
			duration = 0.45
			z_index = 4
			var pop := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_SMOKE_07, V2VfxFactory.SHADER_BURN_DISSOLVE, {
				"primary_color": Color(0.06, 0.72, 0.51, 0.38),
				"burn_color": Color(0.52, 0.96, 0.65, 0.95),
				"dissolve_amount": 0.05,
				"alpha_limit": 0.34,
			}, r * 1.9)
			pop.z_index = -5
			pop.top_level = true
			pop.global_position = pos
			add_child(pop)
			_anim_sprites.append({"node": pop, "mode": "burn", "s0": pop.scale * 0.65, "s1": pop.scale * 1.1, "spin": 1.0})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
				"amount": 10, "lifetime": 0.42, "vel_min": 35.0, "vel_max": r * 1.2,
				"scale_min": 0.05, "scale_max": 0.12, "additive": false,
				"color_start": Color(0.18, 0.88, 0.58, 0.52), "color_end": Color(0.06, 0.50, 0.32, 0.0),
			}))

		"dot_detonate":
			duration = 0.32
			z_index = 6
			var star := V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_09, r * 1.8, Color(col.r, col.g, col.b, 0.9), true)
			add_child(star)
			_anim_sprites.append({"node": star, "mode": "flash", "s0": star.scale * 0.45, "s1": star.scale * 1.2, "spin": 3.5})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_02, {
				"amount": 7, "lifetime": 0.28, "vel_min": 45.0, "vel_max": 120.0,
				"scale_min": 0.03, "scale_max": 0.07,
				"color_start": Color(0.48, 0.98, 0.72, 0.95), "color_end": Color(0.16, 0.76, 0.52, 0.0),
			}))

		"bell_resonance":
			var res_kind := String(extra.get("kind", "shatter"))
			var accent := Color.from_string(String(extra.get("accent_color", "#FDE047")), Color(1.0, 0.88, 0.42, 1.0))
			duration = 0.52
			z_index = 6
			var rune := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_MAGIC_02, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(col.r, col.g, col.b, 0.90),
				"accent_color": accent,
				"petal_count": 8.0,
				"spin_speed": 2.6,
				"alpha_limit": 0.50,
				"is_wave": 1.0,
				"ring_width": 0.18,
			}, r * 2.25)
			add_child(rune)
			_anim_sprites.append({"node": rune, "mode": "wave", "s0": rune.scale * 0.55, "s1": rune.scale * 1.12, "spin": 2.2})
			var core := V2VfxFactory.make_sprite(V2VfxFactory.TEX_FLARE_01, r * 1.2, Color(accent.r, accent.g, accent.b, 0.82), true)
			add_child(core)
			_anim_sprites.append({"node": core, "mode": "flash", "s0": core.scale * 0.35, "s1": core.scale * 1.18, "spin": 1.6})

			if res_kind == "thunder_echo":
				for i in range(3):
					var ang := float(i) * TAU / 3.0 + randf_range(-0.3, 0.3)
					var arc := _build_radial_arc(r * 0.95, ang, Color(1.0, 0.86, 0.30), accent, 16.0)
					add_child(arc)
					_anim_lines.append({"node": arc})
				add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_05, {
					"amount": 14, "lifetime": 0.34, "vel_min": 110.0, "vel_max": r * 2.5,
					"scale_min": 0.035, "scale_max": 0.08,
					"color_start": Color(1.0, 0.94, 0.52, 0.98), "color_end": Color(0.42, 0.38, 0.86, 0.0),
				}))
			elif res_kind == "shock_spread":
				var poison := bool(extra.get("poison", true))
				var spread_col := Color(0.20, 0.88, 0.60, 0.92) if poison else Color(1.0, 0.56, 0.18, 0.92)
				var spread_end := Color(0.58, 0.38, 0.95, 0.0) if poison else Color(0.92, 0.22, 0.06, 0.0)
				add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
					"amount": 16, "lifetime": 0.52, "shape": "ring", "shape_radius": r * 0.45,
					"vel_min": 45.0, "vel_max": r * 1.35,
					"scale_min": 0.06, "scale_max": 0.14, "additive": false,
					"color_start": Color(spread_col.r, spread_col.g, spread_col.b, 0.52), "color_end": spread_end,
				}))
				add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_09, {
					"amount": 12, "lifetime": 0.40, "vel_min": 70.0, "vel_max": r * 1.8,
					"scale_min": 0.035, "scale_max": 0.075,
					"color_start": Color(spread_col.r, spread_col.g, spread_col.b, 0.95), "color_end": spread_end,
				}))
			else:
				for i in range(3):
					var shard := V2VfxFactory.make_sprite(V2VfxFactory.TEX_STAR_08, 34.0 + float(i) * 8.0, Color(0.72, 0.96, 1.0, 0.92), true)
					var s_ang := randf() * TAU
					shard.position = Vector2(cos(s_ang), sin(s_ang)) * r * 0.55
					shard.rotation = s_ang
					add_child(shard)
					_anim_sprites.append({"node": shard, "mode": "flash", "s0": shard.scale * 1.15, "s1": shard.scale * 0.45, "spin": 2.4})
				add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_STAR_08, {
					"amount": 16, "lifetime": 0.36, "vel_min": 100.0, "vel_max": r * 2.7,
					"scale_min": 0.04, "scale_max": 0.09,
					"color_start": Color(0.85, 0.98, 1.0, 0.96), "color_end": Color(0.28, 0.78, 0.98, 0.0),
				}))
				add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_04, {
					"amount": 10, "lifetime": 0.46, "shape": "ring", "shape_radius": r * 0.55,
					"vel_min": 25.0, "vel_max": r * 1.1,
					"scale_min": 0.05, "scale_max": 0.11, "additive": false,
					"color_start": Color(0.72, 0.94, 1.0, 0.40), "color_end": Color(0.34, 0.68, 0.92, 0.0),
				}))

		"soul_seal_burst":
			var small := bool(extra.get("small", false))
			var burst_mult := 0.72 if small else 1.15
			duration = 0.42 if small else 0.56
			z_index = 5
			var seal := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_TWIRL_03, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": Color(0.16, 0.82, 0.58, 0.62),
				"accent_color": Color(0.72, 0.55, 1.0, 0.95),
				"petal_count": 6.0,
				"spin_speed": 3.2,
				"alpha_limit": 0.46,
				"is_wave": 1.0,
				"ring_width": 0.20,
			}, r * 2.1 * burst_mult)
			seal.z_index = -5
			seal.top_level = true
			seal.global_position = pos
			add_child(seal)
			_anim_sprites.append({"node": seal, "mode": "wave", "s0": seal.scale * 0.6, "s1": seal.scale * 1.16, "spin": 2.8})
			var links: Array = extra.get("links", [])
			for link_raw in links:
				var target: Vector2 = link_raw
				var link := _build_radial_arc(target.length(), target.angle(), Color(0.62, 0.94, 0.30), Color(0.88, 0.64, 1.0), 9.0)
				add_child(link)
				_anim_lines.append({"node": link})
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SMOKE_07, {
				"amount": 8 if small else 16, "lifetime": duration * 1.1,
				"shape": "ring", "shape_radius": r * 0.35,
				"vel_min": 30.0, "vel_max": r * (1.4 if small else 1.9),
				"scale_min": 0.05, "scale_max": 0.12, "additive": false,
				"color_start": Color(0.18, 0.88, 0.60, 0.52), "color_end": Color(0.55, 0.32, 0.92, 0.0),
			}))
			add_child(V2VfxFactory.make_gpu_particles(V2VfxFactory.TEX_SPARK_06, {
				"amount": 8 if small else 14, "lifetime": 0.36,
				"vel_min": 60.0, "vel_max": r * 2.0,
				"scale_min": 0.03, "scale_max": 0.075,
				"color_start": Color(0.78, 1.0, 0.84, 0.95), "color_end": Color(0.62, 0.42, 0.98, 0.0),
			}))

		_:
			duration = 0.36
			z_index = -5
			var wave := V2VfxFactory.make_shader_sprite(V2VfxFactory.TEX_CIRCLE_05, V2VfxFactory.SHADER_BAGUA_DOMAIN_WAVE, {
				"primary_color": col,
				"accent_color": Color(1.0, 0.96, 0.82, 0.95),
				"petal_count": 6.0,
				"spin_speed": 1.6,
				"alpha_limit": clampf(col.a, 0.25, 0.38),
				"is_wave": 1.0,
			}, r * 2.0)
			add_child(wave)
			_anim_sprites.append({"node": wave, "mode": "wave", "s0": wave.scale * 0.6, "s1": wave.scale * 1.05, "spin": 0.8})

func _build_radial_arc(length: float, angle: float, bolt_col: Color, core_col: Color, width: float) -> Line2D:
	var line := V2VfxFactory.make_shader_line(V2VfxFactory.SHADER_ELECTRIC_ARC, width, {
		"bolt_color": bolt_col,
		"core_color": core_col,
		"speed": 18.0,
		"jitter_amp": 0.38,
		"thickness": 0.17,
		"taper_ends": 0.18,
	})
	var dir := Vector2.from_angle(angle)
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		Vector2.ZERO,
		dir * (length * 0.36) + perp * randf_range(-10.0, 10.0),
		dir * (length * 0.72) + perp * randf_range(-12.0, 12.0),
		dir * length,
	])
	line.points = pts
	return line

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return

	var t := clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	var fade := clampf(1.0 - maxf(0.0, t - 0.55) / 0.45, 0.0, 1.0)

	for item in _anim_sprites:
		var sp := item["node"] as Sprite2D
		if sp == null or not is_instance_valid(sp):
			continue
		var s0: Vector2 = item["s0"]
		var s1: Vector2 = item["s1"]
		sp.scale = s0.lerp(s1, 1.0 - pow(1.0 - t, 2.0))
		sp.rotation += float(item["spin"]) * delta
		var mat := sp.material as ShaderMaterial
		match String(item["mode"]):
			"burn":
				if mat != null:
					mat.set_shader_parameter("dissolve_amount", smoothstep(0.18, 1.0, t))
					mat.set_shader_parameter("fade", fade)
			"wave":
				if mat != null:
					mat.set_shader_parameter("progress", t)
					mat.set_shader_parameter("fade", fade)
			"slash":
				if mat != null:
					mat.set_shader_parameter("progress", t)
					mat.set_shader_parameter("fade", fade)
			"flash":
				sp.modulate.a = (1.0 - t) * 0.9
			"fire_ring":
				if mat != null:
					mat.set_shader_parameter("fade", fade)

	for item in _anim_lines:
		var ln := item["node"] as Line2D
		if ln == null or not is_instance_valid(ln):
			continue
		var mat := ln.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("fade", 1.0 - t * t)
