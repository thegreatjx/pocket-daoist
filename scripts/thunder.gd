extends Node2D
class_name Thunder

var damage: float = 60.0
var radius: float = 65.0
var timer: float = 0.35
var damaged: bool = false

func _physics_process(delta: float) -> void:
	if not damaged:
		damaged = true
		_deal_aoe_damage()
	timer -= delta
	queue_redraw()
	if timer <= 0:
		queue_free()

func _deal_aoe_damage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			if global_position.distance_to(e.global_position) <= radius:
				e.take_damage(damage)

func _draw() -> void:
	# 绘制天降雷霆贯穿闪电与地面电芒
	var a = timer / 0.35
	# 地面雷池电弧
	draw_circle(Vector2.ZERO, radius * (1.2 - a * 0.2), Color(0.4, 0.6, 1.0, a * 0.4))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(0.7, 0.85, 1.0, a * 0.6))
	# 贯穿天际的雷光之柱
	draw_line(Vector2(0, -600), Vector2(0, 0), Color(0.9, 0.95, 1.0, a * 0.95), 8.0)
	draw_line(Vector2(-6, -600), Vector2(4, 0), Color(0.3, 0.6, 1.0, a * 0.5), 16.0)
