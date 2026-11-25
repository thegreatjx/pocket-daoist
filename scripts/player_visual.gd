extends Node2D

const TEX_RUN: Texture2D = preload("res://assets/sprites/anim_hero_run.png")
const TEX_IDLE: Texture2D = preload("res://assets/sprites/anim_hero_idle.png")
const TEX_ATTACK: Texture2D = preload("res://assets/sprites/anim_hero_attack.png")
const TEX_GUNNER_RUN: Texture2D = preload("res://assets/sprites/anim_gunner_run.png")
const TEX_GUNNER_IDLE: Texture2D = preload("res://assets/sprites/anim_gunner_idle.png")
const TEX_GUNNER_ATTACK: Texture2D = preload("res://assets/sprites/anim_gunner_attack.png")
const TEX_FLOATING_SWORD: Texture2D = preload("res://assets/sprites/fx_flying_sword.png")
const RUN_FRAMES := 8
const IDLE_FRAMES := 6
const ATTACK_FRAMES := 6
const CELL := 128.0

var rig: CharacterRig = null
var motion_rig: HeroMotionRig = null
var _parent_player: CharacterBody2D = null
var _weapon_pulse: float = 0.0
var _attack_aim: Vector2 = Vector2.RIGHT
var _accent_color: Color = Color(0.24, 0.86, 0.74)
var _is_sheet_mode: bool = false

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		_parent_player = get_parent() as CharacterBody2D
	rig = CharacterRig.new({
		"gait_mode": "biped",
		"run_frames": RUN_FRAMES,
		"idle_frames": IDLE_FRAMES,
		"run_fps": 13.0,
		"idle_fps": 6.0,
		"bob_amp": 0.0,
		"idle_breath_amp": 0.0,
		"waddle_rad": 0.0,
		"tilt_max_rad": 0.0,
		"up_down_tilt_rad": 0.0,
		"squash_amp": 0.0,
		"lunge_dist": 6.5,
		"lunge_rot": 0.06,
		"dust_enabled": true,
		"dust_radius": 4.8,
		"dust_color": Color(0.72, 0.96, 0.86, 0.45),
	})
	sync_character_visual()

func sync_character_visual() -> void:
	var cid := "sword_immortal"
	if _parent_player != null and "character_id" in _parent_player:
		cid = str(_parent_player.character_id)
	if cid == "sword_immortal" and Stats != null and Stats.selected_character_id != "":
		cid = Stats.selected_character_id
	var cfg := CharacterData.get_character(cid)
	var mode := str(cfg.get("motion_mode", "hover_ride"))
	_is_sheet_mode = mode == "sheet"
	var acc = cfg.get("accent_color", Color(0.24, 0.86, 0.74))
	if acc is Color:
		_accent_color = acc
	if not _is_sheet_mode:
		if motion_rig == null:
			motion_rig = HeroMotionRig.new()
			motion_rig.position = Vector2(0.0, 20.0)
			add_child(motion_rig)
		motion_rig.setup(cfg)
	elif motion_rig != null:
		motion_rig.queue_free()
		motion_rig = null
	queue_redraw()

func trigger_hurt_feedback(invuln_sec: float = 0.45) -> void:
	if motion_rig != null:
		motion_rig.trigger_hurt_feedback(invuln_sec)
		if not Settings.get_bool("video/hit_flash"):
			motion_rig._flash_timer = 0.0

func trigger_attack_anim(dir: Vector2 = Vector2.ZERO) -> void:
	var d := dir
	if d.length_squared() < 0.001 and _parent_player != null and "facing_dir" in _parent_player:
		d = _parent_player.facing_dir
	if d.length_squared() > 0.001:
		_attack_aim = d.normalized()
	_weapon_pulse = 1.0
	if motion_rig != null:
		motion_rig.trigger_attack(d)
	if rig != null:
		rig.trigger_attack(d)

func _process(delta: float) -> void:
	if rig == null:
		return
	if _weapon_pulse > 0.0:
		_weapon_pulse = maxf(0.0, _weapon_pulse - delta * 5.2)
	var vel := Vector2.ZERO
	var max_spd := 250.0
	var dashing := false
	var aim_dir := Vector2.RIGHT
	if _parent_player != null and not _parent_player.is_dead:
		vel = _parent_player.velocity
		max_spd = float(_parent_player.speed)
		dashing = bool(_parent_player.is_dashing)
		if _parent_player.has_method("get_aim_direction"):
			aim_dir = _parent_player.get_aim_direction()
	rig.update(delta, vel, max_spd, dashing)
	if motion_rig != null:
		motion_rig.update_motion(vel, delta, dashing, aim_dir)
	if vel.length() <= 8.0 and _parent_player != null and _parent_player.has_method("get_aim_direction"):
		rig.facing_8 = CharacterRig.dir_to_octant(aim_dir)
		if absf(aim_dir.x) > 0.12:
			rig.facing_sign = -1.0 if aim_dir.x < 0.0 else 1.0
			var abs_sc: Vector2 = rig.last_pose["abs_scale"]
			rig.last_pose["facing_sign"] = rig.facing_sign
			rig.last_pose["scale"] = Vector2(abs_sc.x * rig.facing_sign, abs_sc.y)
	queue_redraw()

func _draw() -> void:
	if rig == null:
		return
	var pose := rig.get_pose()
	var sh_sc := float(pose["shadow_scale"])

	var aim_dir := Vector2.RIGHT
	var is_gunner := false
	if _parent_player != null:
		aim_dir = _parent_player.get_aim_direction() if _parent_player.has_method("get_aim_direction") else (_parent_player.facing_dir.normalized() if "facing_dir" in _parent_player else Vector2.RIGHT)
		if "character_id" in _parent_player:
			is_gunner = str(_parent_player.character_id) == "jinyiwei_gunner"

	var ring_col := Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.28)
	draw_set_transform(Vector2(0.0, 22.0), 0.0, Vector2(sh_sc, 0.44 * sh_sc))
	draw_circle(Vector2.ZERO, 20.0, Color(0.08, 0.18, 0.14, 0.26))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 28, ring_col, 2.0)
	var tip := aim_dir * 32.0
	var left_w := aim_dir.rotated(0.35) * 24.0
	var right_w := aim_dir.rotated(-0.35) * 24.0
	draw_colored_polygon(PackedVector2Array([tip, left_w, right_w]), Color(0.98, 0.88, 0.42, 0.62))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if motion_rig != null and not _is_sheet_mode:
		return

	rig.draw_dust(self, Vector2(0.0, 21.0))

	var off: Vector2 = pose["offset"]
	var sc: Vector2 = pose["scale"]
	var abs_sc: Vector2 = pose["abs_scale"]
	var rot: float = float(pose["rotation"])
	var tint: Color = pose["dir_tint"]
	var is_moving: bool = bool(pose["is_moving"])
	var idx: int = int(pose["frame_idx"])
	var t := rig.anim_time
	var facing_s := -1.0 if sc.x < 0.0 else 1.0

	if not is_gunner and TEX_FLOATING_SWORD != null:
		var pulse_wave := sin(_weapon_pulse * PI)
		var hover_pos := Vector2(-facing_s * 24.0, -34.0 + sin(t * 3.4) * 5.0)
		var lunge_pos := hover_pos + _attack_aim * (pulse_wave * 28.0)
		var base_ang := (-0.62 if facing_s > 0.0 else (PI + 0.62)) + sin(t * 2.4) * 0.10
		var sw_ang := lerpf(base_ang, _attack_aim.angle(), pulse_wave * 0.85)
		draw_circle(lunge_pos, 14.0 + pulse_wave * 5.0, Color(0.26, 0.94, 0.82, 0.18 + pulse_wave * 0.18))
		draw_set_transform(lunge_pos, sw_ang, Vector2(1.0 + pulse_wave * 0.15, 1.0))
		draw_texture_rect(TEX_FLOATING_SWORD, Rect2(-26.0, -26.0, 52.0, 52.0), false, Color(1.0, 1.0, 1.0, 0.96))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif is_gunner:
		var pod_pulse := sin(_weapon_pulse * PI)
		var pod_pos := Vector2(-facing_s * 18.0, -48.0 + sin(t * 3.6) * 2.5)
		draw_circle(pod_pos, 12.0 + pod_pulse * 4.0, Color(1.0, 0.52, 0.18, 0.16 + pod_pulse * 0.20))

	var tex_run: Texture2D = TEX_GUNNER_RUN if is_gunner else TEX_RUN
	var tex_idle: Texture2D = TEX_GUNNER_IDLE if is_gunner else TEX_IDLE
	var tex_atk: Texture2D = TEX_GUNNER_ATTACK if is_gunner else TEX_ATTACK

	var draw_off := Vector2.ZERO if is_moving else off
	var draw_rot := 0.0 if is_moving else rot
	var use_attack := (not is_moving) and bool(pose.get("is_attacking", false)) and tex_atk != null
	var dest := Rect2(-46.0, -86.0, 92.0, 92.0)

	if use_attack:
		var atk_sign := -1.0 if aim_dir.x < 0.0 else 1.0
		draw_set_transform(Vector2(roundf(draw_off.x), roundf(22.0 + draw_off.y)), draw_rot, Vector2(abs_sc.x * atk_sign, abs_sc.y))
		var atk_idx := clampi(int(floor(float(pose.get("attack_progress", 0.0)) * float(ATTACK_FRAMES))), 0, ATTACK_FRAMES - 1)
		draw_texture_rect_region(tex_atk, dest, Rect2(float(atk_idx) * CELL, 0.0, CELL, CELL), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2(roundf(draw_off.x), roundf(22.0 + draw_off.y)), draw_rot, sc)
		if is_moving and tex_run != null:
			draw_texture_rect_region(tex_run, dest, Rect2(float(idx % RUN_FRAMES) * CELL, 0.0, CELL, CELL), tint)
		elif tex_idle != null:
			draw_texture_rect_region(tex_idle, dest, Rect2(float(idx % IDLE_FRAMES) * CELL, 0.0, CELL, CELL), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_gunner and _weapon_pulse > 0.35:
		var flash_a := (_weapon_pulse - 0.35) / 0.65
		var f_sign := -1.0 if (use_attack and aim_dir.x < 0.0) or (not use_attack and sc.x < 0.0) else 1.0
		var muzzle := Vector2(f_sign * 42.0, -33.0)
		draw_circle(muzzle, 11.0 * flash_a, Color(1.0, 0.45, 0.14, 0.65 * flash_a))
		draw_circle(muzzle + Vector2(f_sign * 4.0, 0.0), 5.5 * flash_a, Color(1.0, 0.95, 0.72, 0.95 * flash_a))
