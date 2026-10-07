extends CharacterBody2D
class_name Enemy

enum Type {
	MINION,
	ELITE,
	BOSS
}

var enemy_type: Type = Type.MINION

@export var max_health: float = 35.0
var current_health: float = 35.0
@export var speed: float = 130.0
@export var contact_damage: float = 8.0

# 轻量分离：只查空间哈希邻域，成本线性；半径/力度可调
@export var separation_radius: float = 22.0
@export var separation_force: float = 90.0

var knockback_resistance: float = 0.0
var damage_reduction: float = 0.0
var exp_gem_count: int = 1
var can_despawn: bool = true
var is_boss: bool = false

var is_dead: bool = false
var target: Node2D = null

var _flash_tween: Tween = null
var _knockback: Vector2 = Vector2.ZERO
var _releasing: bool = false

@onready var visual_node: Node2D = get_node_or_null("Visual")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var hurt_col_shape: CollisionShape2D = get_node_or_null("HurtBox/CollisionShape2D")

func _ready() -> void:
	add_to_group("enemies")
	_reset_state()
	_pick_target()

func pool_acquire() -> void:
	_releasing = false
	_reset_state()
	set_physics_process(true)
	_pick_target()

func _reset_state() -> void:
	is_dead = false
	enemy_type = Type.MINION
	max_health = 35.0
	current_health = 35.0
	speed = 130.0
	contact_damage = 8.0
	knockback_resistance = 0.0
	damage_reduction = 0.0
	exp_gem_count = 1
	can_despawn = true
	is_boss = false
	separation_radius = 22.0
	separation_force = 90.0

	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	modulate = Color.WHITE
	visible = true
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if visual_node != null and visual_node.has_method("set_type"):
		visual_node.set_type(int(Type.MINION))
	_update_shapes(12.0, 14.0)

func setup_type(t: Type, elapsed_time: float) -> void:
	enemy_type = t
	match t:
		Type.MINION:
			# 普通小怪·狼妖：血量 35，配合玩家初始飞剑伤害 35，一击必杀
			max_health = 35.0 * (1.0 + elapsed_time / 180.0)
			speed = 130.0
			contact_damage = 8.0
			knockback_resistance = 0.0
			damage_reduction = 0.0
			exp_gem_count = 1
			can_despawn = true
			is_boss = false
			separation_radius = 22.0
			separation_force = 90.0
			_update_shapes(12.0, 14.0)
		Type.ELITE:
			# 赤煞精英狼：厚实血牛（1200），带 30% 免伤与 75% 击退抗性
			max_health = 1200.0 * (1.0 + elapsed_time / 300.0)
			speed = 145.0
			contact_damage = 22.0
			knockback_resistance = 0.75
			damage_reduction = 0.30
			exp_gem_count = 6
			can_despawn = false
			is_boss = false
			separation_radius = 35.0
			separation_force = 120.0
			_update_shapes(18.0, 22.0)
		Type.BOSS:
			# 首领·啸月狼王：史诗级血条（16000），45% 免伤，95% 霸体
			max_health = 16000.0
			speed = 115.0
			contact_damage = 45.0
			knockback_resistance = 0.95
			damage_reduction = 0.45
			exp_gem_count = 18
			can_despawn = false
			is_boss = true
			separation_radius = 55.0
			separation_force = 200.0
			_update_shapes(32.0, 36.0)

	current_health = max_health
	if visual_node != null and visual_node.has_method("set_type"):
		visual_node.set_type(int(t))

func _update_shapes(body_r: float, hit_r: float) -> void:
	if col_shape != null and col_shape.shape is CircleShape2D:
		(col_shape.shape as CircleShape2D).radius = body_r
	if hurt_col_shape != null and hurt_col_shape.shape is CircleShape2D:
		(hurt_col_shape.shape as CircleShape2D).radius = hit_r

func _pick_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if target == null or not is_instance_valid(target):
		_pick_target()
		if target == null:
			return

	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed

	# 空间哈希分离
	if separation_radius > 0.0 and separation_force > 0.0:
		var sep = Vector2.ZERO
		var r_sq = separation_radius * separation_radius
		for other in CombatGrid.query(global_position, separation_radius):
			if other == self or not is_instance_valid(other) or other.is_dead:
				continue
			var offset = global_position - other.global_position
			var d_sq = offset.length_squared()
			if d_sq < r_sq and d_sq > 0.0001:
				var d = sqrt(d_sq)
				sep += offset / d * (separation_radius - d) / separation_radius
		velocity += sep * separation_force

	# 击退冲量衰减
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback * maxf(0.0, 1.0 - 12.0 * delta)
	else:
		_knockback = Vector2.ZERO

	move_and_slide()

	# 触碰玩家伤害
	var touch_distance = 32.0 if not is_boss else 52.0
	if global_position.distance_to(target.global_position) <= touch_distance:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage * delta)

func apply_knockback(impulse: Vector2) -> void:
	if is_dead:
		return
	_knockback += impulse * (1.0 - knockback_resistance)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	var actual_damage = amount * (1.0 - damage_reduction)
	current_health -= actual_damage

	# 如果是 Boss，通知 UI 更新 Boss 血条
	if is_boss:
		get_tree().call_group("game_manager", "update_boss_hp", current_health, max_health)

	# 受击微光闪白
	if Settings.get_bool("video/hit_flash"):
		modulate = Color(2.0, 1.5, 1.5, 1.0)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	Sfx.play_varied("enemy_die", -6.0)

	# 掉落灵气妖丹
	for i in range(exp_gem_count):
		var gem = ObjectPools.acquire("res://scenes/exp_gem.tscn", get_parent())
		if gem != null:
			var offset = Vector2.ZERO
			if exp_gem_count > 1:
				var ang = randf() * TAU
				var dist = randf_range(8.0, 36.0)
				offset = Vector2(cos(ang), sin(ang)) * dist
			gem.global_position = global_position + offset

	get_tree().call_group("game_manager", "on_enemy_killed")

	if is_boss:
		get_tree().call_group("game_manager", "on_boss_killed")

	_release_to_pool()

func despawn() -> void:
	if is_dead or not can_despawn or is_boss:
		return
	is_dead = true
	_release_to_pool()

func _release_to_pool() -> void:
	if _releasing:
		return
	_releasing = true
	visible = false
	set_physics_process(false)
	call_deferred("_do_release")

func _do_release() -> void:
	ObjectPools.release(self)
