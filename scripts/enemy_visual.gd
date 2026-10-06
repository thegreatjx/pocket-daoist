extends Node2D

func _draw() -> void:
	# 绘制妖狼造型（暗红凶戾妖兽）
	var body_pts = PackedVector2Array([
		Vector2(12, 0),
		Vector2(2, -8),
		Vector2(-12, -6),
		Vector2(-10, 6),
		Vector2(2, 8)
	])
	draw_colored_polygon(body_pts, Color(0.85, 0.2, 0.25, 0.9))
	# 凶戾血目
	draw_circle(Vector2(6, -3), 2.5, Color(1.0, 0.9, 0.2, 1.0))
	draw_circle(Vector2(6, 3), 2.5, Color(1.0, 0.9, 0.2, 1.0))
	# 妖气黑雾轮廓
	draw_polyline(body_pts, Color(0.3, 0.05, 0.05, 0.8), 2.0)
