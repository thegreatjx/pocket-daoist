extends Area2D
class_name Sword

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 35.0
var lifetime: float = 3.5
var pierce_count: int = 2

# 已命中的敌人，防止同一敌人被重复计伤/重复扣穿透
var hit_ids: Dictionary = {}

func setup(dir: Vector2, dmg: float, spd: float = 600.0, pierce: int = 2) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	pierce_count = pierce
	rotation = direction.angle()

func _ready() -> void:
	# 只监听 Area（敌人 HurtBox），避免同时命中敌人身体导致双重伤害
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	# 绘制青玉飞剑形态
	var points = PackedVector2Array([
		Vector2(18, 0),
		Vector2(4, -4),
		Vector2(-12, -3),
		Vector2(-16, -6),
		Vector2(-16, 6),
		Vector2(-12, 3),
		Vector2(4, 4)
	])
	draw_colored_polygon(points, Color(0.3, 0.95, 0.85, 0.95))
	# 剑脊流光
	draw_line(Vector2(-14, 0), Vector2(16, 0), Color(1.0, 1.0, 1.0, 0.9), 1.5)
	# 剑尾剑气拖尾
	draw_line(Vector2(-16, 0), Vector2(-28, 0), Color(0.2, 0.8, 0.8, 0.3), 3.0)

func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	var enemy = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage") or enemy.is_dead:
		return
	var id = enemy.get_instance_id()
	if hit_ids.has(id):
		return
	hit_ids[id] = true
	enemy.take_damage(damage)
	pierce_count -= 1
	if pierce_count <= 0:
		queue_free()
