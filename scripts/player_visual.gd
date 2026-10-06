extends Node2D

func _draw() -> void:
	# 外层仙气护体光环
	draw_circle(Vector2.ZERO, 20.0, Color(0.2, 0.7, 1.0, 0.25))
	# 道袍内胆
	draw_circle(Vector2.ZERO, 13.0, Color(0.15, 0.55, 0.85, 0.9))
	# 核心灵韵
	draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.95, 1.0, 1.0))
	# 头部发髻微点
	draw_circle(Vector2(0, -9), 4.0, Color(0.1, 0.1, 0.15, 1.0))
