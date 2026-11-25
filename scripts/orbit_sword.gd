extends Area2D
class_name OrbitSword

const TEX_SWORD: Texture2D = preload("res://assets/sprites/fx_flying_sword.png")

var damage: float = 24.0
var hit_cooldown: Dictionary = {}
var knockback: float = 110.0
var is_evolved: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func pool_acquire() -> void:
	hit_cooldown.clear()
	is_evolved = false
	visible = true

func _physics_process(delta: float) -> void:
	var keys = hit_cooldown.keys()
	for k in keys:
		hit_cooldown[k] -= delta
		if hit_cooldown[k] <= 0:
			hit_cooldown.erase(k)
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= 28.0:
				jar.take_damage(damage)

func _draw() -> void:
	var glow_col := Color(0.98, 0.84, 0.36, 0.36) if is_evolved else Color(0.32, 0.92, 0.80, 0.30)
	draw_line(Vector2(-28, 0), Vector2(14, 0), glow_col, 8.0 if is_evolved else 6.0)
	draw_circle(Vector2.ZERO, 12.0 if is_evolved else 9.0, glow_col)
	if TEX_SWORD != null:
		var sz := 52.0 if is_evolved else 40.0
		var tint := Color(1.0, 0.94, 0.56, 1.0) if is_evolved else Color(1.0, 0.98, 0.84, 1.0)
		draw_texture_rect(TEX_SWORD, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, tint)

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage") or enemy.is_dead:
		return
	var id = enemy.get_instance_id()
	if hit_cooldown.has(id):
		return
	hit_cooldown[id] = 0.34 if is_evolved else 0.44
	enemy.take_damage(damage)
	Sfx.play_varied("sword_hit", -15.0)
	if enemy.has_method("apply_knockback"):
		var away = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(away * knockback)
