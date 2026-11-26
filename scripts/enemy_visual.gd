extends Node2D

const TEX_FOX_SHEET: Texture2D = preload("res://assets/sprites/anim_fox_run.png")
const TEX_DOLL_SHEET: Texture2D = preload("res://assets/sprites/anim_paper_doll_float.png")
const TEX_SHANXIAO_SHEET: Texture2D = preload("res://assets/sprites/anim_shanxiao_run.png")
const TEX_JIANGSHI_SHEET: Texture2D = preload("res://assets/sprites/anim_jiangshi_run.png")
const TEX_JINCHAN_SHEET: Texture2D = preload("res://assets/sprites/anim_jinchan_run.png")
const TEX_SHENJING_SHEET: Texture2D = preload("res://assets/sprites/anim_shenjing_run.png")
const TEX_HUODOU_SHEET: Texture2D = preload("res://assets/sprites/anim_huodou_run.png")
const TEX_ELITE_SHEET: Texture2D = preload("res://assets/sprites/anim_boar_run.png")
const TEX_WOLF_SHEET: Texture2D = preload("res://assets/sprites/anim_wolf_boss_run.png")
const TEX_ELITE_FOX: Texture2D = preload("res://assets/sprites/enemy_elite_fox.png")
const TEX_ELITE_DOLL: Texture2D = preload("res://assets/sprites/enemy_elite_doll.png")
const TEX_ELITE_SHANXIAO: Texture2D = preload("res://assets/sprites/enemy_elite_shanxiao.png")
const TEX_ELITE_JIANGSHI: Texture2D = preload("res://assets/sprites/enemy_elite_jiangshi.png")
const TEX_ELITE_JINCHAN: Texture2D = preload("res://assets/sprites/enemy_elite_jinchan.png")
const TEX_ELITE_SHENJING: Texture2D = preload("res://assets/sprites/enemy_elite_shenjing.png")
const TEX_ELITE_HUODOU: Texture2D = preload("res://assets/sprites/enemy_elite_huodou.png")
const TEX_ELITE_FOX_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_fox_run.png")
const TEX_ELITE_DOLL_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_doll_float.png")
const TEX_ELITE_SHANXIAO_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_shanxiao_run.png")
const TEX_ELITE_JIANGSHI_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_jiangshi_run.png")
const TEX_ELITE_JINCHAN_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_jinchan_run.png")
const TEX_ELITE_SHENJING_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_shenjing_run.png")
const TEX_ELITE_HUODOU_SHEET: Texture2D = preload("res://assets/sprites/anim_elite_huodou_run.png")
const TEX_ZHUSHA_ZIREN_SHEET: Texture2D = preload("res://assets/sprites/anim_zhusha_zhiren_run.png")
const TEX_CHIHUO_DANLING_SHEET: Texture2D = preload("res://assets/sprites/anim_chihuo_danling_run.png")
const TEX_WUDU_ZHANGCHAN_SHEET: Texture2D = preload("res://assets/sprites/anim_wudu_zhangchan_run.png")
const TEX_CANJIAN_JIANKUI_SHEET: Texture2D = preload("res://assets/sprites/anim_canjian_jiankui_run.png")
const TEX_ELITE_YINSHA: Texture2D = preload("res://assets/sprites/enemy_yinsha_daotong.png")
const TEX_ELITE_SHIDUN: Texture2D = preload("res://assets/sprites/enemy_zhenhun_shidun.png")
const TEX_ELITE_YINSHA_SHEET: Texture2D = preload("res://assets/sprites/anim_yinsha_daotong_run.png")
const TEX_ELITE_SHIDUN_SHEET: Texture2D = preload("res://assets/sprites/anim_zhenhun_shidun_run.png")
const TEX_BAGUA_DANLU_SHEET: Texture2D = preload("res://assets/sprites/anim_bagua_danlu_run.png")
const TEX_TONGJIA_SHIWANG_SHEET: Texture2D = preload("res://assets/sprites/anim_tongjia_shiwang_run.png")
const TEX_HUAPI_HUANDAO_SHEET: Texture2D = preload("res://assets/sprites/anim_huapi_huandao_run.png")
const TEX_WANJIAN_MOZUN_SHEET: Texture2D = preload("res://assets/sprites/anim_wanjian_mozun_run.png")

const RUN_FRAMES := 8
const SHANXIAO_FRAMES := 5
const FOX_FRAMES := 6
const DOLL_FRAMES := 6
const WOLF_BOSS_SIZE := 220.0
const CHARGE_PREP_DURATION := 0.40

var enemy_type: int = 0
var species: int = 0
var tier_variant: int = 1

var rig: CharacterRig = null
var _parent_body: CharacterBody2D = null
var _boss_charge_ratio: float = 0.0
var _boss_enraged: bool = false
var _active_elem: String = ""
var last_charge_squash: Vector2 = Vector2.ONE
var _is_charge_windup: bool = false

static func sample_charge_prep_squash(elapsed: float, duration: float = CHARGE_PREP_DURATION) -> Vector2:
	var u := clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	if u <= 1.0 / 3.0:
		return Vector2(1.1, 0.9).lerp(Vector2(0.8, 1.2), u * 3.0)
	if u <= 2.0 / 3.0:
		return Vector2(0.8, 1.2).lerp(Vector2(1.2, 0.8), (u - 1.0 / 3.0) * 3.0)
	return Vector2(1.2, 0.8).lerp(Vector2(1.0, 1.0), (u - 2.0 / 3.0) * 3.0)

static func sample_windup_squash(time_remaining: float, total_duration: float) -> Vector2:
	if time_remaining <= CHARGE_PREP_DURATION:
		return sample_charge_prep_squash(CHARGE_PREP_DURATION - maxf(0.0, time_remaining), CHARGE_PREP_DURATION)
	var lead_dur := maxf(0.01, total_duration - CHARGE_PREP_DURATION)
	var lead_u := clampf((total_duration - time_remaining) / lead_dur, 0.0, 1.0)
	return Vector2.ONE.lerp(Vector2(1.1, 0.9), lead_u)

func set_active_element(elem: String) -> void:
	if _active_elem != elem:
		_active_elem = elem
		queue_redraw()

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		_parent_body = get_parent() as CharacterBody2D
	_rebuild_rig()

func _rebuild_rig() -> void:
	if enemy_type == 0:
		match species:
			1:
				rig = CharacterRig.new({
					"gait_mode": "float",
					"run_frames": DOLL_FRAMES,
					"idle_frames": DOLL_FRAMES,
					"run_fps": 8.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.25,
					"dust_enabled": false,
				})
			2:
				rig = CharacterRig.new({
					"gait_mode": "biped",
					"run_frames": SHANXIAO_FRAMES,
					"idle_frames": SHANXIAO_FRAMES,
					"run_fps": 12.0,
					"bob_amp": 1.6,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.22,
					"dust_enabled": true,
					"dust_radius": 4.2,
				})
			3:
				rig = CharacterRig.new({
					"gait_mode": "biped",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 10.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.22,
					"dust_enabled": true,
					"dust_radius": 3.8,
					"dust_color": Color(0.72, 0.78, 0.88, 0.40),
				})
			4:
				rig = CharacterRig.new({
					"gait_mode": "quadruped",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 9.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.16,
					"dust_enabled": true,
					"dust_radius": 5.4,
					"dust_color": Color(0.88, 0.82, 0.42, 0.45),
				})
			5:
				rig = CharacterRig.new({
					"gait_mode": "biped",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 13.5,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.24,
					"dust_enabled": true,
					"dust_radius": 3.2,
					"dust_color": Color(0.68, 0.92, 0.65, 0.42),
				})
			6:
				rig = CharacterRig.new({
					"gait_mode": "quadruped",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 12.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.20,
					"dust_enabled": true,
					"dust_radius": 4.6,
					"dust_color": Color(0.96, 0.52, 0.28, 0.50),
				})
			7:
				rig = CharacterRig.new({
					"gait_mode": "float",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 9.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.25,
					"dust_enabled": false,
				})
			8:
				rig = CharacterRig.new({
					"gait_mode": "float",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 12.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.08,
					"lunge_dist": 10.0,
					"hit_pop_scale": 0.24,
					"dust_enabled": false,
				})
			9:
				rig = CharacterRig.new({
					"gait_mode": "quadruped",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 8.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.18,
					"dust_enabled": true,
					"dust_radius": 5.0,
					"dust_color": Color(0.62, 0.84, 0.40, 0.42),
				})
			10:
				rig = CharacterRig.new({
					"gait_mode": "float",
					"run_frames": RUN_FRAMES,
					"idle_frames": RUN_FRAMES,
					"run_fps": 10.0,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"lunge_dist": 16.0,
					"hit_pop_scale": 0.22,
					"dust_enabled": false,
				})
			_:
				rig = CharacterRig.new({
					"gait_mode": "quadruped",
					"run_frames": FOX_FRAMES,
					"idle_frames": FOX_FRAMES,
					"run_fps": 10.5,
					"bob_amp": 0.0,
					"idle_breath_amp": 0.0,
					"waddle_rad": 0.0,
					"tilt_max_rad": 0.0,
					"up_down_tilt_rad": 0.0,
					"squash_amp": 0.0,
					"hit_pop_scale": 0.22,
					"dust_enabled": true,
					"dust_radius": 3.8,
				})
	elif enemy_type == 1:
		var e_gait := "quadruped"
		var e_bob := 2.4
		var e_waddle := 0.04
		var e_frames := RUN_FRAMES
		var e_fps := 11.5
		var e_squash := 0.05
		var e_tilt := 0.05
		var e_breath := 0.025
		var e_dust := true
		var e_dcol := Color(0.96, 0.78, 0.42, 0.45)
		match species:
			0:
				e_gait = "quadruped"
				e_bob = 1.0
				e_waddle = 0.015
				e_frames = FOX_FRAMES
				e_fps = 10.5
				e_squash = 0.02
				e_tilt = 0.03
				e_breath = 0.0
				e_dcol = Color(0.98, 0.58, 0.28, 0.46)
			1:
				e_gait = "float"
				e_bob = 0.0
				e_waddle = 0.0
				e_frames = DOLL_FRAMES
				e_fps = 8.0
				e_squash = 0.0
				e_tilt = 0.0
				e_breath = 0.0
				e_dust = false
			2:
				e_gait = "biped"
				e_bob = 1.2
				e_waddle = 0.02
				e_frames = RUN_FRAMES
				e_fps = 11.5
				e_squash = 0.03
				e_tilt = 0.03
				e_breath = 0.0
				e_dcol = Color(0.92, 0.72, 0.36, 0.48)
			3:
				e_gait = "biped"
				e_bob = 0.8
				e_waddle = 0.015
				e_frames = RUN_FRAMES
				e_fps = 10.0
				e_squash = 0.02
				e_tilt = 0.025
				e_breath = 0.0
				e_dcol = Color(0.84, 0.78, 0.38, 0.46)
			4:
				e_gait = "quadruped"
				e_bob = 1.2
				e_waddle = 0.03
				e_fps = 9.0
				e_squash = 0.03
				e_dcol = Color(0.55, 0.92, 0.56, 0.48)
			5:
				e_gait = "biped"
				e_bob = 1.0
				e_waddle = 0.03
				e_fps = 13.5
				e_squash = 0.03
				e_dcol = Color(0.62, 0.96, 0.62, 0.46)
			6:
				e_gait = "quadruped"
				e_bob = 1.4
				e_waddle = 0.04
				e_fps = 12.0
				e_squash = 0.03
				e_dcol = Color(0.98, 0.50, 0.24, 0.52)
			11:
				e_gait = "float"
				e_bob = 0.0
				e_waddle = 0.0
				e_fps = 9.0
				e_squash = 0.0
				e_tilt = 0.0
				e_breath = 0.0
				e_dust = false
				e_dcol = Color(0.40, 0.92, 0.82, 0.46)
			12:
				e_gait = "quadruped"
				e_bob = 0.8
				e_waddle = 0.02
				e_fps = 8.0
				e_squash = 0.02
				e_dcol = Color(0.86, 0.74, 0.38, 0.46)
			_:
				e_gait = "quadruped"
				e_bob = 1.0
				e_waddle = 0.015
				e_frames = FOX_FRAMES
				e_fps = 10.5
				e_squash = 0.02
				e_tilt = 0.03
				e_breath = 0.0
				e_dcol = Color(0.98, 0.58, 0.28, 0.46)
		rig = CharacterRig.new({
			"gait_mode": e_gait,
			"run_frames": e_frames,
			"idle_frames": e_frames,
			"run_fps": e_fps,
			"bob_amp": e_bob,
			"idle_breath_amp": e_breath,
			"waddle_rad": e_waddle,
			"tilt_max_rad": e_tilt,
			"up_down_tilt_rad": e_tilt * 0.4,
			"squash_amp": e_squash,
			"lunge_dist": 12.0,
			"hit_pop_scale": 0.18,
			"dust_enabled": e_dust,
			"dust_radius": 6.0,
			"dust_color": e_dcol,
		})
	else:
		rig = CharacterRig.new({
			"gait_mode": "quadruped",
			"run_frames": RUN_FRAMES,
			"idle_frames": RUN_FRAMES,
			"run_fps": 11.5,
			"bob_amp": 0.0,
			"idle_breath_amp": 0.0,
			"waddle_rad": 0.0,
			"tilt_max_rad": 0.0,
			"up_down_tilt_rad": 0.0,
			"squash_amp": 0.0,
			"lunge_dist": 14.0,
			"lunge_rot": 0.12,
			"hit_pop_scale": 0.14,
			"dust_enabled": true,
			"dust_radius": 8.5,
			"dust_color": Color(0.98, 0.84, 0.38, 0.48),
		})

func set_type(type_val: int, sp_val: int = 0) -> void:
	enemy_type = type_val
	species = sp_val
	tier_variant = 1
	_boss_charge_ratio = 0.0
	_boss_enraged = false
	last_charge_squash = Vector2.ONE
	_is_charge_windup = false
	_rebuild_rig()
	queue_redraw()

func set_tier_variant(variant: int) -> void:
	var nv := clampi(variant, 1, 3)
	if tier_variant != nv:
		tier_variant = nv
		queue_redraw()

func trigger_hit_pop(intensity: float = 1.0, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if rig != null:
		rig.trigger_hit(intensity, hit_dir)

func trigger_attack_lunge(dir: Vector2 = Vector2.ZERO) -> void:
	if rig != null:
		rig.trigger_attack(dir)

func trigger_land_impact(strength: float = 1.2) -> void:
	if rig != null:
		rig.trigger_land_squash(strength)

func set_boss_state(charge_ratio: float, enraged: bool = false) -> void:
	_boss_charge_ratio = clampf(charge_ratio, 0.0, 1.0)
	_boss_enraged = enraged
	if rig != null:
		rig.set_charge(_boss_charge_ratio)

func _update_charge_squash() -> void:
	last_charge_squash = Vector2.ONE
	_is_charge_windup = false
	if _parent_body == null or _parent_body.is_dead:
		return
	if enemy_type == 0:
		var ch_state := int(_parent_body.get("_charger_state")) if "_charger_state" in _parent_body else 0
		if ch_state == 1:
			_is_charge_windup = true
			var ch_t := float(_parent_body.get("_charger_timer"))
			var ch_tot := float(_parent_body.get("_charger_windup_total")) if "_charger_windup_total" in _parent_body else CHARGE_PREP_DURATION
			last_charge_squash = sample_windup_squash(ch_t, ch_tot)
		elif ch_state == 2:
			last_charge_squash = Vector2(1.18, 0.85)
	elif enemy_type == 1:
		var el_state := int(_parent_body.get("_elite_state")) if "_elite_state" in _parent_body else 0
		if el_state == 1:
			_is_charge_windup = true
			var el_t := float(_parent_body.get("_elite_timer"))
			var el_tot := float(_parent_body.get("_elite_windup_total")) if "_elite_windup_total" in _parent_body else 0.65
			last_charge_squash = sample_windup_squash(el_t, el_tot)
		elif el_state == 2:
			last_charge_squash = Vector2(1.18, 0.85)
	elif enemy_type == 2:
		var b_state := int(_parent_body.get("_boss_state")) if "_boss_state" in _parent_body else 0
		var b_skill := String(_parent_body.get("_boss_active_skill")) if "_boss_active_skill" in _parent_body else ""
		var b_dash := bool(_parent_body.get("_boss_dashing")) if "_boss_dashing" in _parent_body else false
		if b_state == 1 and b_skill == "dash":
			_is_charge_windup = true
			var b_t := float(_parent_body.get("_boss_state_timer"))
			var b_tot := float(_parent_body.get("_boss_windup_total")) if "_boss_windup_total" in _parent_body else 0.74
			last_charge_squash = sample_windup_squash(b_t, b_tot)
		elif b_dash:
			last_charge_squash = Vector2(1.18, 0.85)

func _process(delta: float) -> void:
	if rig == null:
		_rebuild_rig()
	var vel := Vector2.ZERO
	var max_spd := 135.0
	var dashing := false
	if _parent_body != null and not _parent_body.is_dead:
		vel = _parent_body.velocity
		max_spd = maxf(60.0, float(_parent_body.speed))
		if "_boss_dashing" in _parent_body:
			dashing = bool(_parent_body._boss_dashing)
	rig.update(delta, vel, max_spd, dashing)
	_update_charge_squash()
	queue_redraw()

func _draw() -> void:
	if rig == null:
		return
	var mini_boss := false
	if _parent_body != null and "is_mini_boss" in _parent_body:
		mini_boss = bool(_parent_body.get("is_mini_boss"))
	if mini_boss and _parent_body != null:
		var mb_total := float(_parent_body.get("max_health"))
		var mb_now := float(_parent_body.get("current_health"))
		if mb_total > 0.0:
			var bar_w := 76.0
			var bar_ratio := clampf(mb_now / mb_total, 0.0, 1.0)
			draw_rect(Rect2(-bar_w * 0.5, -86.0, bar_w, 8.0), Color(0.05, 0.09, 0.07, 0.86))
			draw_rect(Rect2(-bar_w * 0.5 + 1.0, -85.0, (bar_w - 2.0) * bar_ratio, 6.0), Color(0.88, 0.28, 0.20, 1.0))
			draw_rect(Rect2(-bar_w * 0.5, -86.0, bar_w, 8.0), Color(0.92, 0.76, 0.34, 0.9), false, 1.0)
	var pose := rig.get_pose()
	var t := rig.anim_time
	var off: Vector2 = pose["offset"]
	var sc: Vector2 = pose["scale"]
	var rot: float = float(pose["rotation"])
	var tint: Color = pose["dir_tint"]
	var idx: int = int(pose["frame_idx"])
	var sh_sc: float = float(pose["shadow_scale"])
	if mini_boss:
		sc *= 1.7
	var affix_aura := Color(0.0, 0.0, 0.0, 0.0)
	if _parent_body != null and "elite_aura_color" in _parent_body:
		var raw_aura = _parent_body.get("elite_aura_color")
		if raw_aura is Color:
			affix_aura = raw_aura
	if affix_aura.a > 0.0:
		_draw_kenney_aura(Vector2(0.0, 16.0), 26.0, Color(affix_aura.r, affix_aura.g, affix_aura.b, 0.38 + 0.12 * sin(t * 4.2)), true)
	if enemy_type < 2:
		sc = Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y)
		if _is_charge_windup:
			tint = Color(1.25, 0.88, 0.80, 1.0)

	if enemy_type == 0:
		if tier_variant == 2:
			sc *= 1.08
			tint *= Color(0.94, 1.04, 1.12, 1.0)
		elif tier_variant >= 3:
			sc *= 1.14
			tint *= Color(1.14, 0.90, 0.86, 1.0)
		_draw_shadow(16.0 * sh_sc, 18.0)
		if tier_variant >= 3:
			_draw_kenney_aura(Vector2(0.0, 17.0), 26.0, Color(0.96, 0.36, 0.30, 0.42), false)
		rig.draw_dust(self, Vector2(0.0, 17.0))
		match species:
			1:
				var float_y := roundf(sin(t * 4.5) * 4.0)
				var aura_a := 0.32 + 0.12 * sin(t * 5.2)
				draw_texture_rect(V2VfxFactory.TEX_FLARE_01, Rect2(-26.0, float_y - 30.0, 52.0, 52.0), false, Color(0.24, 0.88, 0.78, aura_a))
				if TEX_DOLL_SHEET != null:
					var doll_idx := int(floor(t * 8.0)) % DOLL_FRAMES
					var src := Rect2(float(doll_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(14.0 + float_y + off.y * 0.4)), rot, sc)
					draw_texture_rect_region(TEX_DOLL_SHEET, Rect2(-29.0, -54.0, 58.0, 58.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			2:
				if TEX_SHANXIAO_SHEET != null:
					var sx_idx := idx % SHANXIAO_FRAMES
					var src := Rect2(float(sx_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_SHANXIAO_SHEET, Rect2(-32.0, -60.0, 64.0, 64.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			3:
				if TEX_JIANGSHI_SHEET != null:
					var js_idx := idx % RUN_FRAMES
					var src := Rect2(float(js_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_JIANGSHI_SHEET, Rect2(-32.0, -58.0, 64.0, 64.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			4:
				if TEX_JINCHAN_SHEET != null:
					var jc_idx := idx % RUN_FRAMES
					var src := Rect2(float(jc_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_JINCHAN_SHEET, Rect2(-36.0, -54.0, 72.0, 72.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			5:
				if TEX_SHENJING_SHEET != null:
					var sj_idx := idx % RUN_FRAMES
					var src := Rect2(float(sj_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_SHENJING_SHEET, Rect2(-30.0, -56.0, 60.0, 60.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			6:
				_draw_kenney_aura(Vector2(0.0, 18.0), 28.0, Color(0.98, 0.48, 0.22, 0.34 + 0.12 * sin(t * 5.2)), false)
				if TEX_HUODOU_SHEET != null:
					var hd_idx := idx % RUN_FRAMES
					var src := Rect2(float(hd_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_HUODOU_SHEET, Rect2(-36.0, -54.0, 72.0, 72.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			7:
				if TEX_ZHUSHA_ZIREN_SHEET != null:
					var zz_idx := idx % RUN_FRAMES
					var src := Rect2(float(zz_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_ZHUSHA_ZIREN_SHEET, Rect2(-56.0, -89.0, 112.0, 112.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			8:
				_draw_kenney_aura(Vector2(0.0, 18.0), 24.0, Color(1.0, 0.56, 0.22, 0.30 + 0.10 * sin(t * 6.0)), false)
				if TEX_CHIHUO_DANLING_SHEET != null:
					var cd_idx := idx % RUN_FRAMES
					var src := Rect2(float(cd_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_CHIHUO_DANLING_SHEET, Rect2(-56.0, -89.0, 112.0, 112.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			9:
				if TEX_WUDU_ZHANGCHAN_SHEET != null:
					var wz_idx := idx % RUN_FRAMES
					var src := Rect2(float(wz_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_WUDU_ZHANGCHAN_SHEET, Rect2(-56.0, -89.0, 112.0, 112.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			10:
				if TEX_CANJIAN_JIANKUI_SHEET != null:
					var cj_idx := idx % RUN_FRAMES
					var src := Rect2(float(cj_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_CANJIAN_JIANKUI_SHEET, Rect2(-56.0, -89.0, 112.0, 112.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				if TEX_FOX_SHEET != null:
					var r_idx := idx % FOX_FRAMES
					var stride := clampf(rig.speed_ratio, 0.0, 1.0)
					var fox_phase := rig.move_phase * PI / 3.0
					var bob_y := -absf(sin(fox_phase)) * 1.6 * stride
					var fox_rot := rot + cos(fox_phase) * 0.03 * rig.facing_sign * stride
					var src := Rect2(float(r_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y + bob_y)), fox_rot, sc)
					draw_texture_rect_region(TEX_FOX_SHEET, Rect2(-32.0, -52.0, 64.0, 64.0), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif enemy_type == 1:
		_draw_shadow(28.0 * sh_sc, 22.0)
		rig.draw_dust(self, Vector2(0.0, 21.0))
		var aura_a := 0.30 + 0.12 * sin(t * 5.0)
		var elite_col := Color(0.98, 0.48, 0.22, aura_a)
		var elite_tex: Texture2D = TEX_ELITE_FOX
		var elite_sheet: Texture2D = TEX_ELITE_FOX_SHEET
		var elite_frames := FOX_FRAMES
		var draw_rect := Rect2(-46.0, -81.0, 92.0, 92.0)
		var extra_y := 0.0
		var elite_frame_px := 128.0
		match species:
			0:
				elite_col = Color(0.96, 0.44, 0.24, aura_a)
				elite_tex = TEX_ELITE_FOX
				elite_sheet = TEX_ELITE_FOX_SHEET
				elite_frames = FOX_FRAMES
				draw_rect = Rect2(-46.0, -81.0, 92.0, 92.0)
			1:
				elite_col = Color(0.22, 0.88, 0.78, aura_a)
				elite_tex = TEX_ELITE_DOLL
				elite_sheet = TEX_ELITE_DOLL_SHEET
				elite_frames = DOLL_FRAMES
				draw_rect = Rect2(-46.0, -85.0, 92.0, 92.0)
			2:
				elite_col = Color(0.96, 0.62, 0.22, aura_a)
				elite_tex = TEX_ELITE_SHANXIAO
				elite_sheet = TEX_ELITE_SHANXIAO_SHEET
				elite_frames = RUN_FRAMES
				draw_rect = Rect2(-50.0, -90.0, 100.0, 100.0)
			3:
				elite_col = Color(0.84, 0.76, 0.30, aura_a)
				elite_tex = TEX_ELITE_JIANGSHI
				elite_sheet = TEX_ELITE_JIANGSHI_SHEET
				elite_frames = RUN_FRAMES
				draw_rect = Rect2(-50.0, -92.0, 100.0, 100.0)
			4:
				elite_col = Color(0.45, 0.94, 0.56, aura_a)
				elite_tex = TEX_ELITE_JINCHAN
				elite_sheet = TEX_ELITE_JINCHAN_SHEET
				elite_frames = RUN_FRAMES
				draw_rect = Rect2(-50.0, -84.0, 100.0, 100.0)
			5:
				elite_col = Color(0.48, 0.96, 0.56, aura_a)
				elite_tex = TEX_ELITE_SHENJING
				elite_sheet = TEX_ELITE_SHENJING_SHEET
				elite_frames = RUN_FRAMES
				draw_rect = Rect2(-44.0, -84.0, 88.0, 88.0)
			6:
				elite_col = Color(1.0, 0.42, 0.16, aura_a)
				elite_tex = TEX_ELITE_HUODOU
				elite_sheet = TEX_ELITE_HUODOU_SHEET
				elite_frames = RUN_FRAMES
				draw_rect = Rect2(-50.0, -84.0, 100.0, 100.0)
			11:
				elite_col = Color(0.31, 0.90, 0.76, aura_a)
				elite_tex = TEX_ELITE_YINSHA
				elite_sheet = TEX_ELITE_YINSHA_SHEET
				elite_frames = RUN_FRAMES
				elite_frame_px = 160.0
				draw_rect = Rect2(-66.0, -92.0, 132.0, 132.0)
			12:
				elite_col = Color(0.88, 0.74, 0.34, aura_a)
				elite_tex = TEX_ELITE_SHIDUN
				elite_sheet = TEX_ELITE_SHIDUN_SHEET
				elite_frames = RUN_FRAMES
				elite_frame_px = 160.0
				draw_rect = Rect2(-66.0, -92.0, 132.0, 132.0)
			_:
				elite_col = Color(0.96, 0.44, 0.24, aura_a)
				elite_tex = TEX_ELITE_FOX
				elite_sheet = TEX_ELITE_FOX_SHEET
				elite_frames = FOX_FRAMES
				draw_rect = Rect2(-46.0, -81.0, 92.0, 92.0)
		draw_set_transform(Vector2(0.0, 22.0), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, elite_col, 3.0)
		draw_arc(Vector2.ZERO, 40.0 + sin(t * 4.0) * 1.5, 0.0, TAU, 24, Color(1.0, 0.86, 0.34, aura_a * 0.65), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if elite_sheet != null:
			var e_idx := idx % elite_frames
			var e_src := Rect2(float(e_idx) * elite_frame_px, 0.0, elite_frame_px, elite_frame_px)
			draw_set_transform(Vector2(roundf(off.x), roundf(22.0 + off.y + extra_y)), rot, sc)
			draw_texture_rect_region(elite_sheet, draw_rect, e_src, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif elite_tex != null:
			draw_set_transform(Vector2(roundf(off.x), roundf(22.0 + off.y + extra_y)), rot, sc)
			draw_texture_rect(elite_tex, draw_rect, false, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif TEX_ELITE_SHEET != null:
			var r_idx := idx % RUN_FRAMES
			var src := Rect2(float(r_idx) * 128.0, 0.0, 128.0, 128.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(22.0 + off.y)), rot, sc)
			draw_texture_rect_region(TEX_ELITE_SHEET, Rect2(-48.0, -83.0, 96.0, 96.0), src, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif enemy_type == 2:
		_draw_shadow(52.0 * sh_sc, 36.0)
		rig.draw_dust(self, Vector2(0.0, 34.0))
		var aura_a := 0.38 + 0.16 * sin(t * 4.5)
		var ring_col1 := Color(1.0, 0.34, 0.24, aura_a + 0.2) if (_boss_enraged or _boss_charge_ratio > 0.05) else Color(0.96, 0.78, 0.28, aura_a)
		var ring_col2 := Color(1.0, 0.82, 0.32, aura_a) if _boss_enraged else Color(0.26, 0.88, 0.76, aura_a * 0.85)
		draw_set_transform(Vector2(0.0, 34.0), 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, 62.0 + _boss_charge_ratio * 14.0, 0.0, TAU, 36, ring_col1, 4.5 + _boss_charge_ratio * 2.5)
		draw_arc(Vector2.ZERO, 74.0 + _boss_charge_ratio * 18.0, 0.0, TAU, 36, ring_col2, 2.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var boss_tint := tint
		if _boss_charge_ratio > 0.05:
			var pulse := 0.5 + 0.5 * sin(t * 28.0)
			boss_tint = Color(1.0 + _boss_charge_ratio * 0.45 * pulse, 0.92 - _boss_charge_ratio * 0.25, 0.82 - _boss_charge_ratio * 0.3, 1.0)
		elif _boss_enraged:
			boss_tint = Color(1.18, 0.90, 0.88, 1.0)

		var anim_state := "chase"
		if _parent_body != null and _parent_body.has_method("get_boss_anim_state"):
			anim_state = _parent_body.get_boss_anim_state()

		if species == 1 and TEX_DOLL_SHEET != null:
			var fy := 0.0 if anim_state == "windup" else sin(t * 4.5) * 6.0
			var use_sc := Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y) if anim_state == "windup" and _is_charge_windup else (Vector2(sc.x * 1.08, sc.y * 0.88) if anim_state == "windup" else sc)
			var doll_idx := 0 if anim_state == "windup" else int(floor(t * 8.0)) % DOLL_FRAMES
			var src := Rect2(float(doll_idx) * 96.0, 0.0, 96.0, 96.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), rot, use_sc)
			draw_texture_rect_region(TEX_DOLL_SHEET, Rect2(-74.0, -142.0 + fy, 148.0, 148.0), src, boss_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif species == 2 and TEX_ELITE_SHEET != null:
			var use_sc := Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y) if (anim_state == "windup" and _is_charge_windup) or anim_state == "pounce" else (Vector2(sc.x * 1.08, sc.y * 0.88) if anim_state == "windup" else sc)
			var r_idx := 2 if anim_state == "windup" else idx % RUN_FRAMES
			var src := Rect2(float(r_idx) * 128.0, 0.0, 128.0, 128.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), rot, use_sc)
			draw_texture_rect_region(TEX_ELITE_SHEET, Rect2(-80.0, -142.0, 160.0, 160.0), src, boss_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif species >= 3 and species <= 6:
			var boss_sheet: Texture2D = TEX_BAGUA_DANLU_SHEET
			match species:
				4:
					boss_sheet = TEX_TONGJIA_SHIWANG_SHEET
				5:
					boss_sheet = TEX_HUAPI_HUANDAO_SHEET
				6:
					boss_sheet = TEX_WANJIAN_MOZUN_SHEET
			if boss_sheet != null:
				var col := idx % RUN_FRAMES
				draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), rot, sc)
				var src := Rect2(float(col) * 224.0, 0.0, 224.0, 224.0)
				draw_texture_rect_region(boss_sheet, Rect2(-135.0, -233.0, 270.0, 270.0), src, boss_tint)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif TEX_WOLF_SHEET != null:
			var col := idx % RUN_FRAMES
			var use_sc := sc
			var use_rot := rot
			match anim_state:
				"windup":
					col = 0
					use_sc = Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y) if _is_charge_windup else Vector2(sc.x * 1.08, sc.y * 0.86)
				"pounce":
					use_sc = Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y)
					use_rot = rot + 0.12 * rig.facing_sign
				"roar":
					use_sc = Vector2(sc.x * 0.94, sc.y * 1.14)
					boss_tint = Color(1.22, 0.86, 0.84, 1.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), use_rot, use_sc)
			var src := Rect2(float(col) * WOLF_BOSS_SIZE, 0.0, WOLF_BOSS_SIZE, WOLF_BOSS_SIZE)
			draw_texture_rect_region(TEX_WOLF_SHEET, Rect2(-94.0, -168.0, 188.0, 188.0), src, boss_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _parent_body != null and not _parent_body.is_dead and _parent_body.has_method("is_burning") and _parent_body.is_burning():
		var burn_sc := 1.85 if enemy_type == 2 else (1.30 if enemy_type == 1 else 1.0)
		var base_y := 18.0 if enemy_type == 2 else (10.0 if enemy_type == 1 else 6.0)
		for bi in range(3):
			var bx := (float(bi) - 1.0) * 10.0 * burn_sc + sin(t * 14.0 + float(bi) * 2.1) * 2.2
			var fh := (24.0 + 6.0 * sin(t * 18.0 + float(bi) * 1.7)) * burn_sc
			var fw := 18.0 * burn_sc
			var by := base_y - fh * 0.65 - absf(sin(t * 12.0 + float(bi))) * 4.0 * burn_sc
			var f_tex := V2VfxFactory.TEX_FLAME_01 if bi != 1 else V2VfxFactory.TEX_FLAME_05
			draw_texture_rect(f_tex, Rect2(bx - fw * 0.5, by - fh * 0.5, fw, fh), false, Color(1.0, 0.44 + 0.14 * float(bi % 2), 0.10, 0.72))
			draw_texture_rect(V2VfxFactory.TEX_FIRE_01, Rect2(bx - fw * 0.32, by - fh * 0.25, fw * 0.64, fh * 0.64), false, Color(1.0, 0.92, 0.58, 0.66))

	if not _active_elem.is_empty():
		var ec := _elem_color(_active_elem)
		var pip_y := -66.0 if enemy_type == 2 else (-44.0 if enemy_type == 1 else -34.0)
		var pip_pos := Vector2(0.0, pip_y)
		draw_circle(pip_pos, 8.0, Color(0.05, 0.08, 0.09, 0.88))
		draw_arc(pip_pos, 8.0, 0.0, TAU, 16, Color(ec.r, ec.g, ec.b, 0.90), 1.4)
		var glyph := V2VfxFactory.elem_glyph_texture(_active_elem)
		if glyph != null:
			draw_texture_rect(glyph, Rect2(pip_pos - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), false, ec)
		else:
			draw_circle(pip_pos, 4.2, ec)

func _elem_color(elem: String) -> Color:
	match elem:
		"fire": return Color(0.98, 0.45, 0.14)
		"ice": return Color(0.24, 0.80, 0.98)
		"water": return Color(0.10, 0.86, 0.92)
		"thunder": return Color(0.62, 0.56, 0.98)
		"wood": return Color(0.22, 0.86, 0.42)
		"venom": return Color(0.14, 0.84, 0.52)
		"metal": return Color(0.98, 0.78, 0.24)
		_: return Color.WHITE

func _draw_shadow(radius: float, y_offset: float) -> void:
	draw_set_transform(Vector2(0.0, y_offset), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, radius, Color(0.08, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_kenney_aura(center: Vector2, radius: float, col: Color, is_magic: bool) -> void:
	var tex := V2VfxFactory.TEX_MAGIC_02 if is_magic else V2VfxFactory.TEX_CIRCLE_03
	draw_set_transform(center, 0.0, Vector2(1.0, 0.45))
	draw_texture_rect(tex, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
