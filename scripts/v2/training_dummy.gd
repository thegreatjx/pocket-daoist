class_name TrainingDummy
extends Enemy

enum ResetMode { DESTRUCTIBLE, INFINITE }

var reset_mode: int = ResetMode.INFINITE
var total_damage: float = 0.0
var hit_count: int = 0
var last_damage: float = 0.0
var dps: float = 0.0
var _damage_events: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("enemies")
	_pick_target()
	setup_dummy(5000.0, reset_mode)

func pool_acquire() -> void:
	_releasing = false
	set_physics_process(true)
	_pick_target()
	setup_dummy(5000.0, reset_mode)

func setup_dummy(hp: float = 5000.0, mode: int = ResetMode.INFINITE) -> void:
	is_dead = false
	is_dying_anim = false
	reset_mode = mode
	enemy_type = Type.MINION
	species = -1
	archetype_id = "training_dummy"
	max_health = maxf(100.0, hp)
	current_health = max_health
	speed = 0.0
	contact_damage = 0.0
	knockback_resistance = 1.0
	damage_reduction = 0.0
	exp_gem_count = 0
	exp_gem_value = 0.0
	gold_value = 0
	can_despawn = false
	is_boss = false
	separation_radius = 22.0
	separation_force = 0.0
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	modulate = Color.WHITE
	visible = true
	if col_shape != null:
		col_shape.set_deferred("disabled", false)
	if hurt_col_shape != null:
		hurt_col_shape.set_deferred("disabled", false)
	_update_shapes(14.0, 22.0)
	reset_stats()

func reset_stats() -> void:
	current_health = max_health
	total_damage = 0.0
	hit_count = 0
	last_damage = 0.0
	dps = 0.0
	_damage_events.clear()
	_dot_dps = 0.0
	_dot_timer = 0.0
	_dot_elem = ""
	_slow_ratio = 0.0
	_slow_timer = 0.0
	_freeze_timer = 0.0
	_clear_freeze_visual()
	_armor_shred = 0.0
	_armor_shred_timer = 0.0
	_stun_timer = 0.0
	set_active_element("", 0.0)
	if visual_node != null:
		visual_node.queue_redraw()

func _refresh_dps() -> void:
	var now_sec := float(Time.get_ticks_msec()) * 0.001
	var cutoff := now_sec - 3.0
	var sum := 0.0
	var kept: Array[Dictionary] = []
	for ev in _damage_events:
		if float(ev.get("t", 0.0)) >= cutoff:
			kept.append(ev)
			sum += float(ev.get("dmg", 0.0))
	_damage_events = kept
	dps = sum / 3.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _freeze_timer > 0.0:
		_freeze_timer = maxf(0.0, _freeze_timer - delta)
		if _freeze_timer <= 0.0:
			_clear_freeze_visual()
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_ratio = 0.0
	if _armor_shred_timer > 0.0:
		_armor_shred_timer -= delta
		if _armor_shred_timer <= 0.0:
			_armor_shred = 0.0
	if _elem_timer > 0.0:
		_elem_timer -= delta
		if _elem_timer <= 0.0:
			set_active_element("", 0.0)
	if _dot_timer > 0.0:
		_dot_timer -= delta
		_dot_tick_acc += delta
		if _dot_tick_acc >= 0.5:
			_dot_tick_acc -= 0.5
			take_damage_v2(_dot_dps * 0.5, false, false, _dot_elem, Color(0.0, 0.0, 0.0, 0.0), true)
			if is_dead:
				return
		if _dot_timer <= 0.0:
			_dot_dps = 0.0
			_dot_tick_acc = 0.0
			_dot_elem = ""
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			modulate = Color.WHITE
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_refresh_dps()

func apply_knockback(_impulse: Vector2) -> void:
	return

func take_damage_v2(amount: float, is_crit: bool = false, true_damage: bool = false, element: String = "", reaction_color: Color = Color(0.0, 0.0, 0.0, 0.0), _is_dot: bool = false) -> void:
	if is_dead:
		return
	var elem_mult := get_element_damage_mult(element)
	var coeff := maxf(1.0, elem_mult) if true_damage else clampf(1.0 - damage_reduction + _armor_shred, 0.20, 1.50) * elem_mult
	var freeze_vuln := FREEZE_VULN_MULT if _freeze_timer > 0.0 else 1.0
	var actual_damage := amount * coeff * freeze_vuln
	current_health -= actual_damage
	total_damage += actual_damage
	hit_count += 1
	last_damage = actual_damage
	_damage_events.append({"t": float(Time.get_ticks_msec()) * 0.001, "dmg": actual_damage})
	_refresh_dps()

	_spawn_damage_number(actual_damage, is_crit)
	if Settings.get_bool("video/hit_flash"):
		var hit_spec := V2VfxFactory.get_hit_vfx_spec(element, reaction_color)
		var flash_dur := float(hit_spec.get("duration", 0.055))
		modulate = hit_spec.get("flash_color", Color(1.75, 1.65, 1.45, 1.0)) as Color
		if visual_node != null and visual_node.has_method("trigger_hit_pop"):
			visual_node.trigger_hit_pop()
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, flash_dur)
		if get_parent() != null:
			V2VfxFactory.spawn_hit_spark(get_parent(), global_position + Vector2(0.0, -10.0), element, is_crit, reaction_color)

	if current_health <= 0.0:
		if reset_mode == ResetMode.INFINITE:
			current_health = max_health
		else:
			die()
	if visual_node != null:
		visual_node.queue_redraw()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	Sfx.play_varied("enemy_die", -6.0)
	if get_parent() != null:
		V2VfxFactory.spawn_enemy_death_vfx(get_parent(), global_position, Color(0.86, 0.72, 0.42, 1.0), false, false)
	if target != null and is_instance_valid(target) and "v2_combat" in target and target.v2_combat != null and target.v2_combat.reaction_engine != null:
		target.v2_combat.reaction_engine.clear_enemy(get_instance_id())
	queue_free()
