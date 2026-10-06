extends Node2D
class_name ExpGem

var exp_value: float = 6.0
var target: Node2D = null
var fly_speed: float = 40.0
var is_attracted: bool = false
var lifetime: float = 45.0

func _physics_process(delta: float) -> void:
	# 超时自毁，防止屏幕外灵气珠无限堆积
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if target == null or not is_instance_valid(target):
		target = null
		is_attracted = false
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			if global_position.distance_to(p.global_position) <= p.magnet_radius:
				target = p
				is_attracted = true

	if is_attracted:
		var dir = (target.global_position - global_position).normalized()
		fly_speed += 750.0 * delta
		global_position += dir * fly_speed * delta

		if global_position.distance_to(target.global_position) <= 16.0:
			if target.has_method("gain_exp"):
				target.gain_exp(exp_value)
			queue_free()

func _draw() -> void:
	# 绘制天地灵气光斑（翠玉微芒）
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.9, 0.5, 0.4))
	draw_circle(Vector2.ZERO, 3.5, Color(0.6, 1.0, 0.8, 0.9))
	draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 1.0, 1.0))
