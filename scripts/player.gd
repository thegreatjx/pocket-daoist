extends CharacterBody2D
class_name Player

signal health_changed(current_hp: float, max_hp: float)
signal exp_changed(current_exp: float, max_exp: float, level: int)
signal leveled_up(new_level: int)
signal died

@export var character_id: String = "sword_immortal"

var base_max_health: float = 120.0
var base_speed: float = 250.0
var base_dash_cooldown: float = 2.2
var base_magnet_radius: float = 170.0
var base_crit_chance: float = 0.12

@export var max_health: float = 120.0
var current_health: float = 120.0
@export var speed: float = 250.0
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 2.2

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var facing_dir: Vector2 = Vector2.RIGHT
var aim_dir: Vector2 = Vector2.RIGHT

var is_dead: bool = false
var level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 10.0

var magnet_radius: float = 170.0
var exp_multiplier: float = 1.0
var damage_reduction: float = 0.0
var regen_per_second: float = 0.0
var _regen_accum: float = 0.0
var invuln_timer: float = 0.0
var slow_timer: float = 0.0
var slow_mult: float = 1.0

var sect_might_mult: float = 1.0
var revivals_left: int = 0
var limit_might_bonus: float = 0.0
var limit_haste_bonus: float = 0.0
var _temp_might_bonus: float = 0.0
var _temp_haste_bonus: float = 0.0
var _temp_buff_timer: float = 0.0
var last_move_dir: Vector2 = Vector2.RIGHT

var shake_amount: float = 0.0
var shake_decay: float = 11.0
var _shake_time: float = 0.0
var _shake_dir: Vector2 = Vector2.RIGHT
var _shake_dir_amount: float = 0.0
var _flash_tween: Tween = null

var weapon_mgr: WeaponManager = null
var v2_combat: V2CombatController = null
var armor: float = 0.0
var dodge_chance: float = 0.0
var stage_speed_mult: float = 1.0
var debug_invincible: bool = false
@onready var camera: Camera2D = $Camera2D

static func exp_required_for_level(lv: int) -> float:
	var n := float(maxi(1, lv))
	if lv < 10:
		return roundf(30.0 + n * 17.0 + n * n * 0.55)
	if lv < 20:
		return roundf(45.0 + n * 22.0 + n * n * 0.65)
	return roundf(70.0 + n * 28.0 + n * n * 0.75)

func set_stage_speed_mult(mult: float) -> void:
	stage_speed_mult = maxf(0.5, mult)
	if v2_combat != null:
		v2_combat.recompute_player_stats()
	else:
		speed = base_speed * stage_speed_mult

static func _bind_action_keys(action: String, keys: Array, joy_btns: Array = [], joy_axis: int = -1, axis_val: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for kc in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc
		InputMap.action_add_event(action, ev)
	for jb in joy_btns:
		var jev := InputEventJoypadButton.new()
		jev.button_index = jb
		InputMap.action_add_event(action, jev)
	if joy_axis >= 0:
		var jmx := InputEventJoypadMotion.new()
		jmx.axis = joy_axis
		jmx.axis_value = axis_val
		InputMap.action_add_event(action, jmx)

static func ensure_move_input_actions() -> void:
	_bind_action_keys("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind_action_keys("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind_action_keys("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_bind_action_keys("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind_action_keys("dash", [KEY_SPACE], [JOY_BUTTON_A])

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _ready() -> void:
	ensure_move_input_actions()
	collision_layer = 8
	collision_mask = 1
	if character_id == "sword_immortal" and Stats.selected_character_id != "":
		character_id = Stats.selected_character_id
	var cfg := CharacterData.get_character(character_id)
	base_max_health = float(cfg.get("max_health", 120.0)) + float(Stats.get_sect_level("hp")) * 20.0
	base_speed = float(cfg.get("speed", 250.0)) * (1.0 + float(Stats.get_sect_level("speed")) * 0.06)
	base_magnet_radius = float(cfg.get("magnet_radius", 170.0)) * (1.0 + float(Stats.get_sect_level("magnet")) * 0.15)
	base_crit_chance = float(cfg.get("crit_chance", 0.12))
	sect_might_mult = 1.0 + float(Stats.get_sect_level("might")) * 0.08
	revivals_left = Stats.get_sect_level("revival")

	max_health = base_max_health
	current_health = max_health
	speed = base_speed * stage_speed_mult
	magnet_radius = base_magnet_radius
	dash_cooldown = base_dash_cooldown
	exp_to_next_level = exp_required_for_level(level)

	weapon_mgr = WeaponManager.new()
	weapon_mgr.name = "WeaponManager"
	add_child(weapon_mgr)
	weapon_mgr.bind_player(self, str(cfg.get("start_weapon", "lotus_slash")))
	weapon_mgr.auto_fire_enabled = false

	var vis := get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("sync_character_visual"):
		vis.sync_character_visual()

	v2_combat = V2CombatController.new()
	v2_combat.name = "V2Combat"
	add_child(v2_combat)
	v2_combat.setup_for_player(self)

	emit_signal("health_changed", current_health, max_health)
	emit_signal("exp_changed", current_exp, exp_to_next_level, level)

func _input(event: InputEvent) -> void:
	if not is_dead and event is InputEventMouseMotion:
		_update_aim_from_mouse()

func get_aim_direction() -> Vector2:
	return aim_dir.normalized() if aim_dir.length_squared() > 0.001 else Vector2.RIGHT

func _update_aim_from_mouse() -> void:
	if get_viewport() == null:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 4.0:
		aim_dir = to_mouse.normalized()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_aim_from_mouse()
	_update_shake(delta)

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if invuln_timer > 0.0:
		invuln_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_mult = 1.0

	var move_input := get_move_input()
	if move_input.length_squared() > 0.0001:
		var move_dir := move_input.normalized()
		dash_direction = move_dir
		facing_dir = move_dir
		last_move_dir = move_dir

	if _temp_buff_timer > 0.0:
		_temp_buff_timer -= delta
		if _temp_buff_timer <= 0.0:
			limit_might_bonus -= _temp_might_bonus
			limit_haste_bonus -= _temp_haste_bonus
			_temp_might_bonus = 0.0
			_temp_haste_bonus = 0.0
			_temp_buff_timer = 0.0

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0.0:
			_end_dash()
	else:
		velocity = move_input * speed * slow_mult
		if (Input.is_action_pressed("dash") or Input.is_key_pressed(KEY_SPACE)) and dash_cooldown_timer <= 0.0:
			if move_input.length_squared() > 0.0001:
				dash_direction = move_input.normalized()
			_start_dash()
	move_and_slide()

	if regen_per_second > 0.0 and current_health < max_health:
		_regen_accum += regen_per_second * delta
		if _regen_accum >= 0.25:
			var heal_amt := _regen_accum
			_regen_accum = 0.0
			current_health = minf(max_health, current_health + heal_amt)
			emit_signal("health_changed", current_health, max_health)

func _update_shake(delta: float) -> void:
	_shake_time += delta
	if shake_amount <= 0.0 and _shake_dir_amount <= 0.05:
		if camera != null and camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, minf(1.0, delta * 30.0))
		return
	shake_amount = maxf(0.0, shake_amount - shake_decay * delta * shake_amount)
	if shake_amount < 0.05:
		shake_amount = 0.0
	_shake_dir_amount = maxf(0.0, _shake_dir_amount - 22.0 * delta * _shake_dir_amount)
	if _shake_dir_amount < 0.05:
		_shake_dir_amount = 0.0

	var sway := Vector2(
		sin(_shake_time * 97.0) * 0.55 + sin(_shake_time * 151.0 + 1.3) * 0.45,
		sin(_shake_time * 83.0 + 0.7) * 0.55 + sin(_shake_time * 137.0 + 2.1) * 0.45)
	var horizontal := clampf((shake_amount - 1.2) / 8.0, 0.0, 1.0)
	var offset := Vector2(sway.x * horizontal, sway.y) * shake_amount + _shake_dir * _shake_dir_amount
	if camera != null:
		camera.offset = offset

func shake_camera(amount: float) -> void:
	if not Settings.get_bool("video/screen_shake"):
		return
	shake_amount = minf(20.0, shake_amount + amount)

func shake_camera_dir(amount: float, dir: Vector2) -> void:
	shake_camera(amount)
	if dir.length_squared() > 0.0001:
		_shake_dir = dir.normalized()
		_shake_dir_amount = maxf(_shake_dir_amount, amount * 0.9)

func _start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	collision_layer = 0
	collision_mask = 1
	Sfx.play("dash", -6.0)

func _end_dash() -> void:
	is_dashing = false
	collision_layer = 8
	collision_mask = 1
	invuln_timer = maxf(invuln_timer, 0.15)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	emit_signal("health_changed", current_health, max_health)

func apply_temp_buff(haste_bonus: float, might_bonus: float, duration: float) -> void:
	limit_haste_bonus -= _temp_haste_bonus
	limit_might_bonus -= _temp_might_bonus
	_temp_haste_bonus = haste_bonus
	_temp_might_bonus = might_bonus
	limit_haste_bonus += _temp_haste_bonus
	limit_might_bonus += _temp_might_bonus
	_temp_buff_timer = maxf(0.1, duration)

func gain_exp(amount: float) -> void:
	if is_dead:
		return
	current_exp += amount * exp_multiplier
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		exp_to_next_level = exp_required_for_level(level)
		emit_signal("leveled_up", level)
	emit_signal("exp_changed", current_exp, exp_to_next_level, level)

func apply_slow(ratio: float, duration: float) -> void:
	if is_dead or ratio <= 0.0:
		return
	slow_mult = minf(slow_mult, clampf(1.0 - ratio, 0.25, 1.0))
	slow_timer = maxf(slow_timer, duration)

func take_damage(amount: float) -> void:
	if debug_invincible and amount < 90000.0:
		return
	if is_dead or is_dashing or invuln_timer > 0.0:
		return
	if amount < 90000.0 and dodge_chance > 0.0 and randf() < clampf(dodge_chance, 0.0, 0.55):
		invuln_timer = 0.25
		if v2_combat != null:
			v2_combat._spawn_text_popup(global_position + Vector2(0.0, -28.0), "闪避", Color(0.45, 0.95, 0.85))
		return
	var total_dmg_mult := 1.0 if amount >= 90000.0 else maxf(0.25, 1.0 - clampf(damage_reduction, 0.0, 0.75))
	var actual := amount * total_dmg_mult
	if actual <= 0.0:
		return
	current_health -= actual
	invuln_timer = 0.45
	Sfx.play_varied("player_hurt", -6.0)
	shake_camera(5.5)

	var vis := get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("trigger_hurt_feedback"):
		vis.trigger_hurt_feedback(0.45)
	if v2_combat != null and v2_combat.orbit_rig != null and v2_combat.orbit_rig.has_method("trigger_hurt_scatter"):
		v2_combat.orbit_rig.trigger_hurt_scatter(1.0)

	if Settings.get_bool("video/hit_flash"):
		modulate = Color(1.6, 0.55, 0.55, 1.0)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.14)

	if amount < 90000.0 and current_health > 0.0:
		for e in CombatGrid.query(global_position, 80.0):
			if e != null and is_instance_valid(e) and not bool(e.get("is_dead")) and e.has_method("apply_knockback"):
				var away: Vector2 = ((e as Node2D).global_position - global_position).normalized()
				if away.length_squared() < 0.001:
					away = Vector2.RIGHT
				e.apply_knockback(away * 180.0)

	if current_health <= 0.0:
		# 90000+ 为测试直接秒杀哨兵值，常规战斗伤害触发九转金丹复活
		if revivals_left > 0 and amount < 90000.0:
			_trigger_revival()
			return
		current_health = 0.0
		is_dead = true
		is_dashing = false
		collision_layer = 8
		collision_mask = 1
		emit_signal("health_changed", current_health, max_health)
		emit_signal("died")
	else:
		emit_signal("health_changed", current_health, max_health)

func _trigger_revival() -> void:
	revivals_left -= 1
	current_health = max_health * 0.60
	invuln_timer = 2.2
	Sfx.play("level_up", 0.0)
	shake_camera(10.0)
	get_tree().call_group("ui", "show_banner", "【九转金丹 · 涅槃重生！】")
	for e in CombatGrid.query(global_position, 260.0):
		if is_instance_valid(e) and not e.is_dead and e.has_method("apply_knockback"):
			var away: Vector2 = (e.global_position - global_position).normalized()
			e.apply_knockback(away * 360.0)
	if v2_combat != null and v2_combat.has_method("on_player_revived"):
		v2_combat.on_player_revived()
	emit_signal("health_changed", current_health, max_health)

func debug_switch_character(new_char_id: String) -> void:
	character_id = new_char_id
	Stats.selected_character_id = new_char_id
	var cfg := CharacterData.get_character(character_id)
	base_max_health = float(cfg.get("max_health", 120.0)) + float(Stats.get_sect_level("hp")) * 20.0
	base_speed = float(cfg.get("speed", 250.0)) * (1.0 + float(Stats.get_sect_level("speed")) * 0.06)
	base_magnet_radius = float(cfg.get("magnet_radius", 170.0)) * (1.0 + float(Stats.get_sect_level("magnet")) * 0.15)
	base_crit_chance = float(cfg.get("crit_chance", 0.12))
	var vis := get_node_or_null("BodyVisual")
	if vis != null and vis.has_method("sync_character_visual"):
		vis.sync_character_visual()
	if v2_combat != null:
		v2_combat.recompute_player_stats()
	else:
		max_health = base_max_health
		speed = base_speed * stage_speed_mult
		magnet_radius = base_magnet_radius
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
