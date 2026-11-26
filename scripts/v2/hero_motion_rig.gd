class_name HeroMotionRig
extends Node2D

const TEX_FLYING_SWORD: Texture2D = preload("res://assets/v2/heroes/mount_jade_sword.png")

var _tex: Texture2D = null
var _motion_mode: String = "hover_ride"
var _mount_type: String = "sword"
var _draw_height: float = 86.0
var _accent_color: Color = Color(0.26, 0.92, 0.82)

var _time: float = 0.0
var _walk_phase: float = 0.0
var _prev_sin_sign: int = 1
var _facing: float = 1.0
var _facing_scale_x: float = 1.0
var _turn_pop: float = 0.0
var _hover_y: float = -11.0
var _body_y: float = 0.0
var _tilt: float = 0.0
var _squash: Vector2 = Vector2.ONE

var _anim_idle: HeroFrameAnim = null
var _anim_run: HeroFrameAnim = null
var _anim_attack: HeroFrameAnim = null
var _anim_state: String = "idle"
var _attack_anim_timer: float = 0.0

var _flash_timer: float = 0.0
var _invuln_timer: float = 0.0
var _last_vel: Vector2 = Vector2.ZERO
var _is_dashing: bool = false
var _aim_dir: Vector2 = Vector2.RIGHT

var _trail_puffs: Array[Dictionary] = []
var _trail_spawn_acc: float = 0.0

func setup(cfg: Dictionary) -> void:
	var sprite_path := str(cfg.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_tex = load(sprite_path) as Texture2D
	_motion_mode = str(cfg.get("motion_mode", "hover_ride"))
	_mount_type = str(cfg.get("mount_type", "none"))
	var default_h := 86.0 if _motion_mode == "hover_ride" else 66.0
	_draw_height = float(cfg.get("draw_height", default_h))
	var acc = cfg.get("accent_color", Color(0.26, 0.92, 0.82))
	if acc is Color:
		_accent_color = acc
	_setup_animations(cfg)
	_trail_puffs.clear()
	queue_redraw()

func _setup_animations(cfg: Dictionary) -> void:
	_anim_idle = null
	_anim_run = null
	_anim_attack = null
	_anim_state = "idle"
	_attack_anim_timer = 0.0
	var idle_atlas := str(cfg.get("anim_idle_atlas", ""))
	var idle_meta := str(cfg.get("anim_idle_meta", ""))
	if idle_atlas != "" and idle_meta != "":
		var idle := HeroFrameAnim.new()
		if idle.load_clip(idle_atlas, idle_meta):
			_anim_idle = idle
	var run_atlas := str(cfg.get("anim_run_atlas", ""))
	var run_meta := str(cfg.get("anim_run_meta", ""))
	if run_atlas != "" and run_meta != "":
		var run_clip := HeroFrameAnim.new()
		if run_clip.load_clip(run_atlas, run_meta):
			_anim_run = run_clip
	var attack_atlas := str(cfg.get("anim_attack_atlas", ""))
	var attack_meta := str(cfg.get("anim_attack_meta", ""))
	if attack_atlas != "" and attack_meta != "":
		var attack := HeroFrameAnim.new()
		if attack.load_clip(attack_atlas, attack_meta):
			_anim_attack = attack

func update_motion(velocity: Vector2, delta: float, is_dashing: bool = false, aim_dir: Vector2 = Vector2.RIGHT) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_time += safe_delta
	_last_vel = velocity
	_is_dashing = is_dashing
	if aim_dir.length_squared() > 0.001:
		_aim_dir = aim_dir.normalized()

	var speed: float = velocity.length()
	var next_facing := _facing
	if absf(velocity.x) > 14.0:
		next_facing = -1.0 if velocity.x < 0.0 else 1.0
	elif speed <= 14.0 and absf(_aim_dir.x) > 0.35:
		next_facing = -1.0 if _aim_dir.x < 0.0 else 1.0
	if next_facing != _facing:
		_facing = next_facing
		_facing_scale_x = _facing
		_turn_pop = 1.0
	_turn_pop = maxf(0.0, _turn_pop - safe_delta / 0.11)

	var step_delta := minf(safe_delta, 0.05)
	var next_puffs: Array[Dictionary] = []
	for p in _trail_puffs:
		var life := float(p["life"]) - safe_delta
		if life > 0.0:
			p["life"] = life
			p["pos"] = (p["pos"] as Vector2) + ((p["vel"] as Vector2) - velocity) * step_delta
			next_puffs.append(p)
	_trail_puffs = next_puffs

	if _motion_mode == "hover_ride":
		_hover_y = -10.5 + sin(_time * 4.0) * 2.8
		_body_y = _hover_y
		var max_tilt := 0.22 if is_dashing else 0.15
		var target_rot := clampf(velocity.x / 250.0, -1.0, 1.0) * max_tilt
		if absf(velocity.x) <= 14.0 and speed > 14.0:
			target_rot = _facing * 0.06
		_tilt = lerpf(_tilt, target_rot, 1.0 - exp(-12.0 * safe_delta))

		var target_sq := Vector2.ONE
		if is_dashing:
			target_sq = Vector2(1.14, 0.88)
		elif speed > 14.0:
			var breath := sin(_time * 5.0) * 0.025
			target_sq = Vector2(1.03 + breath, 0.97 - breath)
		else:
			var breath := sin(_time * 3.2) * 0.025
			target_sq = Vector2(1.0 + breath, 1.0 - breath)
		_squash = _squash.lerp(target_sq, 1.0 - exp(-14.0 * safe_delta))

		if speed > 20.0 or is_dashing:
			_trail_spawn_acc += safe_delta * (34.0 if is_dashing else 15.0)
			while _trail_spawn_acc >= 1.0 and _trail_puffs.size() < 28:
				_trail_spawn_acc -= 1.0
				var puff_col := Color(0.93, 0.97, 0.94) if _mount_type == "cloud" else _accent_color
				if _mount_type == "fire_wheel":
					puff_col = Color(1.0, randf_range(0.38, 0.72), 0.14)
				_trail_puffs.append({
					"pos": Vector2(-_facing * 10.0 + randf_range(-4.0, 4.0), _hover_y + 2.0 + randf_range(-3.0, 3.0)),
					"vel": Vector2(-velocity.x * 0.12, randf_range(-12.0, 6.0)),
					"life": 0.32 if is_dashing else 0.25,
					"max_life": 0.32 if is_dashing else 0.25,
					"r": randf_range(5.0, 8.8) if _mount_type == "cloud" else randf_range(3.2, 6.0),
					"col": puff_col,
				})
		else:
			_trail_spawn_acc = 0.0
	else:
		if speed > 12.0:
			_walk_phase += safe_delta * clampf(speed / 245.0, 0.75, 1.45) / 0.48
			var u := fmod(_walk_phase, 1.0)
			var s := sin(u * TAU)
			if _anim_run != null:
				_body_y = lerpf(_body_y, 0.0, 1.0 - exp(-18.0 * safe_delta))
				_hover_y = _body_y
				_tilt = lerpf(_tilt, clampf(velocity.x / 260.0, -1.0, 1.0) * 0.05, 1.0 - exp(-18.0 * safe_delta))
				_squash = _squash.lerp(Vector2(1.08, 0.94) if is_dashing else Vector2.ONE, 1.0 - exp(-18.0 * safe_delta))
			else:
				var key_sq := Vector2.ONE
				var key_y := 0.0
				if u < 0.25:
					var kt := u / 0.25
					key_sq = Vector2(lerpf(1.0, 1.12, kt), lerpf(1.0, 0.88, kt))
					key_y = lerpf(0.0, 1.5, kt)
				elif u < 0.65:
					var kt := (u - 0.25) / 0.40
					key_sq = Vector2(lerpf(1.12, 0.92, kt), lerpf(0.88, 1.08, kt))
					key_y = lerpf(1.5, -7.5, kt)
				else:
					var kt := (u - 0.65) / 0.35
					key_sq = Vector2(lerpf(0.92, 1.0, kt), lerpf(1.08, 1.0, kt))
					key_y = lerpf(-7.5, 0.0, kt)

				_body_y = lerpf(_body_y, key_y, 1.0 - exp(-22.0 * safe_delta))
				_hover_y = _body_y
				_tilt = lerpf(_tilt, s * 0.065 + clampf(velocity.x / 260.0, -1.0, 1.0) * 0.06, 1.0 - exp(-18.0 * safe_delta))
				_squash = Vector2(1.20, 0.84) if is_dashing else _squash.lerp(key_sq, 1.0 - exp(-22.0 * safe_delta))

			var cur_sign := 1 if s >= 0.0 else -1
			if cur_sign != _prev_sin_sign:
				_prev_sin_sign = cur_sign
				if _trail_puffs.size() < 24:
					_trail_puffs.append({
						"pos": Vector2(randf_range(-5.0, 5.0), 2.0),
						"vel": Vector2(-velocity.x * 0.16 + randf_range(-16.0, 16.0), randf_range(-18.0, -6.0)),
						"life": 0.24,
						"max_life": 0.24,
						"r": randf_range(3.5, 5.6),
						"col": Color(0.86, 0.92, 0.84),
					})
		else:
			var breath := sin(_time * 3.8) * 0.045
			_body_y = lerpf(_body_y, 0.0, 1.0 - exp(-14.0 * safe_delta))
			_hover_y = _body_y
			_tilt = lerpf(_tilt, 0.0, 1.0 - exp(-14.0 * safe_delta))
			_squash = _squash.lerp(Vector2(1.0 + breath, 1.0 - breath), 1.0 - exp(-12.0 * safe_delta))

	if _attack_anim_timer > 0.0:
		_attack_anim_timer = maxf(0.0, _attack_anim_timer - safe_delta)
		if _anim_attack != null:
			_anim_attack.update(safe_delta)
			if _anim_attack.finished():
				_attack_anim_timer = 0.0

	if _attack_anim_timer > 0.0 and _anim_attack != null:
		_anim_state = "attack"
	elif speed > 14.0 and _anim_run != null:
		_anim_state = "run"
	else:
		_anim_state = "idle"

	if _anim_state == "run" and _anim_run != null:
		var run_rate := clampf(speed / 245.0, 0.8, 1.5) * (1.45 if is_dashing else 1.0)
		_anim_run.update(safe_delta * run_rate)
	elif _anim_idle != null:
		var anim_rate := 1.8 if is_dashing else (1.35 if speed > 14.0 else 1.0)
		_anim_idle.update(safe_delta * anim_rate)

	if _flash_timer > 0.0:
		_flash_timer -= safe_delta
		modulate = Color(2.5, 2.5, 2.5, 1.0) if _flash_timer > 0.0 else Color.WHITE
	elif _invuln_timer > 0.0:
		_invuln_timer -= safe_delta
		if _invuln_timer <= 0.0:
			modulate = Color.WHITE
		else:
			modulate.a = 0.45 if int(_invuln_timer * 20.0) % 2 == 0 else 1.0
	else:
		modulate = Color.WHITE

	queue_redraw()

func trigger_attack(dir: Vector2 = Vector2.ZERO) -> void:
	if dir.length_squared() > 0.001:
		_aim_dir = dir.normalized()
	if _anim_attack != null:
		_anim_attack.reset()
		_attack_anim_timer = _anim_attack.duration

func trigger_hurt_feedback(invuln_sec: float = 0.45) -> void:
	_flash_timer = 0.09
	_invuln_timer = invuln_sec

func _draw() -> void:
	var lift := maxf(0.0, -_body_y)
	var sh_sc := clampf(1.0 - lift * 0.024, 0.62, 1.0)
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(sh_sc, 0.40 * sh_sc))
	draw_circle(Vector2.ZERO, 20.0, Color(0.05, 0.07, 0.10, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for p in _trail_puffs:
		var a := clampf(float(p["life"]) / maxf(0.01, float(p["max_life"])), 0.0, 1.0)
		var col: Color = p["col"]
		col.a = a * (0.48 if _motion_mode == "hover_ride" else 0.42)
		draw_circle(p["pos"] as Vector2, float(p["r"]) * (0.55 + 0.45 * a), col)

	var render_fx := -1.0 if _facing < 0.0 else 1.0
	var turn_sq := Vector2(lerpf(1.0, 0.88, _turn_pop), lerpf(1.0, 1.12, _turn_pop))
	var eff_squash := Vector2(_squash.x * turn_sq.x, _squash.y * turn_sq.y)
	var anchor_pos := Vector2(0.0, _body_y)

	if _motion_mode == "hover_ride":
		if _mount_type == "sword":
			draw_set_transform(anchor_pos + Vector2(0.0, 2.0), _tilt * 0.85, Vector2(1.32, 0.36))
			draw_circle(Vector2.ZERO, 25.0, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.24))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if TEX_FLYING_SWORD != null:
				var pitch := _tilt * 0.85 + clampf(_last_vel.y / 320.0, -0.16, 0.16) * (1.0 if render_fx >= 0.0 else -1.0)
				var sw_sz := TEX_FLYING_SWORD.get_size()
				var sw_w := 80.0
				var sw_h := sw_w * (sw_sz.y / maxf(1.0, sw_sz.x))
				draw_set_transform(anchor_pos + Vector2(0.0, 1.0), pitch, Vector2(render_fx, 1.0))
				draw_texture_rect(TEX_FLYING_SWORD, Rect2(-sw_w * 0.56, -sw_h * 0.35, sw_w, sw_h), false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif _mount_type == "cloud":
			draw_set_transform(anchor_pos + Vector2(0.0, 1.0), _tilt * 0.6, Vector2(render_fx, 1.0))
			var outline_col := Color(0.14, 0.20, 0.22, 0.90)
			draw_circle(Vector2(-15.0, 1.0), 10.5, outline_col)
			draw_circle(Vector2(15.0, 1.0), 10.0, outline_col)
			draw_circle(Vector2(0.0, -2.0), 13.5, outline_col)
			draw_circle(Vector2(0.0, 3.0), 11.5, outline_col)
			draw_rect(Rect2(-14.0, -2.0, 28.0, 10.5), outline_col)
			var cloud_col := Color(0.95, 0.98, 0.94, 0.96)
			draw_circle(Vector2(-15.0, 1.0), 8.5, cloud_col)
			draw_circle(Vector2(15.0, 1.0), 8.0, cloud_col)
			draw_circle(Vector2(0.0, -2.0), 11.5, cloud_col)
			draw_circle(Vector2(0.0, 3.0), 9.5, cloud_col)
			draw_rect(Rect2(-13.5, -1.0, 27.0, 8.2), cloud_col)
			draw_arc(Vector2(-6.0, 0.0), 5.0, 0.2, PI * 1.35, 10, Color(0.96, 0.80, 0.36, 0.85), 1.8)
			draw_arc(Vector2(6.0, 1.0), 4.2, PI, TAU * 0.9, 10, Color(0.96, 0.80, 0.36, 0.85), 1.8)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif _mount_type == "gourd" or _mount_type == "fire_wheel":
			draw_set_transform(anchor_pos + Vector2(0.0, 2.0), _tilt * 0.8, Vector2(1.28, 0.40))
			draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.42, 0.14, 0.24))
			draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, Color(1.0, 0.56, 0.18, 0.92), 4.0)
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(0.86, 0.68, 0.28, 0.95), 2.2)
			var spin := _time * (12.0 if _is_dashing else 6.5) * (1.0 if render_fx >= 0.0 else -1.0)
			for i in range(6):
				var ang := spin + float(i) * (TAU / 6.0)
				draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 17.0, Color(0.92, 0.72, 0.32, 0.90), 2.0)
			draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.86, 0.38, 0.98))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var feet_y := -3.0 if (_motion_mode == "hover_ride" and _mount_type != "none") else 0.0
	var body: HeroFrameAnim = _anim_idle
	if _anim_state == "attack" and _anim_attack != null:
		body = _anim_attack
	elif _anim_state == "run" and _anim_run != null:
		body = _anim_run
	if body != null:
		var idx := body.frame()
		var col := idx % body.columns
		var row := idx / body.columns
		var src := Rect2(float(col) * body.cell.x, float(row) * body.cell.y, body.cell.x, body.cell.y)
		var s := _draw_height / maxf(1.0, body.cell.y)
		var dest := Rect2(-body.anchor.x * s, -body.anchor.y * s, body.cell.x * s, body.cell.y * s)
		draw_set_transform(
			anchor_pos + Vector2(0.0, feet_y),
			_tilt,
			Vector2(eff_squash.x * render_fx, eff_squash.y)
		)
		draw_texture_rect_region(body.atlas, dest, src, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif _tex != null:
		var tex_sz := _tex.get_size()
		var draw_w := _draw_height * (tex_sz.x / maxf(1.0, tex_sz.y))
		var draw_h := _draw_height
		draw_set_transform(
			anchor_pos + Vector2(0.0, feet_y),
			_tilt,
			Vector2(eff_squash.x * render_fx, eff_squash.y)
		)
		draw_texture_rect(_tex, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), false, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
