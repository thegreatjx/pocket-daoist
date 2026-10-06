extends CharacterBody2D
class_name Player

signal health_changed(current_hp: float, max_hp: float)
signal exp_changed(current_exp: float, max_exp: float, level: int)
signal leveled_up(new_level: int)
signal died

@export var max_health: float = 100.0
var current_health: float = 100.0

@export var speed: float = 240.0
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 2.5

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

var is_dead: bool = false

var level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 15.0

var magnet_radius: float = 160.0
var exp_multiplier: float = 1.0

# 飞剑攻击属性
var sword_interval: float = 1.2
var sword_timer: float = 0.0
var sword_count: int = 1
var sword_pierce: int = 2
var sword_fly_speed: float = 600.0
var sword_base_damage: float = 35.0
var is_wanjian_unlocked: bool = false
var sword_scene = preload("res://scenes/sword.tscn")

# 护体剑阵属性
var orbit_sword_count: int = 2
var orbit_swords: Array[Node2D] = []
var orbit_angle: float = 0.0
var orbit_radius: float = 75.0
var orbit_speed: float = 3.5
var orbit_damage: float = 20.0

# 九天玄雷属性
var thunder_interval: float = 3.0
var thunder_timer: float = 0.0
var thunder_damage: float = 60.0
var thunder_radius: float = 65.0
var thunder_scene = preload("res://scenes/thunder.tscn")

# 残影生成计时器
var ghost_timer: float = 0.0

var _flash_tween: Tween = null

func _ready() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	emit_signal("exp_changed", current_exp, exp_to_next_level, level)
	_setup_orbit_swords()

# 公开接口：升级系统调整护体剑阵后调用
func refresh_orbit_swords() -> void:
	_setup_orbit_swords()

func _setup_orbit_swords() -> void:
	# 清除现有环绕剑
	for s in orbit_swords:
		if is_instance_valid(s):
			s.queue_free()
	orbit_swords.clear()

	var orbit_sword_res = preload("res://scenes/orbit_sword.tscn")
	for i in range(orbit_sword_count):
		var sw = orbit_sword_res.instantiate()
		sw.damage = orbit_damage
		add_child(sw)
		orbit_swords.append(sw)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 冷却时间递减
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# 键盘输入方向
	var move_input = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
	move_input = move_input.normalized()
	if move_input != Vector2.ZERO:
		dash_direction = move_input

	# 移动 / 身法瞬移（冲刺期间攻击不停摆）
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		ghost_timer -= delta
		if ghost_timer <= 0:
			_spawn_ghost_trail()
			ghost_timer = 0.04
		if dash_timer <= 0:
			is_dashing = false
	else:
		velocity = move_input * speed
		# 空格键施展踏云步
		if Input.is_key_pressed(KEY_SPACE) and dash_cooldown_timer <= 0.0:
			_start_dash()
	move_and_slide()

	# 环绕剑阵旋转
	_update_orbit_swords(delta)

	# 飞剑攻击轮询
	sword_timer += delta
	if sword_timer >= sword_interval:
		sword_timer = 0.0
		_cast_flying_sword()

	# 九天玄雷轮询
	thunder_timer += delta
	if thunder_timer >= thunder_interval:
		thunder_timer = 0.0
		_cast_thunder()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	ghost_timer = 0.0
	_spawn_ghost_trail()

func _spawn_ghost_trail() -> void:
	var ghost = Node2D.new()
	var ghost_script = preload("res://scripts/ghost_trail.gd")
	ghost.set_script(ghost_script)
	get_parent().add_child(ghost)
	ghost.global_position = global_position

func _update_orbit_swords(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	var count = orbit_swords.size()
	if count == 0:
		return
	var step = TAU / float(count)
	for i in range(count):
		var sw = orbit_swords[i]
		if is_instance_valid(sw):
			var a = orbit_angle + i * step
			sw.position = Vector2(cos(a), sin(a)) * orbit_radius
			sw.rotation = a + PI / 2.0

func _cast_flying_sword() -> void:
	var target = _find_nearest_enemy()
	if target == null:
		return

	var base_dir = (target.global_position - global_position).normalized()
	var base_angle = base_dir.angle()

	for i in range(sword_count):
		var sw = sword_scene.instantiate()
		get_parent().add_child(sw)
		sw.global_position = global_position
		# 扇形展开或微散开
		var offset_angle = (i - (sword_count - 1) / 2.0) * 0.18
		var final_dir = Vector2.from_angle(base_angle + offset_angle)
		sw.setup(final_dir, sword_base_damage, sword_fly_speed, sword_pierce)
		if is_wanjian_unlocked:
			sw.modulate = Color(1.2, 1.5, 0.4, 1.0) # 万剑归宗金色华彩

func _cast_thunder() -> void:
	# 只在玩家附近（屏幕范围内）选目标，避免劈到地图外敌人掉落无法拾取的灵气珠
	var enemies = get_tree().get_nodes_in_group("enemies")
	var candidates: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead \
				and global_position.distance_to(e.global_position) <= 800.0:
			candidates.append(e)
	if candidates.size() == 0:
		return
	var rand_target = candidates[randi() % candidates.size()]
	var th = thunder_scene.instantiate()
	th.damage = thunder_damage
	th.radius = thunder_radius
	get_parent().add_child(th)
	th.global_position = rand_target.global_position

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist_sq = INF
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			var d = global_position.distance_squared_to(e.global_position)
			if d < min_dist_sq:
				min_dist_sq = d
				nearest = e
	return nearest

func take_damage(amount: float) -> void:
	if is_dead or is_dashing:
		return # 死亡或身法无敌帧
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	# 受击微红闪烁（打断上一次闪烁补间，避免叠加）
	modulate = Color(1.5, 0.5, 0.5, 1.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if current_health <= 0:
		_die()

func gain_exp(amount: float) -> void:
	current_exp += amount * exp_multiplier
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		exp_to_next_level = round(exp_to_next_level * 1.35 + 10)
		emit_signal("leveled_up", level)
	emit_signal("exp_changed", current_exp, exp_to_next_level, level)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	emit_signal("died")
