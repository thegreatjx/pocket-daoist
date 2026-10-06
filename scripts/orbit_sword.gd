extends Area2D
class_name OrbitSword

var damage: float = 20.0
var hit_cooldown: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# 刷新击中冷却
	var keys = hit_cooldown.keys()
	for k in keys:
		hit_cooldown[k] -= delta
		if hit_cooldown[k] <= 0:
			hit_cooldown.erase(k)

func _draw() -> void:
	# 环绕纯阳太极小飞剑
	var points = PackedVector2Array([
		Vector2(14, 0),
		Vector2(0, -3),
		Vector2(-10, -2),
		Vector2(-12, 0),
		Vector2(-10, 2),
		Vector2(0, 3)
	])
	draw_colored_polygon(points, Color(0.95, 0.8, 0.25, 0.95))
	draw_line(Vector2(-10, 0), Vector2(12, 0), Color(1.0, 1.0, 0.8, 1.0), 1.2)
	# 旋转剑芒流光
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.2, 0.3))

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy and enemy.has_method("take_damage") and not enemy.is_dead:
		var id = enemy.get_instance_id()
		if not hit_cooldown.has(id):
			enemy.take_damage(damage)
			hit_cooldown[id] = 0.45
