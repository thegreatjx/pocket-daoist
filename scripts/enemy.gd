extends CharacterBody2D
class_name Enemy

@export var max_health: float = 30.0
var current_health: float = 30.0
@export var speed: float = 130.0
@export var contact_damage: float = 8.0

var is_dead: bool = false
var target: Node2D = null
var exp_gem_scene = preload("res://scenes/exp_gem.tscn")

var _flash_tween: Tween = null

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	_pick_target()

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

	# 敌人之间不碰撞（collision_mask 只含玩家层），允许重叠跟随，物理开销为线性
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

	# 碰触玩家造成伤害（双方碰撞半径合计约 26，阈值取 30）
	if global_position.distance_to(target.global_position) <= 30.0:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage * delta)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	# 受击微光闪白（先打断上一次闪烁，避免补间叠加）
	modulate = Color(2.0, 1.5, 1.5, 1.0)
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	# 掉落灵气妖丹
	var gem = exp_gem_scene.instantiate()
	gem.global_position = global_position
	get_parent().call_deferred("add_child", gem)
	# 击杀计数上报
	get_tree().call_group("game_manager", "on_enemy_killed")
	queue_free()

func despawn() -> void:
	# 屏幕外回收：不掉落、不计击杀
	if is_dead:
		return
	is_dead = true
	queue_free()
