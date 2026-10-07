extends Node2D

const TEX_HERO: Texture2D = preload("res://assets/sprites/hero_cultivator_64.png")

var _anim_time: float = 0.0
var _parent_player: CharacterBody2D = null

func _ready() -> void:
	if get_parent() is CharacterBody2D:
		_parent_player = get_parent() as CharacterBody2D

func _process(delta: float) -> void:
	_anim_time += delta
	# 水平移动时根据速度方向翻转主角朝向
	if _parent_player != null and not _parent_player.is_dead:
		if _parent_player.velocity.x < -5.0:
			scale.x = -1.0
		elif _parent_player.velocity.x > 5.0:
			scale.x = 1.0
	queue_redraw()

func _draw() -> void:
	if TEX_HERO != null:
		# 御剑仙气脚底光环
		var aura_alpha = 0.22 + 0.08 * sin(_anim_time * 3.0)
		draw_circle(Vector2(0, 18), 16.0, Color(0.2, 0.75, 1.0, aura_alpha))
		# 御剑轻微浮空呼吸微动
		var hover_y = sin(_anim_time * 4.0) * 2.5
		var dest_rect = Rect2(-28.0, -28.0 + hover_y, 56.0, 56.0)
		draw_texture_rect(TEX_HERO, dest_rect, false)
	else:
		# 备用矢量光圈
		draw_circle(Vector2.ZERO, 20.0, Color(0.2, 0.7, 1.0, 0.25))
		draw_circle(Vector2.ZERO, 13.0, Color(0.15, 0.55, 0.85, 0.9))
		draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.95, 1.0, 1.0))
		draw_circle(Vector2(0, -9), 4.0, Color(0.1, 0.1, 0.15, 1.0))
