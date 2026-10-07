extends Node2D

@export var enemy_scene_path: String = "res://scenes/enemy.tscn"
@export var base_spawn_interval: float = 0.8
@export var min_spawn_interval: float = 0.25
@export var max_enemies: int = 250
@export var despawn_distance: float = 1800.0
@export var boss_time_seconds: float = 300.0 # 5 分钟 Boss 登场

var spawn_timer: float = 0.0
var elapsed: float = 0.0
var cleanup_timer: float = 0.0
var spawn_interval: float = 0.8

var _next_elite_time: float = 60.0
var _is_boss_spawned: bool = false
var _boss_instance: Node2D = null

# 兽潮时间表（90秒 / 180秒 / 255秒）
var _swarms = [
	{"time": 90.0, "count": 35, "elites": 1, "done": false, "text": "【兽潮初现：万狼围剿！】"},
	{"time": 180.0, "count": 50, "elites": 2, "done": false, "text": "【妖潮暴动：赤煞狼群狂涌！】"},
	{"time": 255.0, "count": 65, "elites": 2, "done": false, "text": "【至暗时刻：终极兽潮突袭！】"}
]

@onready var player: Node2D = get_node_or_null("../Player")

func _process(delta: float) -> void:
	elapsed += delta
	# 难度随时间平滑提升：刷怪间隔缩短
	spawn_interval = maxf(min_spawn_interval, base_spawn_interval - elapsed * 0.003)

	if player == null or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0:
			player = p[0]
		return

	# 1. 检查阶段性巨型兽潮
	_check_swarms()

	# 2. 第 5 分钟 (300 秒) 啸月狼王 Boss 降临
	if elapsed >= boss_time_seconds and not _is_boss_spawned:
		_spawn_boss()

	# 3. 常规杂兵刷新
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		# Boss 战期间限制杂兵同屏数量，突出 Boss 主角地位
		var current_cap = 30 if _is_boss_spawned else max_enemies
		if get_tree().get_nodes_in_group("enemies").size() < current_cap:
			_spawn_enemy(Enemy.Type.MINION)

	# 4. 常规精英怪刷新机制
	if elapsed >= _next_elite_time and not _is_boss_spawned:
		if elapsed < 180.0:
			_next_elite_time = elapsed + 50.0
			_spawn_enemy(Enemy.Type.ELITE)
		else:
			_next_elite_time = elapsed + 40.0
			_spawn_enemy(Enemy.Type.ELITE)

	# 5. 定期清理屏幕外的远距杂兵
	cleanup_timer += delta
	if cleanup_timer >= 2.0:
		cleanup_timer = 0.0
		_cleanup_far_enemies()

func _check_swarms() -> void:
	if _is_boss_spawned:
		return
	for s in _swarms:
		if not s["done"] and elapsed >= s["time"]:
			s["done"] = true
			_trigger_swarm(s["count"], s["elites"], s["text"])

func _trigger_swarm(count: int, elites: int, msg: String) -> void:
	Sfx.play("thunder", -2.0)
	get_tree().call_group("ui", "show_banner", msg)

	# 360 度环形向玩家合围冲锋
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU + randf_range(-0.1, 0.1)
		var dist = randf_range(700.0, 850.0)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		var enemy = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
		if enemy != null:
			enemy.global_position = spawn_pos
			if enemy.has_method("setup_type"):
				enemy.setup_type(Enemy.Type.MINION, elapsed)

	# 随兽潮伴随精英怪
	for e in range(elites):
		var angle = randf() * TAU
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * 750.0
		var elite = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
		if elite != null:
			elite.global_position = spawn_pos
			if elite.has_method("setup_type"):
				elite.setup_type(Enemy.Type.ELITE, elapsed)

func _spawn_enemy(type: Enemy.Type = Enemy.Type.MINION) -> void:
	var angle = randf() * TAU
	var distance = randf_range(650.0, 850.0)
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance

	var enemy = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
	if enemy == null:
		return
	enemy.global_position = spawn_pos
	if enemy.has_method("setup_type"):
		enemy.setup_type(type, elapsed)

func _spawn_boss() -> void:
	_is_boss_spawned = true
	Sfx.play("thunder", 0.0)
	get_tree().call_group("ui", "show_banner", "【大荒凶煞·啸月狼王 降临！】")

	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * 600.0

	var boss = ObjectPools.acquire(enemy_scene_path, get_parent(), max_enemies)
	if boss == null:
		return
	boss.global_position = spawn_pos
	if boss.has_method("setup_type"):
		boss.setup_type(Enemy.Type.BOSS, elapsed)
	_boss_instance = boss

	# 通知 UI 激活 Boss 血条
	get_tree().call_group("ui", "activate_boss_bar", boss.max_health)

func _cleanup_far_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_dead:
			if player.global_position.distance_to(e.global_position) > despawn_distance:
				e.despawn()
