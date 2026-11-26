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
const SHADER_STILL_MOTION: Shader = preload("res://shaders/enemy_still_motion.gdshader")
const TEX_FENYU_SANYA_STILL: Texture2D = preload("res://assets/sprites/enemy_fenyu_sanya.png")
const TEX_XUEYI_YEFU_STILL: Texture2D = preload("res://assets/sprites/enemy_xueyi_yefu.png")
const TEX_QINGYAN_DENGLONG_STILL: Texture2D = preload("res://assets/sprites/enemy_qingyan_denglong.png")
const TEX_DUYAN_TANGSAN_STILL: Texture2D = preload("res://assets/sprites/enemy_duyan_tangsan.png")
const TEX_BICHI_ZHONGSI_STILL: Texture2D = preload("res://assets/sprites/enemy_bichi_zhongsi.png")
const TEX_LINJIA_CHUANSHAN_STILL: Texture2D = preload("res://assets/sprites/enemy_linjia_chuanshan.png")
const TEX_CHIHUAN_WUGONG_STILL: Texture2D = preload("res://assets/sprites/enemy_chihuan_wugong.png")
const TEX_KULOU_DIZHU_STILL: Texture2D = preload("res://assets/sprites/enemy_kulou_dizhu.png")
const TEX_LINGZHI_GUJING_STILL: Texture2D = preload("res://assets/sprites/enemy_lingzhi_gujing.png")
const TEX_TONGKE_XIEJIANG_STILL: Texture2D = preload("res://assets/sprites/enemy_tongke_xiejiang.png")

enum StillMotion {
	NONE = 0,
	WING_FLAP = 1,
	GHOST_FLOAT = 2,
	HOP_BOUNCE = 3,
	BURROW_SURGE = 4,
	SLITHER_WAVE = 5,
	SCUTTLE_STOMP = 6,
	JELLY_WOBBLE = 7,
}

const RUN_FRAMES := 8
const SHANXIAO_FRAMES := 5
const FOX_FRAMES := 6
const DOLL_FRAMES := 6
const WOLF_BOSS_SIZE := 220.0
const CHARGE_PREP_DURATION := 0.40

# 四层怪物黄金像素标尺（以主角视觉身高 ~80px 为锚点）
const SIZE_MINION_FAST := 58.0      # 疾行/纸符等轻巧小怪
const SIZE_MINION_BASE := 62.0      # 常规小怪
const SIZE_MINION_TANK := 66.0      # 肉盾小怪（略敦实但不越级）
const SIZE_ELITE := 92.0            # 精英怪 = 小怪 ~1.5x
const SIZE_MINI_BOSS := 120.0       # 小 Boss = 小怪 ~2.0x
const SIZE_HUMANOID_BOSS := 136.0   # 人形大 Boss = 主角 ~1.7x（靠法阵/气场显霸气）
const SIZE_BEAST_BOSS := 175.0      # 巨兽大 Boss（苍鬃狼王）= 小怪 ~2.8x / 主角 ~2.1x

const STILL_SPECIES := {
	13: {
		"tex": TEX_FENYU_SANYA_STILL,
		"motion": StillMotion.WING_FLAP,
		"native_facing": -1.0,
		"size": SIZE_MINION_TANK,
		"hover_y": -10.0,
		"hover_amp": 3.2,
		"hover_freq": 6.5,
		"skew_amp": 0.025,
		"skew_freq": 6.5,
		"aura_col": Color(1.0, 0.45, 0.16, 0.34),
		"elite_col": Color(1.0, 0.46, 0.18, 0.36),
		"rig": {
			"gait_mode": "float", "run_frames": 1, "idle_frames": 1, "run_fps": 10.0,
			"bob_amp": 2.2, "idle_breath_amp": 0.02, "waddle_rad": 0.0, "tilt_max_rad": 0.08,
			"up_down_tilt_rad": 0.03, "squash_amp": 0.035, "hit_pop_scale": 0.22, "dust_enabled": false,
		},
	},
	14: {
		"tex": TEX_XUEYI_YEFU_STILL,
		"motion": StillMotion.WING_FLAP,
		"native_facing": -1.0,
		"size": SIZE_MINION_BASE,
		"hover_y": -11.0,
		"hover_amp": 3.6,
		"hover_freq": 7.5,
		"skew_amp": 0.03,
		"skew_freq": 7.5,
		"aura_col": Color(0.75, 0.18, 0.36, 0.24),
		"elite_col": Color(0.86, 0.24, 0.42, 0.36),
		"rig": {
			"gait_mode": "float", "run_frames": 1, "idle_frames": 1, "run_fps": 11.0,
			"bob_amp": 2.6, "idle_breath_amp": 0.02, "waddle_rad": 0.0, "tilt_max_rad": 0.10,
			"up_down_tilt_rad": 0.03, "squash_amp": 0.04, "hit_pop_scale": 0.24, "dust_enabled": false,
		},
	},
	15: {
		"tex": TEX_QINGYAN_DENGLONG_STILL,
		"motion": StillMotion.GHOST_FLOAT,
		"native_facing": 1.0,
		"size": SIZE_MINION_BASE,
		"hover_y": -9.0,
		"hover_amp": 4.2,
		"hover_freq": 4.6,
		"skew_amp": 0.04,
		"skew_freq": 4.6,
		"aura_col": Color(0.22, 0.90, 0.72, 0.34),
		"elite_col": Color(0.26, 0.94, 0.76, 0.38),
		"rig": {
			"gait_mode": "float", "run_frames": 1, "idle_frames": 1, "run_fps": 8.0,
			"bob_amp": 0.0, "idle_breath_amp": 0.02, "waddle_rad": 0.0, "tilt_max_rad": 0.07,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.02, "hit_pop_scale": 0.24, "dust_enabled": false,
		},
	},
	16: {
		"tex": TEX_DUYAN_TANGSAN_STILL,
		"motion": StillMotion.HOP_BOUNCE,
		"native_facing": -1.0,
		"size": SIZE_MINION_BASE,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.045,
		"skew_freq": 7.5,
		"aura_col": Color(0.28, 0.86, 0.82, 0.24),
		"elite_col": Color(0.32, 0.90, 0.86, 0.36),
		"rig": {
			"gait_mode": "biped", "run_frames": 1, "idle_frames": 1, "run_fps": 10.0,
			"bob_amp": 5.5, "idle_breath_amp": 0.02, "waddle_rad": 0.05, "tilt_max_rad": 0.08,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.08, "hit_pop_scale": 0.24, "dust_enabled": true,
			"dust_radius": 3.8, "dust_color": Color(0.68, 0.88, 0.86, 0.42),
		},
	},
	17: {
		"tex": TEX_BICHI_ZHONGSI_STILL,
		"motion": StillMotion.HOP_BOUNCE,
		"native_facing": -1.0,
		"size": SIZE_MINION_FAST,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.04,
		"skew_freq": 9.0,
		"aura_col": Color(0.0, 0.0, 0.0, 0.0),
		"elite_col": Color(0.45, 0.92, 0.48, 0.36),
		"rig": {
			"gait_mode": "quadruped", "run_frames": 1, "idle_frames": 1, "run_fps": 12.0,
			"bob_amp": 5.2, "idle_breath_amp": 0.02, "waddle_rad": 0.04, "tilt_max_rad": 0.09,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.085, "hit_pop_scale": 0.24, "dust_enabled": true,
			"dust_radius": 3.4, "dust_color": Color(0.72, 0.90, 0.62, 0.42),
		},
	},
	18: {
		"tex": TEX_LINJIA_CHUANSHAN_STILL,
		"motion": StillMotion.BURROW_SURGE,
		"native_facing": 1.0,
		"size": SIZE_MINION_TANK,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.018,
		"skew_freq": 10.0,
		"aura_col": Color(0.0, 0.0, 0.0, 0.0),
		"elite_col": Color(0.92, 0.72, 0.32, 0.36),
		"rig": {
			"gait_mode": "quadruped", "run_frames": 1, "idle_frames": 1, "run_fps": 9.0,
			"bob_amp": 1.4, "idle_breath_amp": 0.015, "waddle_rad": 0.025, "tilt_max_rad": 0.04,
			"up_down_tilt_rad": 0.015, "squash_amp": 0.045, "hit_pop_scale": 0.16, "dust_enabled": true,
			"dust_radius": 5.2, "dust_color": Color(0.76, 0.64, 0.46, 0.48),
		},
	},
	19: {
		"tex": TEX_CHIHUAN_WUGONG_STILL,
		"motion": StillMotion.SLITHER_WAVE,
		"native_facing": -1.0,
		"size": SIZE_MINION_BASE,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.05,
		"skew_freq": 8.0,
		"aura_col": Color(0.96, 0.44, 0.18, 0.24),
		"elite_col": Color(0.98, 0.46, 0.20, 0.36),
		"rig": {
			"gait_mode": "quadruped", "run_frames": 1, "idle_frames": 1, "run_fps": 11.0,
			"bob_amp": 1.6, "idle_breath_amp": 0.02, "waddle_rad": 0.045, "tilt_max_rad": 0.06,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.04, "hit_pop_scale": 0.20, "dust_enabled": true,
			"dust_radius": 3.8, "dust_color": Color(0.90, 0.48, 0.28, 0.42),
		},
	},
	20: {
		"tex": TEX_KULOU_DIZHU_STILL,
		"motion": StillMotion.SCUTTLE_STOMP,
		"native_facing": -1.0,
		"size": SIZE_MINION_BASE,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.035,
		"skew_freq": 10.0,
		"aura_col": Color(0.0, 0.0, 0.0, 0.0),
		"elite_col": Color(0.72, 0.40, 0.90, 0.36),
		"rig": {
			"gait_mode": "quadruped", "run_frames": 1, "idle_frames": 1, "run_fps": 12.0,
			"bob_amp": 2.4, "idle_breath_amp": 0.02, "waddle_rad": 0.05, "tilt_max_rad": 0.07,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.055, "hit_pop_scale": 0.22, "dust_enabled": true,
			"dust_radius": 3.8, "dust_color": Color(0.68, 0.54, 0.80, 0.40),
		},
	},
	21: {
		"tex": TEX_LINGZHI_GUJING_STILL,
		"motion": StillMotion.JELLY_WOBBLE,
		"native_facing": -1.0,
		"size": SIZE_MINION_FAST,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.055,
		"skew_freq": 7.0,
		"aura_col": Color(0.0, 0.0, 0.0, 0.0),
		"elite_col": Color(0.96, 0.54, 0.68, 0.36),
		"rig": {
			"gait_mode": "biped", "run_frames": 1, "idle_frames": 1, "run_fps": 10.0,
			"bob_amp": 4.4, "idle_breath_amp": 0.03, "waddle_rad": 0.05, "tilt_max_rad": 0.07,
			"up_down_tilt_rad": 0.02, "squash_amp": 0.095, "hit_pop_scale": 0.28, "dust_enabled": true,
			"dust_radius": 3.2, "dust_color": Color(0.95, 0.78, 0.82, 0.40),
		},
	},
	22: {
		"tex": TEX_TONGKE_XIEJIANG_STILL,
		"motion": StillMotion.SCUTTLE_STOMP,
		"native_facing": 1.0,
		"size": SIZE_MINION_TANK,
		"hover_y": 0.0,
		"hover_amp": 0.0,
		"hover_freq": 0.0,
		"skew_amp": 0.02,
		"skew_freq": 7.5,
		"aura_col": Color(0.0, 0.0, 0.0, 0.0),
		"elite_col": Color(0.90, 0.74, 0.32, 0.36),
		"rig": {
			"gait_mode": "quadruped", "run_frames": 1, "idle_frames": 1, "run_fps": 9.0,
			"bob_amp": 1.8, "idle_breath_amp": 0.015, "waddle_rad": 0.04, "tilt_max_rad": 0.05,
			"up_down_tilt_rad": 0.015, "squash_amp": 0.04, "hit_pop_scale": 0.16, "dust_enabled": true,
			"dust_radius": 5.2, "dust_color": Color(0.86, 0.74, 0.42, 0.45),
		},
	},
}

static func get_target_draw_size(e_type: int, sp: int, is_mini: bool, is_humanoid_boss: bool = false) -> float:
	if e_type == 0:
		if STILL_SPECIES.has(sp):
			return float((STILL_SPECIES[sp] as Dictionary).get("size", SIZE_MINION_BASE))
		match sp:
			0, 1, 5:
				return SIZE_MINION_FAST
			4, 9:
				return SIZE_MINION_TANK
			_:
				return SIZE_MINION_BASE
	if e_type == 1:
		return SIZE_MINI_BOSS if is_mini else SIZE_ELITE
	return SIZE_HUMANOID_BOSS if is_humanoid_boss else SIZE_BEAST_BOSS

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
var _still_sprite: Sprite2D = null
var _still_fx_overlay: Node2D = null
var _still_mat: ShaderMaterial = null

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
	_sync_still_nodes_visibility()

func _is_still_active() -> bool:
	return enemy_type <= 1 and STILL_SPECIES.has(species)

func _ensure_still_nodes() -> void:
	if _still_sprite == null:
		_still_sprite = Sprite2D.new()
		_still_sprite.name = "StillSprite"
		_still_sprite.centered = false
		_still_sprite.offset = Vector2(-128.0, -245.0)
		_still_mat = ShaderMaterial.new()
		_still_mat.shader = SHADER_STILL_MOTION
		_still_sprite.material = _still_mat
		add_child(_still_sprite)
	if _still_fx_overlay == null:
		_still_fx_overlay = Node2D.new()
		_still_fx_overlay.name = "StillFxOverlay"
		_still_fx_overlay.draw.connect(_on_still_fx_overlay_draw)
		add_child(_still_fx_overlay)

func _sync_still_nodes_visibility() -> void:
	var active := _is_still_active()
	if active:
		_ensure_still_nodes()
		var cfg: Dictionary = STILL_SPECIES[species]
		_still_sprite.texture = cfg.get("tex") as Texture2D
		_still_sprite.visible = true
		_still_fx_overlay.visible = true
		if _still_mat != null:
			_still_mat.set_shader_parameter("motion_mode", int(cfg.get("motion", 0)))
			_still_mat.set_shader_parameter("amp_scale", 1.0)
	else:
		if _still_sprite != null:
			_still_sprite.visible = false
		if _still_fx_overlay != null:
			_still_fx_overlay.visible = false

func _on_still_fx_overlay_draw() -> void:
	if not _is_still_active() or _still_fx_overlay == null or rig == null:
		return
	var mini_boss := _parent_body != null and "is_mini_boss" in _parent_body and bool(_parent_body.get("is_mini_boss"))
	var draw_sz := get_target_draw_size(enemy_type, species, mini_boss, false)
	_draw_status_overlays(_still_fx_overlay, draw_sz)

func _rebuild_rig() -> void:
	if enemy_type <= 1 and STILL_SPECIES.has(species):
		var cfg_rig: Dictionary = ((STILL_SPECIES[species] as Dictionary).get("rig", {}) as Dictionary).duplicate()
		if enemy_type == 1:
			cfg_rig["hit_pop_scale"] = 0.18
			cfg_rig["lunge_dist"] = 12.0
			cfg_rig["dust_radius"] = 6.0
		rig = CharacterRig.new(cfg_rig)
		return
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
	_sync_still_nodes_visibility()
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
	var frozen_now: bool = _parent_body != null and "_freeze_timer" in _parent_body and float(_parent_body.get("_freeze_timer")) > 0.0
	if not frozen_now:
		rig.update(delta, vel, max_spd, dashing)
		_update_charge_squash()
	if _is_still_active():
		_update_still_sprite(frozen_now)
	queue_redraw()

func _update_still_sprite(frozen_now: bool) -> void:
	_sync_still_nodes_visibility()
	if _still_sprite == null or rig == null:
		return
	var cfg: Dictionary = STILL_SPECIES[species]
	var pose := rig.get_pose()
	var t := rig.anim_time
	var off: Vector2 = pose["offset"]
	var sc: Vector2 = pose["scale"]
	var rot: float = float(pose["rotation"])
	var tint: Color = pose["dir_tint"]
	var mini_boss := _parent_body != null and "is_mini_boss" in _parent_body and bool(_parent_body.get("is_mini_boss"))
	var draw_sz := get_target_draw_size(enemy_type, species, mini_boss, false)

	sc = Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y)
	if _is_charge_windup:
		tint = Color(1.25, 0.88, 0.80, 1.0)
	if frozen_now:
		tint *= Color(0.72, 0.94, 1.12, 1.0)
	if enemy_type == 0:
		if tier_variant == 2:
			sc *= 1.08
			tint *= Color(0.94, 1.04, 1.12, 1.0)
		elif tier_variant >= 3:
			sc *= 1.14
			tint *= Color(1.14, 0.90, 0.86, 1.0)

	var native_facing := float(cfg.get("native_facing", 1.0))
	var base_y := 22.0 if enemy_type == 1 else 18.0
	var hover_y := float(cfg.get("hover_y", 0.0))
	var hover_amp := float(cfg.get("hover_amp", 0.0))
	var hover_freq := float(cfg.get("hover_freq", 0.0))
	if hover_amp > 0.0 and hover_freq > 0.0:
		hover_y += sin(t * hover_freq) * hover_amp

	var fit := draw_sz / 256.0
	_still_sprite.position = Vector2(roundf(off.x), roundf(base_y + hover_y + off.y))
	_still_sprite.rotation = rot
	_still_sprite.scale = Vector2(sc.x * native_facing * fit, sc.y * fit)
	var skew_amp := float(cfg.get("skew_amp", 0.0))
	var skew_freq := float(cfg.get("skew_freq", 0.0))
	_still_sprite.skew = sin(t * skew_freq) * skew_amp * lerpf(0.45, 1.15, clampf(rig.speed_ratio, 0.0, 1.2)) if (skew_amp > 0.0 and skew_freq > 0.0) else 0.0
	_still_sprite.modulate = tint

	if _still_mat != null:
		_still_mat.set_shader_parameter("anim_time", t)
		_still_mat.set_shader_parameter("move_speed", rig.speed_ratio)
	if _still_fx_overlay != null:
		_still_fx_overlay.queue_redraw()

func _draw() -> void:
	if rig == null:
		return
	var mini_boss := false
	if _parent_body != null and "is_mini_boss" in _parent_body:
		mini_boss = bool(_parent_body.get("is_mini_boss"))
	var is_humanoid := false
	if _parent_body != null and "is_humanoid_boss" in _parent_body:
		is_humanoid = bool(_parent_body.get("is_humanoid_boss"))
	var draw_sz: float = get_target_draw_size(enemy_type, species, mini_boss, is_humanoid)
	var frozen_now: bool = _parent_body != null and "_freeze_timer" in _parent_body and float(_parent_body.get("_freeze_timer")) > 0.0

	if mini_boss and _parent_body != null:
		var mb_total := float(_parent_body.get("max_health"))
		var mb_now := float(_parent_body.get("current_health"))
		if mb_total > 0.0:
			var bar_w := 76.0
			var bar_ratio := clampf(mb_now / mb_total, 0.0, 1.0)
			draw_rect(Rect2(-bar_w * 0.5, -92.0, bar_w, 8.0), Color(0.05, 0.09, 0.07, 0.86))
			draw_rect(Rect2(-bar_w * 0.5 + 1.0, -91.0, (bar_w - 2.0) * bar_ratio, 6.0), Color(0.88, 0.28, 0.20, 1.0))
			draw_rect(Rect2(-bar_w * 0.5, -92.0, bar_w, 8.0), Color(0.92, 0.76, 0.34, 0.9), false, 1.0)
			_draw_qi_shield_bar(0.0, -92.0, bar_w)
	elif enemy_type == 1:
		_draw_qi_shield_bar(0.0, -68.0, 52.0)
	elif enemy_type == 2:
		_draw_qi_shield_bar(0.0, -90.0 if is_humanoid else -112.0, 104.0)
	var pose := rig.get_pose()
	var t := rig.anim_time
	var off: Vector2 = pose["offset"]
	var sc: Vector2 = pose["scale"]
	var rot: float = float(pose["rotation"])
	var tint: Color = pose["dir_tint"]
	var idx: int = int(pose["frame_idx"])
	var sh_sc: float = float(pose["shadow_scale"])
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
	if frozen_now:
		tint *= Color(0.72, 0.94, 1.12, 1.0)

	if enemy_type == 0:
		if STILL_SPECIES.has(species):
			var cfg: Dictionary = STILL_SPECIES[species]
			var is_air := float(cfg.get("hover_y", 0.0)) < 0.0
			_draw_shadow((13.5 if is_air else 16.0) * sh_sc, 18.0)
			if tier_variant >= 3:
				_draw_kenney_aura(Vector2(0.0, 17.0), 26.0, Color(0.96, 0.36, 0.30, 0.42), false)
			var aura_c: Color = cfg.get("aura_col", Color(0.0, 0.0, 0.0, 0.0))
			if aura_c.a > 0.0:
				_draw_kenney_aura(Vector2(0.0, 18.0), 25.0, Color(aura_c.r, aura_c.g, aura_c.b, aura_c.a + 0.08 * sin(t * 5.2)), false)
			rig.draw_dust(self, Vector2(0.0, 17.0))
			return
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
		var m_rect := Rect2(-draw_sz * 0.5, -draw_sz * 0.88, draw_sz, draw_sz)
		match species:
			1:
				var float_y := roundf(sin(t * 4.5) * 4.0)
				var aura_a := 0.32 + 0.12 * sin(t * 5.2)
				draw_texture_rect(V2VfxFactory.TEX_FLARE_01, Rect2(-26.0, float_y - 30.0, 52.0, 52.0), false, Color(0.24, 0.88, 0.78, aura_a))
				if TEX_DOLL_SHEET != null:
					var doll_idx := int(floor(t * 8.0)) % DOLL_FRAMES
					var src := Rect2(float(doll_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(14.0 + float_y + off.y * 0.4)), rot, sc)
					draw_texture_rect_region(TEX_DOLL_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			2:
				if TEX_SHANXIAO_SHEET != null:
					var sx_idx := idx % SHANXIAO_FRAMES
					var src := Rect2(float(sx_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_SHANXIAO_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			3:
				if TEX_JIANGSHI_SHEET != null:
					var js_idx := idx % RUN_FRAMES
					var src := Rect2(float(js_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_JIANGSHI_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			4:
				if TEX_JINCHAN_SHEET != null:
					var jc_idx := idx % RUN_FRAMES
					var src := Rect2(float(jc_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_JINCHAN_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			5:
				if TEX_SHENJING_SHEET != null:
					var sj_idx := idx % RUN_FRAMES
					var src := Rect2(float(sj_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_SHENJING_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			6:
				_draw_kenney_aura(Vector2(0.0, 18.0), 28.0, Color(0.98, 0.48, 0.22, 0.34 + 0.12 * sin(t * 5.2)), false)
				if TEX_HUODOU_SHEET != null:
					var hd_idx := idx % RUN_FRAMES
					var src := Rect2(float(hd_idx) * 96.0, 0.0, 96.0, 96.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_HUODOU_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			7:
				if TEX_ZHUSHA_ZIREN_SHEET != null:
					var zz_idx := idx % RUN_FRAMES
					var src := Rect2(float(zz_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_ZHUSHA_ZIREN_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			8:
				_draw_kenney_aura(Vector2(0.0, 18.0), 24.0, Color(1.0, 0.56, 0.22, 0.30 + 0.10 * sin(t * 6.0)), false)
				if TEX_CHIHUO_DANLING_SHEET != null:
					var cd_idx := idx % RUN_FRAMES
					var src := Rect2(float(cd_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_CHIHUO_DANLING_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			9:
				if TEX_WUDU_ZHANGCHAN_SHEET != null:
					var wz_idx := idx % RUN_FRAMES
					var src := Rect2(float(wz_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_WUDU_ZHANGCHAN_SHEET, m_rect, src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			10:
				if TEX_CANJIAN_JIANKUI_SHEET != null:
					var cj_idx := idx % RUN_FRAMES
					var src := Rect2(float(cj_idx) * 128.0, 0.0, 128.0, 128.0)
					draw_set_transform(Vector2(roundf(off.x), roundf(18.0 + off.y)), rot, sc)
					draw_texture_rect_region(TEX_CANJIAN_JIANKUI_SHEET, m_rect, src, tint)
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
					draw_texture_rect_region(TEX_FOX_SHEET, Rect2(-draw_sz * 0.5, -draw_sz * 0.82, draw_sz, draw_sz), src, tint)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif enemy_type == 1:
		_draw_shadow(28.0 * sh_sc, 22.0)
		rig.draw_dust(self, Vector2(0.0, 21.0))
		var aura_a := 0.30 + 0.12 * sin(t * 5.0)
		if STILL_SPECIES.has(species):
			var cfg_el: Dictionary = STILL_SPECIES[species]
			var el_c: Color = cfg_el.get("elite_col", Color(0.96, 0.62, 0.22, 0.36))
			draw_set_transform(Vector2(0.0, 22.0), 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(el_c.r, el_c.g, el_c.b, aura_a), 3.0)
			draw_arc(Vector2.ZERO, 40.0 + sin(t * 4.0) * 1.5, 0.0, TAU, 24, Color(1.0, 0.86, 0.34, aura_a * 0.65), 1.6)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var elite_col := Color(0.98, 0.48, 0.22, aura_a)
		var elite_tex: Texture2D = TEX_ELITE_FOX
		var elite_sheet: Texture2D = TEX_ELITE_FOX_SHEET
		var elite_frames := FOX_FRAMES
		var draw_rect := Rect2(-draw_sz * 0.5, -draw_sz * 0.88, draw_sz, draw_sz)
		var extra_y := 0.0
		var elite_frame_px := 128.0
		match species:
			0:
				elite_col = Color(0.96, 0.44, 0.24, aura_a)
				elite_tex = TEX_ELITE_FOX
				elite_sheet = TEX_ELITE_FOX_SHEET
				elite_frames = FOX_FRAMES
			1:
				elite_col = Color(0.22, 0.88, 0.78, aura_a)
				elite_tex = TEX_ELITE_DOLL
				elite_sheet = TEX_ELITE_DOLL_SHEET
				elite_frames = DOLL_FRAMES
			2:
				elite_col = Color(0.96, 0.62, 0.22, aura_a)
				elite_tex = TEX_ELITE_SHANXIAO
				elite_sheet = TEX_ELITE_SHANXIAO_SHEET
				elite_frames = RUN_FRAMES
			3:
				elite_col = Color(0.84, 0.76, 0.30, aura_a)
				elite_tex = TEX_ELITE_JIANGSHI
				elite_sheet = TEX_ELITE_JIANGSHI_SHEET
				elite_frames = RUN_FRAMES
			4:
				elite_col = Color(0.45, 0.94, 0.56, aura_a)
				elite_tex = TEX_ELITE_JINCHAN
				elite_sheet = TEX_ELITE_JINCHAN_SHEET
				elite_frames = RUN_FRAMES
			5:
				elite_col = Color(0.48, 0.96, 0.56, aura_a)
				elite_tex = TEX_ELITE_SHENJING
				elite_sheet = TEX_ELITE_SHENJING_SHEET
				elite_frames = RUN_FRAMES
			6:
				elite_col = Color(1.0, 0.42, 0.16, aura_a)
				elite_tex = TEX_ELITE_HUODOU
				elite_sheet = TEX_ELITE_HUODOU_SHEET
				elite_frames = RUN_FRAMES
			11:
				elite_col = Color(0.31, 0.90, 0.76, aura_a)
				elite_tex = TEX_ELITE_YINSHA
				elite_sheet = TEX_ELITE_YINSHA_SHEET
				elite_frames = RUN_FRAMES
				elite_frame_px = 160.0
			12:
				elite_col = Color(0.88, 0.74, 0.34, aura_a)
				elite_tex = TEX_ELITE_SHIDUN
				elite_sheet = TEX_ELITE_SHIDUN_SHEET
				elite_frames = RUN_FRAMES
				elite_frame_px = 160.0
			_:
				elite_col = Color(0.96, 0.44, 0.24, aura_a)
				elite_tex = TEX_ELITE_FOX
				elite_sheet = TEX_ELITE_FOX_SHEET
				elite_frames = FOX_FRAMES
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
			draw_texture_rect_region(TEX_ELITE_SHEET, draw_rect, src, tint)
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
		if frozen_now:
			boss_tint *= Color(0.72, 0.94, 1.12, 1.0)

		var anim_state := "chase"
		if _parent_body != null and _parent_body.has_method("get_boss_anim_state"):
			anim_state = _parent_body.get_boss_anim_state()

		var b_rect := Rect2(-draw_sz * 0.5, -draw_sz * 0.89, draw_sz, draw_sz)
		if species == 1 and TEX_DOLL_SHEET != null:
			var fy := 0.0 if anim_state == "windup" else sin(t * 4.5) * 6.0
			var use_sc := Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y) if anim_state == "windup" and _is_charge_windup else (Vector2(sc.x * 1.08, sc.y * 0.88) if anim_state == "windup" else sc)
			var doll_idx := 0 if anim_state == "windup" else int(floor(t * 8.0)) % DOLL_FRAMES
			var src := Rect2(float(doll_idx) * 96.0, 0.0, 96.0, 96.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), rot, use_sc)
			draw_texture_rect_region(TEX_DOLL_SHEET, Rect2(b_rect.position.x, b_rect.position.y + fy, draw_sz, draw_sz), src, boss_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif species == 2 and TEX_ELITE_SHEET != null:
			var use_sc := Vector2(sc.x * last_charge_squash.x, sc.y * last_charge_squash.y) if (anim_state == "windup" and _is_charge_windup) or anim_state == "pounce" else (Vector2(sc.x * 1.08, sc.y * 0.88) if anim_state == "windup" else sc)
			var r_idx := 2 if anim_state == "windup" else idx % RUN_FRAMES
			var src := Rect2(float(r_idx) * 128.0, 0.0, 128.0, 128.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), rot, use_sc)
			draw_texture_rect_region(TEX_ELITE_SHEET, b_rect, src, boss_tint)
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
				draw_texture_rect_region(boss_sheet, b_rect, src, boss_tint)
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
					if frozen_now:
						boss_tint *= Color(0.72, 0.94, 1.12, 1.0)
			draw_set_transform(Vector2(roundf(off.x), roundf(36.0 + off.y)), use_rot, use_sc)
			var src := Rect2(float(col) * WOLF_BOSS_SIZE, 0.0, WOLF_BOSS_SIZE, WOLF_BOSS_SIZE)
			draw_texture_rect_region(TEX_WOLF_SHEET, b_rect, src, boss_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not _is_still_active():
		_draw_status_overlays(self, draw_sz)

func _draw_status_overlays(canvas: CanvasItem, draw_sz: float) -> void:
	if rig == null:
		return
	var t := rig.anim_time
	if _parent_body != null and not _parent_body.is_dead and _parent_body.has_method("is_burning") and _parent_body.is_burning():
		var burn_sc := 1.85 if enemy_type == 2 else (1.30 if enemy_type == 1 else 1.0)
		var base_y := 18.0 if enemy_type == 2 else (10.0 if enemy_type == 1 else 6.0)
		for bi in range(3):
			var bx := (float(bi) - 1.0) * 10.0 * burn_sc + sin(t * 14.0 + float(bi) * 2.1) * 2.2
			var fh := (24.0 + 6.0 * sin(t * 18.0 + float(bi) * 1.7)) * burn_sc
			var fw := 18.0 * burn_sc
			var by := base_y - fh * 0.65 - absf(sin(t * 12.0 + float(bi))) * 4.0 * burn_sc
			var f_tex := V2VfxFactory.TEX_FLAME_01 if bi != 1 else V2VfxFactory.TEX_FLAME_05
			canvas.draw_texture_rect(f_tex, Rect2(bx - fw * 0.5, by - fh * 0.5, fw, fh), false, Color(1.0, 0.44 + 0.14 * float(bi % 2), 0.10, 0.72))
			canvas.draw_texture_rect(V2VfxFactory.TEX_FIRE_01, Rect2(bx - fw * 0.32, by - fh * 0.25, fw * 0.64, fh * 0.64), false, Color(1.0, 0.92, 0.58, 0.66))

	if not _active_elem.is_empty():
		var ec := _elem_color(_active_elem)
		var pip_y := -66.0 if enemy_type == 2 else (-44.0 if enemy_type == 1 else -34.0)
		var pip_pos := Vector2(0.0, pip_y)
		canvas.draw_circle(pip_pos, 8.0, Color(0.05, 0.08, 0.09, 0.88))
		canvas.draw_arc(pip_pos, 8.0, 0.0, TAU, 16, Color(ec.r, ec.g, ec.b, 0.90), 1.4)
		var glyph := V2VfxFactory.elem_glyph_texture(_active_elem)
		if glyph != null:
			canvas.draw_texture_rect(glyph, Rect2(pip_pos - Vector2(6.5, 6.5), Vector2(13.0, 13.0)), false, ec)
		else:
			canvas.draw_circle(pip_pos, 4.2, ec)

	_draw_element_status_badges(canvas, draw_sz)

func _draw_element_status_badges(canvas: CanvasItem, draw_sz: float) -> void:
	if _parent_body == null or bool(_parent_body.get("is_dead")):
		return
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var half_h: float = draw_sz * 0.45
	var half_w: float = draw_sz * 0.32

	# 1) 潮湿（5 秒水印记）：脚底淡蓝水波 + 两侧飘浮 2 颗晶莹水滴
	if _active_elem == "water":
		canvas.draw_set_transform(Vector2(0.0, half_h * 0.35), 0.0, Vector2(1.0, 0.36))
		canvas.draw_arc(Vector2.ZERO, half_w * 1.05, 0.0, TAU, 18, Color(0.26, 0.84, 0.98, 0.45), 1.8)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in range(2):
			var side: float = -1.0 if i == 0 else 1.0
			var drop_y: float = -half_h * 0.45 + fmod(t * 26.0 + float(i) * 14.0, 26.0)
			var drop_p := Vector2(side * (half_w * 0.95), drop_y)
			canvas.draw_colored_polygon(PackedVector2Array([
				drop_p + Vector2(0.0, -5.0),
				drop_p + Vector2(3.5, 1.5),
				drop_p + Vector2(0.0, 4.5),
				drop_p + Vector2(-3.5, 1.5),
			]), Color(0.45, 0.92, 1.0, 0.88))

	# 2) 火印记：怪身斜上方冒 2 粒橘红小火星
	elif _active_elem == "fire":
		for i in range(2):
			var phase: float = fmod(t * 2.2 + float(i) * 0.5, 1.0)
			var p := Vector2((-8.0 if i == 0 else 9.0) + sin(t * 8.0 + float(i)) * 3.0, -half_h * 0.25 - phase * 22.0)
			canvas.draw_circle(p, lerpf(3.2, 1.2, phase), Color(1.0, 0.56, 0.16, (1.0 - phase) * 0.92))

	# 3) 雷印记 / 麻痹抽搐：身上闪细碎紫白电丝
	var stunned: bool = "_stun_timer" in _parent_body and float(_parent_body.get("_stun_timer")) > 0.0
	if _active_elem == "thunder" or stunned:
		var zig_seed: int = int(t * 14.0) + _parent_body.get_instance_id()
		var sx: float = -half_w * 0.7 if (zig_seed % 2 == 0) else half_w * 0.3
		var p0 := Vector2(sx, -half_h * 0.65)
		var p1 := p0 + Vector2(8.0, 10.0)
		var p2 := p1 + Vector2(-7.0, 9.0)
		var p3 := p2 + Vector2(9.0, 11.0)
		canvas.draw_polyline(PackedVector2Array([p0, p1, p2, p3]), Color(0.76, 0.68, 1.0, 0.92), 2.0)

	# 4) 熔金（4 秒唯一易伤）：橙金熔甲光环
	if "damage_taken_mult" in _parent_body and float(_parent_body.get("damage_taken_mult")) > 1.05:
		var pulse: float = 0.55 + 0.35 * sin(t * 10.0)
		canvas.draw_arc(Vector2(0.0, -half_h * 0.25), half_w * 1.15, 0.0, TAU, 20, Color(1.0, 0.62, 0.20, pulse * 0.65), 2.2)

	# 5) 焚煞印记（待尸爆）：胸口暗红脉动火核
	if "_detonate_mark_timer" in _parent_body and float(_parent_body.get("_detonate_mark_timer")) > 0.0:
		var pulse_r: float = 5.5 + 2.5 * sin(t * 14.0)
		canvas.draw_circle(Vector2(0.0, -half_h * 0.3), pulse_r, Color(0.98, 0.28, 0.10, 0.72))
		canvas.draw_circle(Vector2(0.0, -half_h * 0.3), pulse_r * 0.45, Color(1.0, 0.88, 0.45, 0.92))

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

func _draw_qi_shield_bar(center_x: float, hp_bar_top_y: float, bar_w: float) -> void:
	if _parent_body == null or not ("max_shield" in _parent_body):
		return
	var max_s: float = float(_parent_body.get("max_shield"))
	var cur_s: float = float(_parent_body.get("current_shield"))
	if max_s <= 0.0 or cur_s <= 0.0:
		return
	var ratio: float = clampf(cur_s / max_s, 0.0, 1.0)
	var sh_h: float = 5.0 if enemy_type == 2 else 4.0
	var rect_bg := Rect2(center_x - bar_w * 0.5, hp_bar_top_y - sh_h - 2.0, bar_w, sh_h)
	draw_rect(rect_bg.grow(1.0), Color(0.06, 0.12, 0.14, 0.92), true)
	draw_rect(rect_bg, Color(0.22, 0.28, 0.30, 0.85), true)
	draw_rect(Rect2(rect_bg.position, Vector2(bar_w * ratio, sh_h)), Color(0.95, 0.98, 1.0, 0.98), true)

func _draw_shadow(radius: float, y_offset: float) -> void:
	draw_set_transform(Vector2(0.0, y_offset), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, radius, Color(0.08, 0.18, 0.14, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_kenney_aura(center: Vector2, radius: float, col: Color, is_magic: bool) -> void:
	var tex := V2VfxFactory.TEX_MAGIC_02 if is_magic else V2VfxFactory.TEX_CIRCLE_03
	draw_set_transform(center, 0.0, Vector2(1.0, 0.45))
	draw_texture_rect(tex, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
