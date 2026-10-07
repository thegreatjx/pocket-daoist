extends CharacterBody2D
class_name Enemy

@export var max_health: float = 30.0
var current_health: float = 30.0
@export var speed: float = 130.0
@export var contact_damage: float = 8.0

# 轻量分离：只查空间哈希邻域，成本线性；半径/力度可调
@export var separation_radius: float = 22.0
@export var separation_force: float = 90.0

var is_dead: bool = false
var target: Node2D = null

var _flash_tween: Tween = null
var _knockback: Vector2 = Vector2.ZERO
var _releasing: bool = false

func _ready() -> void:
	add_to_group("enemies")
	_reset_state()
	_pick_target()

# 对象池取用时重置状态（由 ObjectPools.acquire 调用）
func pool_acquire() -> void:
	_releasing = false
	_reset_state()
	set_physics_process(true)
	_pick_target()

func _reset_state() -> void:
	is_dead = false
	current_health = max_health
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	modulate = Color.WHITE
	visible = true
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null

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

	# 空间哈希分离：查询本帧 CombatGrid 邻域，把过近的同类轻推分开
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

	# 击退冲量：叠加后指数衰减，制造命中反馈
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback * maxf(0.0, 1.0 - 12.0 * delta)
	else:
		_knockback = Vector2.ZERO

	move_and_slide()

	# 碰触玩家造成伤害（双方碰撞半径合计约 26，阈值取 30）
	if global_position.distance_to(target.global_position) <= 30.0:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage * delta)

func apply_knockback(impulse: Vector2) -> void:
	if is_dead:
		return
	_knockback += impulse

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	# 受击微光闪白（先打断上一次闪烁，避免补间叠加）
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
	# 掉落灵气妖丹（走对象池）
	var gem = ObjectPools.acquire("res://scenes/exp_gem.tscn", get_parent())
	if gem != null:
		gem.global_position = global_position
	get_tree().call_group("game_manager", "on_enemy_killed")
	_release_to_pool()

func despawn() -> void:
	# 屏幕外回收：不掉落、不计击杀
	if is_dead:
		return
	is_dead = true
	_release_to_pool()

func _release_to_pool() -> void:
	# 延迟归还：die() 常在 Area2D 信号回调中被调用，
	# 此时直接改动场景树会破坏正在进行的物理查询。
	if _releasing:
		return
	_releasing = true
	visible = false
	set_physics_process(false)
	call_deferred("_do_release")

func _do_release() -> void:
	ObjectPools.release(self)
