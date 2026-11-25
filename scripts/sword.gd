extends Area2D
class_name Sword

const TEX_SWORD: Texture2D = preload("res://assets/sprites/fx_flying_sword.png")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 640.0
var damage: float = 35.0
var lifetime: float = 3.2
var pierce_count: int = 2
var ricochet_count: int = 0
var knockback: float = 65.0
var is_evolved: bool = false
var is_bullet: bool = false
var blast_radius: float = 0.0

var hit_ids: Dictionary = {}
var _releasing: bool = false
var _trail: Array[Vector2] = []

func setup(dir: Vector2, dmg: float, spd: float = 640.0, pierce: int = 2, ricochet: int = 0, evolved: bool = false, kb: float = 65.0) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	pierce_count = pierce
	ricochet_count = ricochet
	is_evolved = evolved
	knockback = kb
	is_bullet = false
	blast_radius = 0.0
	rotation = direction.angle()
	_trail.clear()

func setup_bullet(dir: Vector2, dmg: float, spd: float, pierce: int, blast_rad: float, evolved: bool, kb: float) -> void:
	setup(dir, dmg, spd, pierce, 1 if evolved else 0, evolved, kb)
	is_bullet = true
	blast_radius = blast_rad
	lifetime = 1.8

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func pool_acquire() -> void:
	hit_ids.clear()
	_releasing = false
	lifetime = 3.2
	ricochet_count = 0
	is_evolved = false
	is_bullet = false
	blast_radius = 0.0
	visible = true
	modulate = Color.WHITE
	_trail.clear()

func _physics_process(delta: float) -> void:
	if _releasing:
		return
	global_position += direction * speed * delta
	_trail.append(global_position)
	if _trail.size() > 8:
		_trail.remove_at(0)
	# 检查青瓷灵罐
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= 26.0:
				jar.take_damage(damage)
	queue_redraw()
	lifetime -= delta
	if lifetime <= 0:
		_release()

func _release() -> void:
	if _releasing:
		return
	_releasing = true
	set_physics_process(false)
	set_process(false)
	visible = false
	call_deferred("_do_release")

func _do_release() -> void:
	ObjectPools.release(self)
	set_physics_process(true)

func _draw() -> void:
	if is_bullet:
		if _trail.size() >= 2:
			var b_col := Color(1.0, 0.42, 0.14, 0.62) if is_evolved else Color(1.0, 0.72, 0.24, 0.52)
			for i in range(_trail.size() - 1):
				var t := float(i + 1) / float(_trail.size())
				var p0 := to_local(_trail[i])
				var p1 := to_local(_trail[i + 1])
				draw_line(p0, p1, Color(b_col.r, b_col.g, b_col.b, t * b_col.a), 2.5 + t * (7.0 if is_evolved else 4.8))
		var core_len := 22.0 if is_evolved else 16.0
		draw_line(Vector2(-core_len, 0.0), Vector2(core_len * 0.6, 0.0), Color(1.0, 0.36, 0.12, 0.85), 9.0 if is_evolved else 6.5)
		draw_line(Vector2(-core_len * 0.7, 0.0), Vector2(core_len * 0.7, 0.0), Color(1.0, 0.94, 0.62, 0.98), 4.2 if is_evolved else 3.0)
		draw_circle(Vector2(core_len * 0.5, 0.0), 5.2 if is_evolved else 3.8, Color(1.0, 0.96, 0.78, 0.96))
		return

	if _trail.size() >= 2:
		var trail_col := Color(1.0, 0.84, 0.34, 0.50) if is_evolved else Color(0.24, 0.90, 0.78, 0.44)
		for i in range(_trail.size() - 1):
			var t := float(i + 1) / float(_trail.size())
			var p0 := to_local(_trail[i])
			var p1 := to_local(_trail[i + 1])
			draw_line(p0, p1, Color(trail_col.r, trail_col.g, trail_col.b, t * trail_col.a), 2.0 + t * (6.5 if is_evolved else 4.5))

	if TEX_SWORD != null:
		var sz := 54.0 if is_evolved else 44.0
		var tint := Color(1.0, 0.95, 0.68, 1.0) if is_evolved else Color.WHITE
		draw_texture_rect(TEX_SWORD, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, tint)
	else:
		draw_line(Vector2(-12, 0), Vector2(18, 0), Color(0.28, 0.92, 0.82, 0.98), 4.0)

func _on_area_entered(area: Area2D) -> void:
	if _releasing:
		return
	var enemy = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage") or enemy.is_dead:
		return
	var id = enemy.get_instance_id()
	if hit_ids.has(id):
		return
	hit_ids[id] = true
	enemy.take_damage(damage)
	if is_bullet:
		if blast_radius > 0.0:
			Sfx.play_varied("cannon_blast", -11.0)
			var nearby := CombatGrid.query(global_position, blast_radius)
			var splash_dmg := damage * (0.62 if is_evolved else 0.42)
			for other in nearby:
				if is_instance_valid(other) and other != enemy and not other.is_dead and other.has_method("take_damage"):
					if global_position.distance_to(other.global_position) <= blast_radius:
						other.take_damage(splash_dmg)
		else:
			Sfx.play_varied("sword_hit", -11.0)
	else:
		Sfx.play_varied("sword_hit", -11.0)
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction * knockback)
	if ricochet_count > 0:
		ricochet_count -= 1
		var next_target := _find_ricochet_target()
		if next_target != null:
			direction = (next_target.global_position - global_position).normalized()
			rotation = direction.angle()
			return
	pierce_count -= 1
	if pierce_count <= 0:
		_release()

func _find_ricochet_target() -> Node2D:
	var best: Node2D = null
	var best_d := 420.0
	var nearby := CombatGrid.query(global_position, best_d)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if not is_instance_valid(e) or e.is_dead:
			continue
		if hit_ids.has(e.get_instance_id()):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
