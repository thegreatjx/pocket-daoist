extends Node2D

const TEX_MINION: Texture2D = preload("res://assets/sprites/wolf_run_sheet_64.png")
const TEX_ELITE: Texture2D = preload("res://assets/sprites/wolf_elite_run_sheet_64.png")
const TEX_BOSS: Texture2D = preload("res://assets/sprites/wolf_boss_run_sheet_128.png")

const FRAME_COUNT: int = 4
const FPS_MINION: float = 10.0
const FPS_ELITE: float = 11.0
const FPS_BOSS: float = 8.0

var enemy_type: int = 0 # 0: MINION, 1: ELITE, 2: BOSS
var _anim_time: float = 0.0
var _parent_body: CharacterBody2D = null

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		_parent_body = get_parent() as CharacterBody2D

func set_type(type_val: int) -> void:
	enemy_type = type_val
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	# 水平移动时根据速度自动翻转朝向
	if _parent_body != null and not _parent_body.is_dead:
		if _parent_body.velocity.x < -2.0:
			scale.x = -1.0
		elif _parent_body.velocity.x > 2.0:
			scale.x = 1.0
	queue_redraw()

func _draw() -> void:
	if enemy_type == 0:
		# 普通狼妖：4 帧奔跑动画循环
		if TEX_MINION != null:
			var current_frame = int(_anim_time * FPS_MINION) % FRAME_COUNT
			var src_rect = Rect2(current_frame * 64.0, 0.0, 64.0, 64.0)
			var dest_rect = Rect2(-24.0, -24.0, 48.0, 48.0)
			draw_texture_rect_region(TEX_MINION, dest_rect, src_rect)
		else:
			_draw_fallback(Color(0.85, 0.2, 0.25, 0.9), 1.0)
	elif enemy_type == 1:
		# 赤煞精英狼：4 帧骨刺幽冥奔跑动画循环
		if TEX_ELITE != null:
			var current_frame = int(_anim_time * FPS_ELITE) % FRAME_COUNT
			var src_rect = Rect2(current_frame * 64.0, 0.0, 64.0, 64.0)
			var dest_rect = Rect2(-36.0, -36.0, 72.0, 72.0)
			draw_texture_rect_region(TEX_ELITE, dest_rect, src_rect)
			# 幽冥煞火脚下微光
			var aura_a = 0.28 + 0.12 * sin(_anim_time * 6.0)
			draw_circle(Vector2(0, 16), 18.0, Color(0.1, 0.9, 0.9, aura_a))
		else:
			_draw_fallback(Color(0.95, 0.15, 0.2, 1.0), 1.5)
	elif enemy_type == 2:
		# 首领·啸月狼王：4 帧巨型震地冲锋动画循环
		if TEX_BOSS != null:
			var current_frame = int(_anim_time * FPS_BOSS) % FRAME_COUNT
			var src_rect = Rect2(current_frame * 128.0, 0.0, 128.0, 128.0)
			var dest_rect = Rect2(-64.0, -64.0, 128.0, 128.0)
			draw_texture_rect_region(TEX_BOSS, dest_rect, src_rect)
			# 双层狂暴魔煞光环
			var aura_a = 0.35 + 0.15 * sin(_anim_time * 4.0)
			draw_arc(Vector2(0, 24), 42.0, 0.0, TAU, 32, Color(1.0, 0.25, 0.1, aura_a), 3.5)
			draw_arc(Vector2(0, 24), 50.0, 0.0, TAU, 32, Color(0.2, 0.85, 1.0, aura_a * 0.8), 2.5)
		else:
			_draw_fallback(Color(0.4, 0.05, 0.05, 1.0), 2.5)

func _draw_fallback(c: Color, s: float) -> void:
	var body_pts = PackedVector2Array([
		Vector2(12 * s, 0),
		Vector2(2 * s, -8 * s),
		Vector2(-12 * s, -6 * s),
		Vector2(-10 * s, 6 * s),
		Vector2(2 * s, 8 * s)
	])
	draw_colored_polygon(body_pts, c)
	draw_circle(Vector2(6 * s, -3 * s), 2.5 * s, Color(1.0, 0.9, 0.2, 1.0))
	draw_circle(Vector2(6 * s, 3 * s), 2.5 * s, Color(1.0, 0.9, 0.2, 1.0))
	draw_polyline(body_pts, Color(0.3, 0.05, 0.05, 0.8), 2.0 * s)
