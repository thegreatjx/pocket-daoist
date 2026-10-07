extends Area2D
class_name OrbitSword

var damage: float = 20.0
var hit_cooldown: Dictionary = {}
var knockback: float = 90.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func pool_acquire() -> void:
	hit_cooldown.clear()
	visible = true

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
	if enemy == null or not enemy.has_method("take_damage") or enemy.is_dead:
		return
	var id = enemy.get_instance_id()
	if hit_cooldown.has(id):
		return
	hit_cooldown[id] = 0.45
	enemy.take_damage(damage)
	Sfx.play_varied("sword_hit", -16.0)
	if enemy.has_method("apply_knockback"):
		var away = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(away * knockback)
