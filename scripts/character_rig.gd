extends RefCounted
class_name CharacterRig
## 通用多方向 2D 角色/怪物动态表现骨架（任天堂 / 吸血鬼幸存者式高响应动画控制器）。
## 后续新增任何角色、小怪、精英或首领，只需配置一份 Profile Dictionary 即可复用：
## - 8 方向运动感知（左右防抖翻转 + 上下朝向微仰/微俯 + 冲锋前倾角）
## - 速度驱动的跑动步频、弹跳弧线（abs(sin) 踏步感）与落地挤压拉伸（Squash & Stretch）
## - 步点相位检测：自动在左/右脚踏地瞬间触发烟尘粒子回调
## - 攻击前摇/扑击冲量（lunge）、受击击退微震与果冻回弹（hit_pop）、蓄力震颤（charge_shake）

enum Facing4 { RIGHT, DOWN, LEFT, UP }

var profile: Dictionary = {}
var anim_time: float = 0.0
var move_phase: float = 0.0
var facing_sign: float = 1.0
var facing_4: int = Facing4.RIGHT
var facing_8: int = 0
var move_dir: Vector2 = Vector2.RIGHT

static func dir_to_octant(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return 0
	var deg := fposmod(rad_to_deg(v.angle()) + 22.5, 360.0)
	return int(floor(deg / 45.0)) % 8
var speed_ratio: float = 0.0
var last_pose: Dictionary = {}

var _attack_lunge: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _hit_pop: float = 0.0
var _hit_intensity: float = 1.0
var _hit_dir: Vector2 = Vector2.RIGHT
var _land_squash: float = 0.0
var _charge_ratio: float = 0.0
var _prev_step_index: int = -1
var _was_moving: bool = false

# 轻量脚步烟尘粒子池（局部绘制，零节点分配开销）
var _dust_puffs: Array[Dictionary] = []

static func make_profile(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"run_frames": 8,
		"idle_frames": 6,
		"run_fps": 12.5,
		"idle_fps": 5.5,
		"bob_amp": 0.8,           # 跑动垂直弹跳幅度（px）
		"idle_breath_amp": 0.012, # 待机呼吸胸腔起伏比例
		"tilt_max_rad": 0.02,     # 移动前倾最大弧度
		"up_down_tilt_rad": 0.0,# 上行/下行附加姿态角
		"waddle_rad": 0.0,
		"gait_mode": "biped",
		"squash_amp": 0.0,      # 踏步挤压拉伸幅度
		"lunge_dist": 7.5,        # 攻击前冲位移（px）
		"lunge_rot": 0.14,        # 攻击挥砍倾角
		"hit_pop_scale": 0.20,    # 受击果冻弹跳幅度
		"flip_deadzone": 8.0,     # 左右翻转死区速度，防止斜向微操抽搐
		"dust_enabled": true,
		"dust_radius": 4.2,
		"dust_color": Color(0.82, 0.90, 0.80, 0.42),
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return base

func _init(cfg: Dictionary = {}) -> void:
	profile = make_profile(cfg)
	anim_time = randf() * TAU
	move_phase = randf() * TAU
	last_pose = update(0.0, Vector2.ZERO)

func get_pose() -> Dictionary:
	if last_pose.is_empty():
		return update(0.0, Vector2.ZERO)
	return last_pose

func trigger_attack(dir: Vector2 = Vector2.ZERO) -> void:
	_attack_lunge = 1.0
	if dir.length_squared() > 0.001:
		_attack_dir = dir.normalized()
		if absf(_attack_dir.x) > 0.15:
			facing_sign = -1.0 if _attack_dir.x < 0.0 else 1.0
	else:
		_attack_dir = Vector2(facing_sign, 0.0)

func trigger_hit(intensity: float = 1.0, dir: Vector2 = Vector2.ZERO) -> void:
	var eff := clampf(intensity, 0.5, 1.85)
	_hit_pop = 1.0
	_hit_intensity = eff
	if dir.length_squared() > 0.001:
		_hit_dir = dir.normalized()
	else:
		_hit_dir = Vector2(-facing_sign, 0.0)

func trigger_land_squash(strength: float = 1.0) -> void:
	_land_squash = clampf(strength, 0.2, 1.8)

func set_charge(ratio: float) -> void:
	_charge_ratio = clampf(ratio, 0.0, 1.0)

func update(delta: float, velocity: Vector2, max_speed: float = 220.0, is_dashing: bool = false) -> Dictionary:
	anim_time += delta
	var spd := velocity.length()
	var deadzone := float(profile.get("flip_deadzone", 8.0))
	var is_moving := spd > deadzone

	if is_moving:
		move_dir = velocity / spd
		speed_ratio = clampf(spd / maxf(40.0, max_speed), 0.25, 1.65)
		facing_8 = dir_to_octant(move_dir)
		if absf(velocity.x) > deadzone:
			facing_sign = -1.0 if velocity.x < 0.0 else 1.0
		if absf(move_dir.x) >= absf(move_dir.y) * 0.85:
			facing_4 = Facing4.LEFT if facing_sign < 0.0 else Facing4.RIGHT
		else:
			facing_4 = Facing4.UP if move_dir.y < 0.0 else Facing4.DOWN

		var run_fps := float(profile.get("run_fps", 12.5)) * lerpf(0.78, 1.28, clampf(speed_ratio, 0.0, 1.3))
		move_phase += delta * run_fps
		# 每半个周期（左脚/右脚落地）生成一朵轻量烟尘
		var step_idx := int(floor(move_phase * 0.5))
		if step_idx != _prev_step_index:
			_prev_step_index = step_idx
			if bool(profile.get("dust_enabled", true)):
				_spawn_dust( -facing_sign * randf_range(4.0, 10.0), is_dashing)
	else:
		speed_ratio = move_toward(speed_ratio, 0.0, delta * 6.0)
		if _was_moving:
			# 急停微挤压回弹
			_land_squash = maxf(_land_squash, 0.45)

	_was_moving = is_moving

	if _attack_lunge > 0.0:
		_attack_lunge = maxf(0.0, _attack_lunge - delta * 6.8)
	if _hit_pop > 0.0:
		_hit_pop = maxf(0.0, _hit_pop - delta * 9.5)
	if _land_squash > 0.0:
		_land_squash = maxf(0.0, _land_squash - delta * 7.5)

	_update_dust(delta)

	# 计算帧索引、弹跳高度、挤压拉伸与方向倾角
	var run_frames := maxi(1, int(profile.get("run_frames", 8)))
	var idle_frames := maxi(1, int(profile.get("idle_frames", 6)))
	var frame_idx := 0
	var bob_y := 0.0
	var sx := 1.0
	var sy := 1.0
	var tilt := 0.0

	if is_moving:
		frame_idx = int(floor(move_phase)) % run_frames
		var step_angle := move_phase * 0.5 * PI
		bob_y = -absf(sin(step_angle)) * float(profile.get("bob_amp", 3.2)) * minf(1.25, speed_ratio)
		var sq := cos(step_angle * 2.0) * float(profile.get("squash_amp", 0.085)) * minf(1.15, speed_ratio)
		sx += sq
		sy -= sq * 0.88
		tilt = move_dir.x * float(profile.get("tilt_max_rad", 0.11)) * minf(1.2, speed_ratio)
		# 上下移动赋予细微的纵深俯仰感
		tilt += move_dir.y * float(profile.get("up_down_tilt_rad", 0.055)) * facing_sign
		var waddle_amp := float(profile.get("waddle_rad", 0.085)) * minf(1.15, speed_ratio)
		var gait_mode := str(profile.get("gait_mode", "biped"))
		if gait_mode == "quadruped":
			tilt -= sin(step_angle * 2.0) * waddle_amp * facing_sign
		elif gait_mode == "biped":
			tilt += sin(step_angle) * waddle_amp
	else:
		var idle_fps := float(profile.get("idle_fps", 5.5))
		frame_idx = int(floor(anim_time * idle_fps)) % idle_frames
		var breath := sin(anim_time * 3.2) * float(profile.get("idle_breath_amp", 0.032))
		sx -= breath * 0.45
		sy += breath
		bob_y = -maxf(0.0, breath) * 18.0

	# 冲刺流线拉伸
	if is_dashing:
		sx = maxf(sx * 1.16, 1.14)
		sy = minf(sy * 0.86, 0.88)
		bob_y -= 3.5

	# 落地/急停挤压
	if _land_squash > 0.0:
		var lsq := _land_squash * 0.14
		sx += lsq
		sy -= lsq * 0.9

	# 攻击前扑与挥砍倾角
	var lunge_offset := Vector2.ZERO
	if _attack_lunge > 0.0:
		var l_curve := sin(_attack_lunge * PI)
		lunge_offset = _attack_dir * (l_curve * float(profile.get("lunge_dist", 7.5)))
		tilt += l_curve * float(profile.get("lunge_rot", 0.14)) * facing_sign
		sx += l_curve * 0.07
		sy -= l_curve * 0.05

	# 受击果冻回弹（先横向压扁再纵向回弹，叠加受击方向冲量偏移）
	var hit_kick_offset := Vector2.ZERO
	if _hit_pop > 0.0:
		var h_wave := sin(_hit_pop * PI * 1.5) * float(profile.get("hit_pop_scale", 0.20)) * _hit_intensity
		sx += h_wave
		sy -= h_wave * 0.72
		var k_wave := sin(_hit_pop * PI)
		hit_kick_offset = _hit_dir * (k_wave * 4.2 * _hit_intensity)
		tilt += _hit_dir.x * facing_sign * k_wave * 0.12 * _hit_intensity

	# 蓄力震颤（Boss / 精英技能前摇）
	var charge_jitter := Vector2.ZERO
	if _charge_ratio > 0.0:
		var amp := (1.5 + _charge_ratio * 3.5)
		charge_jitter = Vector2(sin(anim_time * 54.0), cos(anim_time * 47.0)) * amp
		sx += _charge_ratio * 0.10 * sin(anim_time * 18.0)
		sy -= _charge_ratio * 0.08 * sin(anim_time * 18.0)

	# 上下走位时轻微体现明暗透视层次（向上背身略沉，向下迎面略亮）
	var dir_tint := Color.WHITE
	if is_moving and absf(move_dir.y) > 0.35:
		if move_dir.y < 0.0:
			dir_tint = Color(0.93, 0.97, 1.0, 1.0)
		else:
			dir_tint = Color(1.03, 1.01, 0.98, 1.0)

	last_pose = {
		"is_moving": is_moving,
		"is_attacking": _attack_lunge > 0.0,
		"attack_progress": clampf(1.0 - _attack_lunge, 0.0, 1.0),
		"frame_idx": frame_idx,
		"facing_sign": facing_sign,
		"facing_4": facing_4,
		"facing_8": facing_8,
		"bob_y": bob_y,
		"scale": Vector2(sx * facing_sign, sy),
		"abs_scale": Vector2(sx, sy),
		"rotation": tilt,
		"offset": lunge_offset + hit_kick_offset + charge_jitter + Vector2(0.0, bob_y),
		"dir_tint": dir_tint,
		"shadow_scale": clampf(1.0 - (-bob_y) * 0.025, 0.78, 1.12),
	}
	return last_pose

func _spawn_dust(offset_x: float, big: bool = false) -> void:
	if _dust_puffs.size() >= 10:
		return
	var r := float(profile.get("dust_radius", 4.2)) * (1.45 if big else 1.0)
	_dust_puffs.append({
		"pos": Vector2(offset_x + randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)),
		"vel": Vector2(-facing_sign * randf_range(12.0, 26.0), randf_range(-18.0, -9.0)),
		"age": 0.0,
		"life": randf_range(0.24, 0.36),
		"r": r,
	})

func _update_dust(delta: float) -> void:
	var i := _dust_puffs.size() - 1
	while i >= 0:
		var d: Dictionary = _dust_puffs[i]
		d["age"] = float(d["age"]) + delta
		if float(d["age"]) >= float(d["life"]):
			_dust_puffs.remove_at(i)
		else:
			d["pos"] = (d["pos"] as Vector2) + (d["vel"] as Vector2) * delta
		i -= 1

func draw_dust(canvas: CanvasItem, foot_offset: Vector2 = Vector2(0.0, 20.0)) -> void:
	if _dust_puffs.is_empty():
		return
	var base_col: Color = profile.get("dust_color", Color(0.82, 0.90, 0.80, 0.42))
	for d in _dust_puffs:
		var t := clampf(float(d["age"]) / maxf(0.01, float(d["life"])), 0.0, 1.0)
		var a := (1.0 - t * t) * base_col.a
		var r := float(d["r"]) * (0.65 + t * 0.75)
		canvas.draw_circle(foot_offset + (d["pos"] as Vector2), r, Color(base_col.r, base_col.g, base_col.b, a))
