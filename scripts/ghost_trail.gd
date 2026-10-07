extends Node2D
class_name GhostTrail

var alpha: float = 0.65
var fade_speed: float = 3.5

func pool_acquire() -> void:
	alpha = 0.65
	visible = true
	queue_redraw()

func _draw() -> void:
	# 绘制水墨仙气青衣残影
	draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.8, 0.9, alpha * 0.4))
	draw_circle(Vector2.ZERO, 10.0, Color(0.8, 1.0, 1.0, alpha * 0.7))

func _process(delta: float) -> void:
	alpha -= delta * fade_speed
	queue_redraw()
	if alpha <= 0.0:
		ObjectPools.release(self)
