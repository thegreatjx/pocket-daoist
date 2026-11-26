extends CharacterBody2D
class_name Enemy

enum Type {
	MINION,
	ELITE,
	BOSS
}

const DAMAGE_NUMBER_SCENE := "res://scenes/damage_number.tscn"
const TREASURE_CHEST_SCENE: PackedScene = preload("res://scenes/treasure_chest.tscn")
const FREEZE_MARKER_SCRIPT: Script = preload("res://scripts/freeze_marker.gd")
const OFFSCREEN_CULL_MARGIN := 160.0
const DEATH_ANIM_DURATION := 0.38
const FREEZE_VULN_MULT := 1.15
const BOSS_FREEZE_MAX_SEC := 1.5
const BOSS_FREEZE_SLOW_RATIO := 0.6

var enemy_type: Type = Type.MINION

@export var max_health: float = 35.0
var current_health: float = 35.0
@export var speed: float = 130.0
@export var contact_damage: float = 8.0

@export var separation_radius: float = 22.0
@export var separation_force: float = 90.0

var knockback_resistance: float = 0.0
var damage_reduction: float = 0.0
var exp_gem_count: int = 1
var exp_gem_value: float = 6.0
var can_despawn: bool = true
var is_boss: bool = false
var is_mini_boss: bool = false
var elite_affix_id: String = ""
var elite_aura_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var elite_blast_delay: float = 0.0
var elite_blast_radius: float = 0.0
var elite_blast_damage: float = 0.0

var is_dead: bool = false
var target: Node2D = null

var _flash_tween: Tween = null
var _knockback: Vector2 = Vector2.ZERO
var _releasing: bool = false
var _slow_ratio: float = 0.0
var _slow_timer: float = 0.0
var _stun_timer: float = 0.0
var _freeze_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _freeze_marker: Node2D = null
var _spawn_elapsed: float = 0.0
var _cached_bg: Node = null

var _elite_skill_cd: float = 4.5
var _elite_state: int = 0
var _elite_timer: float = 0.0
var _elite_aim: Vector2 = Vector2.RIGHT
var _ranged_cd: float = 4.2

var archetype_id: String = ""
var gold_value: int = 1
var chase_mode: String = "direct"
var ranged_attack: Dictionary = {}
var dash_telegraph: Dictionary = {}
var death_burst: Dictionary = {}
var resistances: Dictionary = {}
var element_multipliers: Dictionary = {}
var tier_variant: int = 1
var is_visual_culled: bool = false
var _cull_check_accum: float = 0.0
var _banish_timer: float = 0.0
var _banish_vel: Vector2 = Vector2.ZERO
var damage_taken_mult: float = 1.0
var _vuln_timer: float = 0.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var _shield_break_flash: float = 0.0
var _detonate_mark_timer: float = 0.0
var _detonate_mark_radius: float = 95.0
var _detonate_mark_pct: float = 0.22
var _detonate_mark_cap: float = 0.0
var _dot_dps: float = 0.0
var _dot_timer: float = 0.0
var _dot_tick_acc: float = 0.0
var _dot_spread_on_death: bool = false
var _dot_elem: String = ""
var _soul_seal_active: bool = false
var _soul_seal_dps: float = 0.0
var _soul_seal_radius: float = 110.0
var _soul_seal_targets: int = 3
var _active_elem: String = ""
var _elem_timer: float = 0.0
var _charger_cd: float = 2.8
var _charger_state: int = 0
var _charger_timer: float = 0.0
var _charger_windup_total: float = 0.40
var _charger_aim: Vector2 = Vector2.RIGHT
var _elite_windup_total: float = 0.65
var _boss_windup_total: float = 0.56
var _last_hit_flash_key: String = ""
var _last_hit_flash_duration: float = 0.0
var is_dying_anim: bool = false
var _death_anim_timer: float = 0.0
var _death_anim_elapsed: float = 0.0
var _death_spin_dir: float = 1.0

enum BossState { CHASE, WINDUP, ACTION, RECOVER }
var _boss_state: int = BossState.CHASE
var _boss_state_timer: float = 0.0
var _boss_skill_cd: float = 1.65
var _boss_skill_index: int = 0
var _boss_active_skill: String = ""
var _boss_aim_dir: Vector2 = Vector2.RIGHT
var _boss_dashing: bool = false
var _boss_enraged: bool = false
var _boss_dash_ghost_cd: float = 0.0
var _boss_strafe_phase: float = 0.0
var boss_kit = null

@onready var visual_node: Node2D = get_node_or_null("Visual")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var hurt_col_shape: CollisionShape2D = get_node_or_null("HurtBox/CollisionShape2D")

var species: int = 0

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
	is_dying_anim = false
	_death_anim_timer = 0.0
	_death_anim_elapsed = 0.0
	_death_spin_dir = 1.0
	if not is_in_group("enemies"):
		add_to_group("enemies")
	enemy_type = Type.MINION
	species = 0
	max_health = 35.0
	current_health = 35.0
	speed = 130.0
	contact_damage = 8.0
	knockback_resistance = 0.0
	damage_reduction = 0.0
	exp_gem_count = 1
	exp_gem_value = 6.0
	can_despawn = true
	is_boss = false
	is_mini_boss = false
	elite_affix_id = ""
	elite_aura_color = Color(0.0, 0.0, 0.0, 0.0)
	elite_blast_delay = 0.0
	elite_blast_radius = 0.0
	elite_blast_damage = 0.0
	if is_in_group("bosses"):
		remove_from_group("bosses")
	if is_in_group("elite_enemies"):
		remove_from_group("elite_enemies")
	separation_radius = 22.0
	separation_force = 90.0

	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_slow_ratio = 0.0
	_slow_timer = 0.0
	_stun_timer = 0.0
	_clear_freeze_visual()
	_freeze_timer = 0.0
	_hitstop_timer = 0.0
	if visual_node != null:
		visual_node.position = Vector2.ZERO
	_spawn_elapsed = 0.0
	_elite_skill_cd = 4.5
	_elite_state = 0
	_elite_timer = 0.0
	_elite_aim = Vector2.RIGHT
	_ranged_cd = randf_range(2.8, 5.2)
	archetype_id = ""
	gold_value = 1
	chase_mode = "direct"
	ranged_attack.clear()
	dash_telegraph.clear()
	death_burst.clear()
	resistances.clear()
	element_multipliers.clear()
	tier_variant = 1
	_cull_check_accum = float(get_instance_id() % 5) * 0.008
	_banish_timer = 0.0
	_banish_vel = Vector2.ZERO
	set_process(false)
	_set_visual_culled(false)
	damage_taken_mult = 1.0
	_vuln_timer = 0.0
	max_shield = 0.0
	current_shield = 0.0
	_shield_break_flash = 0.0
	_detonate_mark_timer = 0.0
	_detonate_mark_radius = 95.0
	_detonate_mark_pct = 0.22
	_detonate_mark_cap = 0.0
	_dot_dps = 0.0
	_dot_timer = 0.0
	_dot_tick_acc = 0.0
	_dot_spread_on_death = false
	_dot_elem = ""
	_soul_seal_active = false
	_soul_seal_dps = 0.0
	_soul_seal_radius = 110.0
	_soul_seal_targets = 3
	_active_elem = ""
	_elem_timer = 0.0
	_charger_cd = randf_range(1.6, 2.8)
	_charger_state = 0
	_charger_timer = 0.0
	_charger_windup_total = 0.40
	_charger_aim = Vector2.RIGHT
	_elite_windup_total = 0.65
	_boss_windup_total = 0.56
	_last_hit_flash_key = ""
	_last_hit_flash_duration = 0.0
	_boss_state = BossState.CHASE
	_boss_state_timer = 0.0
	_boss_skill_cd = 1.65
	_boss_skill_index = 0
	_boss_active_skill = ""
	_boss_aim_dir = Vector2.RIGHT
	_boss_dashing = false
	_boss_enraged = false
	_boss_dash_ghost_cd = 0.0
	_boss_strafe_phase = 0.0
	modulate = Color.WHITE
	visible = true
	if col_shape != null:
		col_shape.set_deferred("disabled", false)
	if hurt_col_shape != null:
		hurt_col_shape.set_deferred("disabled", false)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if visual_node != null:
		visual_node.scale = Vector2.ONE
		visual_node.rotation = 0.0
		visual_node.set_process(true)
	if visual_node != null and visual_node.has_method("set_type"):
		visual_node.set_type(int(Type.MINION), 0)
	if visual_node != null and visual_node.has_method("set_tier_variant"):
		visual_node.set_tier_variant(1)
	if visual_node != null and visual_node.has_method("set_active_element"):
		visual_node.set_active_element("")
	_update_shapes(12.0, 14.0)

func apply_archetype(arch: Dictionary, variant: int = 1) -> void:
	if arch.is_empty():
		return
	archetype_id = String(arch.get("id", ""))
	gold_value = int(arch.get("gold_value", 1))
	tier_variant = clampi(variant, 1, 3)
	chase_mode = String(arch.get("chase_mode", "direct"))
	if enemy_type == Type.MINION:
		ranged_attack.clear()
		dash_telegraph.clear()
		death_burst.clear()
	else:
		var ra: Variant = arch.get("ranged_attack", null)
		ranged_attack = (ra as Dictionary).duplicate(true) if ra is Dictionary else {}
		var dt: Variant = arch.get("dash_telegraph", null)
		dash_telegraph = (dt as Dictionary).duplicate(true) if dt is Dictionary else {}
		var db: Variant = arch.get("death_burst", null)
		death_burst = (db as Dictionary).duplicate(true) if db is Dictionary else {}
	var res: Variant = arch.get("resistances", null)
	resistances = (res as Dictionary).duplicate(true) if res is Dictionary else {}
	var em: Variant = arch.get("element_multipliers", null)
	element_multipliers = (em as Dictionary).duplicate(true) if em is Dictionary else {}
	knockback_resistance = float(resistances.get("knockback_resist", arch.get("knockback_resist", 0.0)))
	damage_reduction = 0.0
	var rad := float(arch.get("radius", 0.0))
	if rad > 0.0:
		separation_radius = maxf(14.0, rad)
	if dash_telegraph.has("cooldown_sec"):
		_charger_cd = randf_range(0.5, float(dash_telegraph["cooldown_sec"]))
	if visual_node != null and visual_node.has_method("set_tier_variant"):
		visual_node.set_tier_variant(tier_variant)

func setup_type(t: Type, elapsed_time: float, sp: int = 0) -> void:
	enemy_type = t
	species = sp
	_spawn_elapsed = elapsed_time
	archetype_id = ""
	ranged_attack.clear()
	dash_telegraph.clear()
	death_burst.clear()
	resistances.clear()
	element_multipliers.clear()
	tier_variant = 1
	match sp:
		3:
			chase_mode = "hop"
		5:
			chase_mode = "snake"
		_:
			chase_mode = "direct"
	match t:
		Type.MINION:
			match sp:
				1:
					max_health = 28.0 * (1.0 + elapsed_time / 180.0)
					speed = 115.0
					contact_damage = 7.0
					knockback_resistance = 0.20
					damage_reduction = 0.0
					separation_radius = 16.0
					separation_force = 60.0
					_update_shapes(10.0, 12.0)
				2:
					max_health = 45.0 * (1.0 + elapsed_time / 180.0)
					speed = 95.0
					contact_damage = 10.0
					knockback_resistance = 0.10
					damage_reduction = 0.0
					separation_radius = 20.0
					separation_force = 80.0
					_update_shapes(12.0, 14.0)
				_:
					max_health = 35.0 * (1.0 + elapsed_time / 180.0)
					speed = 135.0
					contact_damage = 8.0
					knockback_resistance = 0.0
					damage_reduction = 0.0
					separation_radius = 22.0
					separation_force = 90.0
					_update_shapes(12.0, 14.0)
			exp_gem_count = 1
			can_despawn = true
			is_boss = false
		Type.ELITE:
			var elite_scale := 1.0 + elapsed_time / 300.0
			if not is_in_group("elite_enemies"):
				add_to_group("elite_enemies")
			max_health = 720.0 * elite_scale
			speed = 140.0
			contact_damage = 18.0
			knockback_resistance = 0.72
			damage_reduction = 0.0
			exp_gem_count = 4
			match sp:
				0:
					max_health = 660.0 * elite_scale
					speed = 146.0
					contact_damage = 16.0
					knockback_resistance = 0.72
				1:
					max_health = 640.0 * elite_scale
					speed = 144.0
					contact_damage = 17.0
					knockback_resistance = 0.72
				2:
					max_health = 840.0 * elite_scale
					speed = 132.0
					contact_damage = 21.0
					knockback_resistance = 0.85
					exp_gem_count = 5
				3:
					max_health = 750.0 * elite_scale
					speed = 138.0
					contact_damage = 18.0
					knockback_resistance = 0.78
					resistances["slow_resist"] = 0.45
					chase_mode = "hop"
				4:
					max_health = 900.0 * elite_scale
					speed = 122.0
					contact_damage = 16.0
					knockback_resistance = 0.85
					damage_reduction = 0.0
					exp_gem_count = 6
					chase_mode = "hop"
				5:
					max_health = 620.0 * elite_scale
					speed = 158.0
					contact_damage = 15.0
					knockback_resistance = 0.68
					exp_gem_count = 6
					chase_mode = "snake"
				6:
					max_health = 800.0 * elite_scale
					speed = 148.0
					contact_damage = 20.0
					knockback_resistance = 0.80
					exp_gem_count = 5
			can_despawn = false
			is_boss = false
			separation_radius = 35.0
			separation_force = 120.0
			_update_shapes(18.0, 22.0)
		Type.BOSS:
			max_health = 22000.0
			speed = 138.0
			contact_damage = 30.0
			knockback_resistance = 0.95
			damage_reduction = 0.0
			exp_gem_count = 14
			can_despawn = false
			is_boss = true
			separation_radius = 55.0
			separation_force = 200.0
			_update_shapes(32.0, 36.0)
			if sp == 4:
				knockback_resistance = 1.0

	if is_boss:
		_create_boss_kit(sp)
		add_to_group("bosses")
	elif is_in_group("bosses"):
		remove_from_group("bosses")

	var curse_hp_mult := _resolve_curse_hp_mult()
	if curse_hp_mult > 1.0:
		max_health *= curse_hp_mult
	current_health = max_health
	sync_qi_shield()
	if visual_node != null and visual_node.has_method("set_type"):
		visual_node.set_type(int(t), species)
	if visual_node != null and visual_node.has_method("set_tier_variant"):
		visual_node.set_tier_variant(1)

func _resolve_curse_hp_mult() -> float:
	if not is_inside_tree() or get_tree() == null:
		return 1.0
	var p := get_tree().get_first_node_in_group("player")
	if p != null and "v2_combat" in p and p.v2_combat != null and p.v2_combat.has_method("get_curse_enemy_hp_mult"):
		return float(p.v2_combat.get_curse_enemy_hp_mult())
	return 1.0

func sync_qi_shield() -> void:
	match enemy_type:
		Type.MINION:
			max_shield = 0.0
		Type.ELITE:
			max_shield = roundf(max_health * (0.32 if is_mini_boss else 0.25))
		Type.BOSS:
			max_shield = roundf(max_health * (6500.0 / 22000.0))
	current_shield = max_shield

func apply_curse_scaling(curse_pct: float) -> void:
	var mult := V2SpawnDirector.calc_curse_hp_mult(curse_pct)
	if mult > 1.0:
		max_health *= mult
		current_health = max_health
		max_shield *= mult
		current_shield = max_shield

func get_boss_anim_state() -> String:
	if not is_boss:
		return "chase"
	match _boss_state:
		BossState.WINDUP:
			return "windup"
		BossState.ACTION:
			if _boss_active_skill == "dash":
				return "pounce"
			return "roar"
		_:
			return "chase"

func _update_shapes(body_r: float, hit_r: float) -> void:
	if col_shape != null and col_shape.shape is CircleShape2D:
		(col_shape.shape as CircleShape2D).radius = body_r
	if hurt_col_shape != null and hurt_col_shape.shape is CircleShape2D:
		(hurt_col_shape.shape as CircleShape2D).radius = hit_r

func _pick_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _process(delta: float) -> void:
	if _banish_timer > 0.0:
		_banish_timer -= delta
		global_position += _banish_vel * delta
		_banish_vel *= maxf(0.0, 1.0 - 5.0 * delta)
		modulate.a = clampf(_banish_timer / 0.25, 0.0, 1.0)
		if _banish_timer <= 0.0:
			set_process(false)
			_release_to_pool()
		return
	if is_dying_anim:
		_death_anim_elapsed += delta
		_death_anim_timer = maxf(0.0, DEATH_ANIM_DURATION - _death_anim_elapsed)
		var u := clampf(_death_anim_elapsed / DEATH_ANIM_DURATION, 0.0, 1.0)
		var s := maxf(0.001, 1.0 - u)
		if visual_node != null:
			visual_node.scale = Vector2(s, s)
			visual_node.rotation = _death_spin_dir * TAU * u
		var gray := lerpf(1.0, 0.35, u)
		modulate = Color(gray, gray, gray, clampf(1.0 - u * 0.85, 0.0, 1.0))
		if _death_anim_elapsed >= DEATH_ANIM_DURATION:
			is_dying_anim = false
			set_process(false)
			_release_to_pool()
		return
	set_process(false)

func get_camera_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		var center := target.global_position if (target != null and is_instance_valid(target)) else global_position
		return Rect2(center - Vector2(640.0, 360.0), Vector2(1280.0, 720.0))
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		var center := target.global_position if (target != null and is_instance_valid(target)) else global_position
		return Rect2(center - Vector2(640.0, 360.0), Vector2(1280.0, 720.0))
	var inv := vp.get_canvas_transform().affine_inverse()
	var tl := inv * Vector2.ZERO
	var br := inv * vp_size
	return Rect2(tl, br - tl).abs()

func _set_visual_culled(culled: bool) -> void:
	is_visual_culled = culled
	if visual_node != null:
		visual_node.visible = not culled
		visual_node.set_process(not culled)

func update_visual_culling(cam_rect: Rect2) -> bool:
	if is_boss:
		if is_visual_culled:
			_set_visual_culled(false)
		return false
	var should_cull := not cam_rect.grow(OFFSCREEN_CULL_MARGIN).has_point(global_position)
	if should_cull != is_visual_culled:
		_set_visual_culled(should_cull)
	return is_visual_culled

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if target == null or not is_instance_valid(target):
		_pick_target()
		if target == null:
			return

	_spawn_elapsed += delta
	_cull_check_accum += delta
	if _cull_check_accum >= 0.10:
		_cull_check_accum = 0.0
		update_visual_culling(get_camera_world_rect())

	if _freeze_timer > 0.0:
		_freeze_timer = maxf(0.0, _freeze_timer - delta)
		velocity = Vector2.ZERO
		_knockback = Vector2.ZERO
		if visual_node != null:
			visual_node.set_process(false)
		if _freeze_timer <= 0.0:
			_clear_freeze_visual()
		return

	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		velocity = Vector2.ZERO
		if visual_node != null and not is_visual_culled:
			visual_node.position = Vector2(randf_range(-2.2, 2.2), randf_range(-1.6, 1.6))
			if _hitstop_timer <= 0.0:
				visual_node.position = Vector2.ZERO
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_ratio = 0.0

	if _vuln_timer > 0.0:
		_vuln_timer -= delta
		if _vuln_timer <= 0.0:
			damage_taken_mult = 1.0

	if _shield_break_flash > 0.0:
		_shield_break_flash = maxf(0.0, _shield_break_flash - delta)

	if _detonate_mark_timer > 0.0:
		_detonate_mark_timer = maxf(0.0, _detonate_mark_timer - delta)

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
		velocity = _knockback
		if _knockback.length_squared() > 1.0:
			_knockback = _knockback * maxf(0.0, 1.0 - 12.0 * delta)
		else:
			_knockback = Vector2.ZERO
		move_and_slide()
		if _stun_timer <= 0.0 and not is_dead:
			modulate = Color.WHITE
		return

	if is_boss:
		_process_boss_ai(delta)
	elif enemy_type == Type.ELITE:
		_process_elite_ai(delta)
	else:
		_process_minion_ai(delta)

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

	var pillars := _get_pillars()
	if not pillars.is_empty():
		if enemy_type == Type.ELITE and _elite_state == 2 and EnemySteeringDirector.check_pillar_collision(global_position, 20.0, pillars, 6.0):
			apply_stun(1.2)
			move_and_slide()
			return
		elif enemy_type != Type.MINION and not is_boss and _charger_state == 2 and not dash_telegraph.is_empty() and EnemySteeringDirector.check_pillar_collision(global_position, separation_radius * 0.85, pillars, 6.0):
			_charger_state = 0
			_charger_cd = float(dash_telegraph.get("cooldown_sec", 2.8))
			apply_stun(float(dash_telegraph.get("stun_on_pillar", 1.2)))
			move_and_slide()
			return
		elif not is_boss and velocity.length_squared() > 1.0:
			velocity += EnemySteeringDirector.compute_pillar_slide(
				global_position,
				separation_radius * 0.7,
				velocity.normalized(),
				speed * (1.0 - _slow_ratio),
				pillars,
				get_instance_id()
			)

	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback * maxf(0.0, 1.0 - 12.0 * delta)
	else:
		_knockback = Vector2.ZERO

	move_and_slide()

	var touch_distance = 32.0 if not is_boss else 52.0
	if global_position.distance_to(target.global_position) <= touch_distance:
		if target.has_method("take_damage"):
			target.take_damage(contact_damage)

func _process_minion_ai(_delta: float) -> void:
	var to_p := target.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / maxf(1.0, dist)
	var eff_spd := speed * (1.0 - _slow_ratio)

	if chase_mode == "hop":
		var hop_phase := fmod(_spawn_elapsed * 7.5, TAU)
		var hop_boost := 1.45 if sin(hop_phase) > 0.0 else 0.55
		velocity = dir * eff_spd * hop_boost
	elif chase_mode == "snake":
		var jitter := Vector2(-dir.y, dir.x) * sin(_spawn_elapsed * 7.0 + float(get_instance_id() % 7)) * 0.35
		velocity = (dir + jitter).normalized() * eff_spd
	elif species == 1:
		var strafe := Vector2(-dir.y, dir.x) * sin(_spawn_elapsed + float(get_instance_id() % 13)) * 0.28
		velocity = (dir + strafe).normalized() * eff_spd
	else:
		velocity = dir * eff_spd

func _fire_elite_orb(direction: Vector2, spd: float, dmg: float, rad: float, col: Color) -> void:
	if get_parent() == null:
		return
	var orb := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
	if orb != null:
		orb.setup_projectile(self, global_position, direction.normalized(), spd, dmg, rad, col)

func _process_elite_ai(delta: float) -> void:
	var to_p := target.global_position - global_position
	var dist := to_p.length()
	var dir := to_p / maxf(1.0, dist)
	var eff_spd := speed * (1.0 - _slow_ratio)

	match _elite_state:
		0:
			match species:
				0, 1:
					var strafe := Vector2(-dir.y, dir.x) * sin(_spawn_elapsed * 2.2 + float(get_instance_id() % 11)) * 0.45
					velocity = (dir + strafe).normalized() * eff_spd
				3, 4:
					var hop_p := fmod(_spawn_elapsed * 6.8, TAU)
					var hop_b := 1.38 if sin(hop_p) > 0.0 else 0.62
					velocity = dir * eff_spd * hop_b
				5:
					var weave := Vector2(-dir.y, dir.x) * sin(_spawn_elapsed * 6.4 + float(get_instance_id() % 7)) * 0.42
					velocity = (dir + weave).normalized() * eff_spd
				_:
					velocity = dir * eff_spd
			_elite_skill_cd -= delta
			if _elite_skill_cd <= 0.0 and dist <= 360.0 and dist >= 75.0:
				if species == 0:
					var base_a := dir.angle()
					for off_a in [-0.24, 0.0, 0.24]:
						_fire_elite_orb(Vector2.from_angle(base_a + off_a), 235.0, maxf(10.0, contact_damage * 0.85), 11.0, Color(0.98, 0.34, 0.62, 1.0))
					_elite_skill_cd = 3.8
					if visual_node != null and visual_node.has_method("trigger_attack_lunge"):
						visual_node.trigger_attack_lunge(dir)
				elif species == 1:
					for k in range(4):
						_fire_elite_orb(Vector2.from_angle(dir.angle() + float(k) * (PI * 0.5)), 200.0, maxf(10.0, contact_damage * 0.8), 11.0, Color(0.24, 0.90, 0.78, 1.0))
					_elite_skill_cd = 4.2
					if visual_node != null and visual_node.has_method("trigger_attack_lunge"):
						visual_node.trigger_attack_lunge(dir)
				elif species == 4 and dist <= 240.0:
					if get_parent() != null:
						var slam := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
						if slam != null:
							slam.setup_circle_slam(self, target.global_position, 92.0, 0.78, maxf(14.0, contact_damage * 1.1), Color(0.36, 0.92, 0.56, 1.0))
					_elite_skill_cd = 4.6
					if visual_node != null and visual_node.has_method("trigger_land_impact"):
						visual_node.trigger_land_impact(1.1)
				else:
					var windup := 0.65
					var dash_len := 280.0
					var dash_w := 46.0
					match species:
						2:
							windup = 0.70
							dash_len = 310.0
							dash_w = 56.0
						3:
							windup = 0.50
							dash_len = 260.0
							dash_w = 44.0
						5:
							windup = 0.45
							dash_len = 250.0
							dash_w = 40.0
						6:
							windup = 0.52
							dash_len = 320.0
							dash_w = 48.0
					_elite_state = 1
					_elite_timer = windup
					_elite_windup_total = windup
					_elite_aim = dir
					if get_parent() != null:
						var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
						if atk != null:
							atk.setup_line_dash(self, global_position, _elite_aim, dash_len, dash_w, windup)
		1:
			velocity = Vector2.ZERO
			_elite_timer -= delta
			if _elite_timer <= 0.0:
				_elite_state = 2
				_elite_timer = 0.34 if species == 5 else (0.40 if species == 6 else 0.36)
				if visual_node != null and visual_node.has_method("trigger_attack_lunge"):
					visual_node.trigger_attack_lunge(_elite_aim)
		2:
			var dash_mult := 3.35 if species == 6 else (3.30 if species == 5 else (3.20 if species == 3 else 3.10))
			velocity = _elite_aim * (speed * dash_mult)
			_elite_timer -= delta
			if _elite_timer <= 0.0:
				if species == 6:
					for k in range(4):
						_fire_elite_orb(Vector2.from_angle(float(k) * (PI * 0.5) + PI * 0.25), 210.0, maxf(10.0, contact_damage * 0.75), 10.0, Color(1.0, 0.45, 0.14, 1.0))
				_elite_state = 0
				_elite_skill_cd = 3.8 if species == 5 else (4.6 if species == 6 else 5.2)

func apply_knockback(impulse: Vector2) -> void:
	if is_dead:
		return
	var resist := knockback_resistance
	if (_elite_state == 1 or _charger_state == 1) and dash_telegraph.has("windup_kb_resist"):
		resist = maxf(resist, float(dash_telegraph["windup_kb_resist"]))
	_knockback += impulse * (1.0 - clampf(resist, 0.0, 1.0))

func apply_slow(ratio: float, duration: float) -> void:
	if is_dead or ratio <= 0.0:
		return
	var slow_res := clampf(float(resistances.get("slow_resist", 0.0)), 0.0, 0.9)
	var effective_ratio := ratio * (1.0 - slow_res)
	if effective_ratio <= 0.0:
		return
	var cap := 0.20 if is_boss else 0.55
	_slow_ratio = maxf(_slow_ratio, minf(cap, effective_ratio))
	_slow_timer = maxf(_slow_timer, duration)

func apply_stun(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	_stun_timer = maxf(_stun_timer, duration)
	if enemy_type == Type.ELITE and _elite_state == 2:
		_elite_state = 0
		_elite_skill_cd = 3.5
	velocity = Vector2.ZERO
	modulate = Color(1.4, 1.3, 0.7, 1.0)

func apply_freeze(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	var freeze_sec := duration
	if is_boss:
		freeze_sec = minf(duration, BOSS_FREEZE_MAX_SEC)
		_slow_ratio = maxf(_slow_ratio, BOSS_FREEZE_SLOW_RATIO)
		_slow_timer = maxf(_slow_timer, maxf(0.0, duration - freeze_sec))
	_freeze_timer = maxf(_freeze_timer, freeze_sec)
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	if enemy_type == Type.ELITE and _elite_state == 2:
		_elite_state = 0
		_elite_skill_cd = 3.5
	_show_freeze_marker()

func is_frozen() -> bool:
	return _freeze_timer > 0.0

func unfreeze() -> void:
	if _freeze_timer > 0.0:
		_freeze_timer = 0.0
		_clear_freeze_visual()

func _show_freeze_marker() -> void:
	if _freeze_marker != null and is_instance_valid(_freeze_marker) and not _freeze_marker.is_queued_for_deletion():
		_freeze_marker.visible = true
		return
	var host := visual_node if visual_node != null else self
	_freeze_marker = Node2D.new()
	_freeze_marker.name = "FreezeMarker"
	_freeze_marker.set_script(FREEZE_MARKER_SCRIPT)
	host.add_child(_freeze_marker)
	if _freeze_marker.has_method("setup"):
		_freeze_marker.setup(self)

func _clear_freeze_visual() -> void:
	if _freeze_marker != null and is_instance_valid(_freeze_marker):
		_freeze_marker.queue_free()
	_freeze_marker = null
	if visual_node != null and not is_visual_culled and not is_dying_anim:
		visual_node.set_process(true)

func _get_pillars() -> Array:
	if _cached_bg == null or not is_instance_valid(_cached_bg):
		var tree := get_tree()
		if tree != null:
			_cached_bg = tree.get_first_node_in_group("background")
	if _cached_bg != null and _cached_bg.has_method("get_pillars"):
		return _cached_bg.get_pillars()
	return []

func apply_vulnerability(mult: float, dur: float) -> void:
	# 全场唯一易伤倍率：取较高值、刷新时长、不叠乘
	damage_taken_mult = maxf(damage_taken_mult, clampf(mult, 1.0, 1.5))
	_vuln_timer = maxf(_vuln_timer, dur)

func apply_detonate_mark(dur: float, radius: float, max_hp_pct: float, dmg_cap: float) -> void:
	_detonate_mark_timer = maxf(_detonate_mark_timer, dur)
	_detonate_mark_radius = radius
	_detonate_mark_pct = max_hp_pct
	_detonate_mark_cap = maxf(_detonate_mark_cap, dmg_cap)

func interrupt_charge_windup() -> void:
	if _charger_state == 1:
		_charger_state = 0
		_charger_timer = 0.0
		_charger_cd = maxf(_charger_cd, 1.6)
	if _elite_state == 1:
		_elite_state = 0
		_elite_timer = 0.0
		_elite_skill_cd = maxf(_elite_skill_cd, 2.0)

func apply_shield_chunk_damage(max_shield_pct: float, flat_min: float = 0.0) -> float:
	if is_dead or current_shield <= 0.0 or max_shield <= 0.0:
		return 0.0
	var chunk: float = maxf(flat_min, max_shield * clampf(max_shield_pct, 0.0, 1.0))
	var dealt: float = minf(current_shield, chunk)
	current_shield = maxf(0.0, current_shield - dealt)
	if current_shield <= 0.0:
		_on_shield_broken()
	if is_boss:
		get_tree().call_group("game_manager", "update_boss_hp", current_health, max_health, current_shield, max_shield)
	return dealt

func _on_shield_broken() -> void:
	_shield_break_flash = 0.35
	_stun_timer = maxf(_stun_timer, 0.55)
	interrupt_charge_windup()
	apply_vulnerability(1.25, 3.0)
	if target != null and is_instance_valid(target) and "v2_combat" in target and target.v2_combat != null:
		target.v2_combat._spawn_text_popup(global_position + Vector2(0.0, -34.0), "破罡！", Color(0.95, 0.98, 1.0))
		target.v2_combat.play_v2_cue("sfx_react_shatter", "reaction", 1.12)

func apply_dot(dps: float, dur: float, spread_on_death: bool = false, elem: String = "") -> void:
	if is_dead or dps <= 0.0:
		return
	_dot_dps = maxf(_dot_dps, dps)
	_dot_timer = maxf(_dot_timer, dur)
	if not elem.is_empty():
		_dot_elem = elem
	if spread_on_death:
		_dot_spread_on_death = true

func detonate_remaining_dot(pct: float) -> float:
	if _dot_timer <= 0.0 or _dot_dps <= 0.0:
		return 0.0
	var p := clampf(pct, 0.0, 1.0)
	var bonus := _dot_dps * _dot_timer * p
	_dot_timer *= (1.0 - p)
	return bonus

func apply_soul_seal(dps: float, dur: float, spread_r: float = 110.0, max_targets: int = 3) -> void:
	if is_dead or dps <= 0.0:
		return
	_soul_seal_active = true
	_soul_seal_dps = dps
	_soul_seal_radius = maxf(40.0, spread_r)
	_soul_seal_targets = clampi(max_targets, 1, 3)
	apply_dot(dps, dur, false, "venom")

func has_soul_seal() -> bool:
	return _soul_seal_active and _dot_timer > 0.0

func is_burning() -> bool:
	return _dot_timer > 0.0 and _dot_elem == "fire"

func is_poisoned() -> bool:
	return _dot_timer > 0.0 and (_dot_elem == "wood" or _dot_elem == "venom")

func get_dot_info() -> Dictionary:
	return {
		"dps": _dot_dps,
		"remaining": _dot_timer,
		"elem": _dot_elem,
	}

func set_active_element(elem: String, dur: float = 3.5) -> void:
	_active_elem = elem
	_elem_timer = dur if not elem.is_empty() else 0.0
	if visual_node != null and visual_node.has_method("set_active_element"):
		visual_node.set_active_element(elem)

func _spawn_damage_number(amount: float, is_crit: bool = false) -> void:
	if amount < 1.0:
		return
	if ObjectPools.active_count(DAMAGE_NUMBER_SCENE) >= 40:
		return
	var num = ObjectPools.acquire(DAMAGE_NUMBER_SCENE, get_parent())
	if num == null:
		return
	num.global_position = global_position + Vector2(randf_range(-10.0, 10.0), -18.0)
	if num.has_method("setup"):
		num.setup(amount, is_crit)

func get_element_damage_mult(element: String) -> float:
	if element.is_empty():
		return 1.0
	return float(element_multipliers.get(element, 1.0))

func take_damage(amount: float) -> void:
	take_damage_v2(amount, false, false, "")

func take_damage_v2(amount: float, is_crit: bool = false, _true_damage: bool = false, element: String = "", reaction_color: Color = Color(0.0, 0.0, 0.0, 0.0), is_dot: bool = false, shield_mult: float = 1.0) -> void:
	if is_dead:
		return
	var eff_dmg := maxf(1.0, amount * damage_taken_mult)
	var displayed_damage := eff_dmg
	if current_shield > 0.0:
		var s_mult := maxf(1.0, shield_mult)
		var shield_dmg := eff_dmg * s_mult
		if current_shield > shield_dmg:
			current_shield -= shield_dmg
			eff_dmg = 0.0
			displayed_damage = shield_dmg
		else:
			var broken_part := current_shield
			var overflow_raw := (shield_dmg - current_shield) / s_mult
			current_shield = 0.0
			_on_shield_broken()
			eff_dmg = overflow_raw
			displayed_damage = broken_part + overflow_raw
	if eff_dmg > 0.0:
		current_health -= eff_dmg
	if not is_visual_culled:
		_spawn_damage_number(displayed_damage, is_crit)

	if is_boss:
		get_tree().call_group("game_manager", "update_boss_hp", current_health, max_health, current_shield, max_shield)
		if boss_kit != null:
			boss_kit.on_hurt()
		if not _boss_enraged and current_health > 0.0 and current_health <= max_health * 0.50:
			_enter_boss_phase2()

	var is_reaction_hit := reaction_color.a > 0.01
	var hit_intensity := 1.55 if (is_crit and is_reaction_hit) else (1.42 if is_crit else (1.28 if is_reaction_hit else 0.78))
	var hit_dir := Vector2.RIGHT
	if target != null and is_instance_valid(target):
		var away := global_position - target.global_position
		if away.length_squared() > 0.001:
			hit_dir = away.normalized()

	if not is_visual_culled and Settings.get_bool("video/hit_flash"):
		var hit_spec := V2VfxFactory.get_hit_vfx_spec(element, reaction_color)
		var flash_dur := float(hit_spec.get("duration", 0.055)) * (1.25 if is_crit else 1.0)
		_last_hit_flash_key = String(hit_spec.get("key", "default"))
		_last_hit_flash_duration = flash_dur
		var flash_col: Color = hit_spec.get("flash_color", Color(1.75, 1.65, 1.45, 1.0)) as Color
		if is_crit:
			flash_col = Color(flash_col.r * 1.18, flash_col.g * 1.18, flash_col.b * 1.18, 1.0)
		modulate = flash_col
		if visual_node != null and visual_node.has_method("trigger_hit_pop"):
			visual_node.trigger_hit_pop(hit_intensity, hit_dir)
		if is_crit or is_reaction_hit:
			var stop_sec := 0.018 if is_boss else (0.045 if (is_crit and is_reaction_hit) else 0.032)
			_hitstop_timer = maxf(_hitstop_timer, stop_sec)
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(self, "modulate", Color.WHITE, flash_dur)
		if get_parent() != null:
			V2VfxFactory.spawn_hit_spark(get_parent(), global_position + Vector2(0.0, -10.0), element, is_crit, reaction_color)

	if not is_dot and not is_visual_culled:
		HitFeel.on_hit(global_position + Vector2(0.0, -8.0), hit_dir, element, is_crit, int(enemy_type), current_health <= 0.0, get_parent())

	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	if _detonate_mark_timer > 0.0:
		var blast_r := _detonate_mark_radius
		var blast_dmg := minf(max_health * _detonate_mark_pct, maxf(12.0, _detonate_mark_cap))
		_detonate_mark_timer = 0.0
		var nearby := CombatGrid.query(global_position, blast_r)
		for other in nearby:
			if other == null or other == self or not is_instance_valid(other) or bool(other.get("is_dead")):
				continue
			if other.has_method("take_damage_v2"):
				# 传入空元素 ""杜绝二次反应套娃
				other.take_damage_v2(blast_dmg, false, false, "", Color(1.0, 0.48, 0.16), false)
		if target != null and is_instance_valid(target) and "v2_combat" in target and target.v2_combat != null and target.v2_combat.has_method("spawn_detonate_death_fx"):
			target.v2_combat.spawn_detonate_death_fx(global_position, blast_r)
	if elite_blast_delay > 0.0 and elite_blast_radius > 0.0:
		_spawn_elite_blast()
	_hitstop_timer = 0.0
	if visual_node != null:
		visual_node.position = Vector2.ZERO
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	Sfx.play_varied("enemy_die", -6.0)
	if not is_visual_culled and get_parent() != null:
		var death_col := Color(0.98, 0.56, 0.24, 1.0) if (is_boss or enemy_type == Type.ELITE) else Color(0.45, 0.92, 0.82, 1.0)
		if species == 6:
			death_col = Color(1.0, 0.44, 0.18, 1.0)
		elif species == 4 or species == 5:
			death_col = Color(0.36, 0.92, 0.56, 1.0)
		elif species == 0:
			death_col = Color(0.94, 0.36, 0.72, 1.0)
		V2VfxFactory.spawn_enemy_death_vfx(get_parent(), global_position, death_col, enemy_type == Type.ELITE, is_boss)

	if target != null and is_instance_valid(target) and "v2_combat" in target and target.v2_combat != null:
		var v2 = target.v2_combat
		if v2.reaction_engine != null:
			v2.reaction_engine.clear_enemy(get_instance_id())
		if _dot_spread_on_death:
			v2.spread_corpse_venom(global_position, _dot_dps)
		if _soul_seal_active and _dot_timer > 0.0 and v2.has_method("spread_soul_seal_venom"):
			v2.spread_soul_seal_venom(global_position, _soul_seal_dps, _soul_seal_radius, _soul_seal_targets)
		if v2.has_method("try_spawn_spirit_stone_drop"):
			v2.try_spawn_spirit_stone_drop(global_position, int(enemy_type), gold_value)
		if v2.has_method("try_spawn_qiankun_bag_drop"):
			v2.try_spawn_qiankun_bag_drop(global_position, int(enemy_type))

	if enemy_type != Type.MINION and not death_burst.is_empty() and get_parent() != null:
		var slam := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
		if slam != null:
			slam.persist_after_owner_death = true
			var r := float(death_burst.get("radius", 78.0))
			var dly := float(death_burst.get("delay_sec", 0.40))
			var dmg_m := float(death_burst.get("dmg_mult", 1.0))
			var b_col := Color.from_string(String(death_burst.get("color", "#85EB3D")), Color(0.52, 0.92, 0.24, 1.0))
			slam.setup_circle_slam(self, global_position, r, dly, maxf(10.0, contact_damage * dmg_m), b_col)

	for i in range(exp_gem_count):
		var gem = ObjectPools.acquire("res://scenes/exp_gem.tscn", get_parent())
		if gem != null:
			var offset = Vector2.ZERO
			if exp_gem_count > 1:
				var ang = randf() * TAU
				var dist = randf_range(8.0, 36.0)
				offset = Vector2(cos(ang), sin(ang)) * dist
			gem.global_position = global_position + offset
			if gem.has_method("setup_value"):
				gem.setup_value(exp_gem_value)

	get_tree().call_group("game_manager", "on_enemy_killed")
	if enemy_type == Type.ELITE:
		get_tree().call_group("game_manager", "on_elite_killed")

	if is_boss or is_mini_boss:
		if TREASURE_CHEST_SCENE != null and get_parent() != null:
			var chest = TREASURE_CHEST_SCENE.instantiate()
			chest.global_position = global_position
			get_parent().call_deferred("add_child", chest)

	if is_boss:
		get_tree().call_group("game_manager", "on_boss_killed")

	if enemy_type == Type.MINION and not is_visual_culled and is_inside_tree():
		_begin_death_anim()
	else:
		_release_to_pool()

func _spawn_elite_blast() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var delay := elite_blast_delay
	var rad := elite_blast_radius
	var dmg := elite_blast_damage
	var pos := global_position
	var tree := get_tree()
	var tele := SpawnTelegraph.new()
	tele.setup(pos, delay, rad, func(p: Vector2) -> void:
		if tree == null:
			return
		for pl in tree.get_nodes_in_group("player"):
			var node := pl as Node2D
			if node != null and node.global_position.distance_to(p) <= rad:
				node.call("take_damage", dmg)
	)
	parent.add_child(tele)

func _begin_death_anim() -> void:
	is_dying_anim = true
	_death_anim_elapsed = 0.0
	_death_anim_timer = DEATH_ANIM_DURATION
	_death_spin_dir = -1.0 if _knockback.x < -1.0 else 1.0
	set_physics_process(false)
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	if hurt_col_shape != null:
		hurt_col_shape.set_deferred("disabled", true)
	set_active_element("", 0.0)
	if visual_node != null:
		visual_node.set_process(false)
		visual_node.scale = Vector2.ONE
		visual_node.rotation = 0.0
	modulate = Color.WHITE
	set_process(true)

func despawn() -> void:
	if is_dead or not can_despawn or is_boss:
		return
	is_dead = true
	_release_to_pool()

func banish_by_wave_pulse(origin: Vector2, player_node: Node2D) -> Dictionary:
	if is_dead or is_boss:
		return {"banished": false, "gold": 0, "gems": 0}
	is_dead = true
	set_physics_process(false)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null

	var v2: Variant = null
	if player_node != null and is_instance_valid(player_node) and "v2_combat" in player_node:
		v2 = player_node.v2_combat
	if v2 != null and v2.reaction_engine != null:
		v2.reaction_engine.clear_enemy(get_instance_id())

	var bonus_gold := 0

	var gems_spawned := 0
	if get_parent() != null:
		for _i in range(exp_gem_count):
			var gem = ObjectPools.acquire("res://scenes/exp_gem.tscn", get_parent())
			if gem != null:
				var offset := Vector2.ZERO
				if exp_gem_count > 1:
					var ang := randf() * TAU
					offset = Vector2(cos(ang), sin(ang)) * randf_range(8.0, 28.0)
				gem.global_position = global_position + offset
				if gem.has_method("setup_value"):
					gem.setup_value(exp_gem_value)
				gems_spawned += 1

	var away := global_position - origin
	if away.length_squared() < 1.0:
		away = Vector2.from_angle(randf() * TAU)
	else:
		away = away.normalized()
	_banish_vel = away * 560.0
	_banish_timer = 0.25
	set_process(true)
	return {"banished": true, "gold": bonus_gold, "gems": gems_spawned}

func _release_to_pool() -> void:
	if _releasing:
		return
	_releasing = true
	is_dying_anim = false
	set_process(false)
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("bosses"):
		remove_from_group("bosses")
	if is_in_group("elite_enemies"):
		remove_from_group("elite_enemies")
	if visual_node != null:
		visual_node.scale = Vector2.ONE
		visual_node.rotation = 0.0
	modulate = Color.WHITE
	visible = false
	set_physics_process(false)
	call_deferred("_do_release")

func _do_release() -> void:
	ObjectPools.release(self)

func _enter_boss_phase2() -> void:
	_boss_enraged = true
	speed *= 1.22
	_boss_skill_cd = minf(_boss_skill_cd, 0.45)
	Sfx.play_boss_or_fallback("boss_roar", "thunder", -1.0, 0.78)
	get_tree().call_group("ui", "show_banner", "【首领狂暴 · 妖气暴走！】")
	if get_parent() != null:
		V2VfxFactory.spawn_boss_shockwave(get_parent(), global_position, 195.0, Color(0.98, 0.24, 0.20, 1.0), Color(1.0, 0.86, 0.34, 1.0), 0.55)
	if target != null and is_instance_valid(target) and target.has_method("shake_camera"):
		target.shake_camera(9.0)
	if boss_kit != null:
		boss_kit.on_phase2()
	if visual_node != null and visual_node.has_method("set_boss_state"):
		visual_node.set_boss_state(0.0, true)

func _process_boss_ai(delta: float) -> void:
	var to_player := target.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(1.0, dist)

	match _boss_state:
		BossState.CHASE:
			if boss_kit != null:
				boss_kit.update_chase(delta, dir, dist)
			else:
				_boss_dashing = false
				_boss_strafe_phase += delta * 2.4
				var perp := Vector2(-dir.y, dir.x) * sin(_boss_strafe_phase) * 0.28
				velocity = (dir + perp).normalized() * speed * (1.0 - _slow_ratio)
				_boss_skill_cd -= delta
				if visual_node != null and visual_node.has_method("set_boss_state"):
					visual_node.set_boss_state(0.0, _boss_enraged)
				if _boss_skill_cd <= 0.0 and dist <= 650.0:
					_begin_boss_skill(dir)

		BossState.WINDUP:
			_boss_dashing = false
			var pull_ratio := clampf(_boss_state_timer / maxf(0.1, _boss_windup_total), 0.0, 1.0)
			velocity = -_boss_aim_dir * 42.0 * pull_ratio
			_boss_state_timer -= delta
			var ratio := clampf(1.0 - _boss_state_timer / maxf(0.1, _boss_windup_total), 0.0, 1.0)
			if visual_node != null and visual_node.has_method("set_boss_state"):
				visual_node.set_boss_state(ratio, _boss_enraged)
			if _boss_state_timer <= 0.0:
				_execute_boss_skill()

		BossState.ACTION:
			_boss_state_timer -= delta
			if _boss_active_skill == "dash":
				_boss_dashing = true
				velocity = _boss_aim_dir * (680.0 if _boss_enraged else 580.0)
				_boss_dash_ghost_cd -= delta
				if _boss_dash_ghost_cd <= 0.0 and get_parent() != null and visual_node != null:
					_boss_dash_ghost_cd = 0.06
					_emit_boss_dash_ghost()
			else:
				_boss_dashing = false
				velocity = Vector2.ZERO
			if boss_kit != null:
				boss_kit.update_action(delta)
			if _boss_state_timer <= 0.0:
				_finish_boss_skill()

		BossState.RECOVER:
			_boss_dashing = false
			velocity = dir * speed * 0.45
			_boss_state_timer -= delta
			if visual_node != null and visual_node.has_method("set_boss_state"):
				visual_node.set_boss_state(0.0, _boss_enraged)
			if _boss_state_timer <= 0.0:
				_boss_state = BossState.CHASE
				_boss_skill_cd = float(boss_kit.skill_cooldown()) if boss_kit != null else (1.05 if _boss_enraged else 1.65)

func _begin_boss_skill(dir_to_player: Vector2) -> void:
	if boss_kit == null:
		return
	boss_kit.begin(dir_to_player)

func _execute_boss_skill() -> void:
	if boss_kit == null:
		return
	boss_kit.execute()

func _finish_boss_skill() -> void:
	if boss_kit == null:
		return
	boss_kit.finish()

func _create_boss_kit(sp: int) -> void:
	match sp:
		3:
			boss_kit = BossCauldronKit.new()
		4:
			boss_kit = BossCorpseKingKit.new()
		5:
			boss_kit = BossFoxDemonKit.new()
		6:
			boss_kit = BossSwordMasterKit.new()
		_:
			boss_kit = BossKit.new()
	boss_kit.setup(self)

func _spawn_boss_circle_at(world_pos: Vector2, rad: float, windup: float, dmg: float, primary: Color = Color(0.98, 0.24, 0.22, 1.0)) -> void:
	if get_parent() == null:
		return
	var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
	if atk != null:
		atk.setup_circle_slam(self, world_pos, rad, windup, dmg, primary)

func summon_boss_minions(minion_species: int, count: int) -> void:
	if get_parent() == null:
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var room := maxi(0, 60 - alive)
	count = mini(count, room)
	for i in range(count):
		var ang := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.2, 0.2)
		var add_e = ObjectPools.acquire("res://scenes/enemy.tscn", get_parent(), 250)
		if add_e != null:
			add_e.global_position = global_position + Vector2(cos(ang), sin(ang)) * 78.0
			add_e.setup_type(Type.MINION, _spawn_elapsed, minion_species)
			var sp := get_tree().get_first_node_in_group("spawner")
			if sp != null and sp.has_method("scale_spawned_minion"):
				sp.scale_spawned_minion(add_e)

func boss_teleport(pos: Vector2) -> void:
	var tree := get_tree()
	if tree != null:
		var sp := tree.get_first_node_in_group("spawner")
		if sp != null and sp.has_method("clamp_to_arena"):
			pos = sp.clamp_to_arena(pos)
	global_position = pos
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	reset_physics_interpolation()

func spawn_boss_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, rad: float, color: Color, slow_ratio: float = 0.0, slow_dur: float = 0.0) -> void:
	if get_parent() == null:
		return
	var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
	if atk == null:
		return
	atk.setup_projectile(self, pos, dir, spd, dmg, rad, color)
	atk.slow_ratio = slow_ratio
	atk.slow_dur = slow_dur

func spawn_boss_line_from(pos: Vector2, dir: Vector2, dash_len: float, dash_w: float, windup: float) -> void:
	if get_parent() == null:
		return
	var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
	if atk == null:
		return
	atk.setup_line_dash(self, pos, dir, dash_len, dash_w, windup)

func emit_boss_ghost() -> void:
	_emit_boss_dash_ghost()

func _summon_wolf_pack() -> void:
	Sfx.play_boss_or_fallback("boss_roar", "thunder", -2.0, 0.90)
	if get_parent() == null:
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var room := maxi(0, 60 - alive)
	var cnt := mini(4, room)
	for i in range(cnt):
		var ang := (float(i) / float(maxi(1, cnt))) * TAU + randf_range(-0.2, 0.2)
		var add_e = ObjectPools.acquire("res://scenes/enemy.tscn", get_parent(), 250)
		if add_e != null:
			add_e.global_position = global_position + Vector2(cos(ang), sin(ang)) * 75.0
			add_e.setup_type(Type.MINION, _spawn_elapsed, 0)
			var sp := get_tree().get_first_node_in_group("spawner")
			if sp != null and sp.has_method("scale_spawned_minion"):
				sp.scale_spawned_minion(add_e)
			add_e.speed *= 1.25

func _emit_boss_dash_ghost() -> void:
	if visual_node == null or get_parent() == null:
		return
	var tex: Texture2D = visual_node.get("TEX_WOLF_SHEET") as Texture2D
	var d_rect := Rect2(-94.0, -168.0, 188.0, 188.0)
	var s_rect := Rect2(0.0, 0.0, 220.0, 220.0)
	if species == 1:
		tex = visual_node.get("TEX_DOLL_SHEET") as Texture2D
		d_rect = Rect2(-74.0, -142.0, 148.0, 148.0)
		s_rect = Rect2(0.0, 0.0, 96.0, 96.0)
	elif species == 2:
		tex = visual_node.get("TEX_ELITE_SHEET") as Texture2D
		d_rect = Rect2(-80.0, -142.0, 160.0, 160.0)
		s_rect = Rect2(0.0, 0.0, 128.0, 128.0)
	var fx := -1.0 if _boss_aim_dir.x < 0.0 else 1.0
	V2VfxFactory.spawn_boss_dash_ghost(get_parent(), global_position + Vector2(0.0, 36.0), tex, s_rect, d_rect, fx, Color(1.0, 0.42, 0.26, 0.55))

func _spawn_boss_dash_corridor(dash_len: float, dash_w: float, windup: float) -> void:
	if get_parent() == null:
		return
	var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
	if atk == null:
		return
	atk.setup_line_dash(self, global_position, _boss_aim_dir, dash_len, dash_w, windup)

func _spawn_boss_circles(count: int, rad: float, windup: float, dmg: float) -> void:
	if get_parent() == null or target == null or not is_instance_valid(target):
		return
	for i in range(count):
		var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
		if atk == null:
			continue
		var pos: Vector2 = target.global_position
		if i > 0:
			var ang := (float(i - 1) / float(maxi(1, count - 1))) * TAU + randf_range(-0.3, 0.3)
			pos += Vector2(cos(ang), sin(ang)) * randf_range(95.0, 175.0)
		atk.setup_circle_slam(self, pos, rad, windup, dmg)

func _fire_boss_volley() -> void:
	if get_parent() == null:
		return
	Sfx.play_boss_or_fallback("boss_roar", "sword_cast", -3.0, 0.82)
	var is_ring := (species == 1)
	var count := (14 if _boss_enraged else 10) if is_ring else (11 if _boss_enraged else 7)
	var base_ang := _boss_aim_dir.angle()
	var spread := TAU if is_ring else 1.45
	var spd := 360.0 if _boss_enraged else 305.0
	for i in range(count):
		var atk := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
		if atk == null:
			continue
		var ang: float = base_ang + (float(i) / float(count)) * TAU if is_ring else base_ang + (float(i) - float(count - 1) * 0.5) * (spread / float(maxi(1, count - 1)))
		atk.setup_projectile(self, global_position, Vector2.from_angle(ang), spd, 18.0, 14.0)
	if _boss_enraged:
		var inner_cnt := 8 if is_ring else 5
		var inner_spd := 250.0
		for j in range(inner_cnt):
			var atk2 := ObjectPools.acquire_script("boss_attack", BossAttack, get_parent(), 96) as BossAttack
			if atk2 == null:
				continue
			var ang2: float = base_ang + (float(j) + 0.5) / float(inner_cnt) * TAU if is_ring else base_ang + (float(j) - float(inner_cnt - 1) * 0.5) * (1.05 / float(maxi(1, inner_cnt - 1)))
			atk2.setup_projectile(self, global_position, Vector2.from_angle(ang2), inner_spd, 16.0, 13.0, Color(0.76, 0.24, 0.94, 1.0))
