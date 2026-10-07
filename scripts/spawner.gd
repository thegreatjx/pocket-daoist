extends Node2D

@export var enemy_scene_path: String = "res://scenes/enemy.tscn"
@export var base_spawn_interval: float = 0.8
@export var min_spawn_interval: float = 0.25
@export var max_enemies: int = 250
@export var despawn_distance: float = 1800.0

var spawn_timer: float = 0.0
var elapsed: float = 0.0
var cleanup_timer: float = 0.0
var spawn_interval: float = 0.8

@onready var player: Node2D = get_node_or_null("../Player")

func _process(delta: float) -> void:
	elapsed += delta
	# 难度随时间提升：刷怪间隔逐渐缩短
	spawn_interval = maxf(min_spawn_interval, base_spawn_interval - elapsed * 0.004)

	if player == null or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0:
			player = p[0]
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		# 敌人数量硬上限，防止无限增长拖垮性能
		if get_tree().get_nodes_in_group("enemies").size() < max_enemies:
			_spawn_enemy()

	# 定期回收远离玩家的屏幕外敌人
	cleanup_timer += delta
	if cleanup_timer >= 2.0:
		cleanup_timer = 0.0
		_cleanup_far_enemies()

func _spawn_enemy() -> void:
	var angle = randf() * TAU
	var distance = randf_range(650.0, 850.0)
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance

	# 走对象池复用敌人，避免长时间运行后频繁分配/释放
	var enemy = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
	if enemy == null:
		return
	enemy.global_position = spawn_pos
	# 敌人血量随存活时间成长（每分钟 +50%）
	enemy.max_health *= 1.0 + elapsed / 120.0
	enemy.current_health = enemy.max_health

func _cleanup_far_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			if player.global_position.distance_to(e.global_position) > despawn_distance:
				e.despawn()
