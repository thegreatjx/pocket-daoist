extends Node2D
class_name ExpGem

const TEX_GEM: Texture2D = preload("res://assets/sprites/exp_gem_jade.png")
const MAX_ACTIVE_GEMS := 120
const PICKUP_RADIUS := 36.0
const PICKUP_RADIUS_SQ := PICKUP_RADIUS * PICKUP_RADIUS

var exp_value: float = 6.0
var target: Node2D = null
var fly_speed: float = 40.0
var is_attracted: bool = false
var lifetime: float = 45.0
var _age: float = 0.0
var _anim_t: float = 0.0
var _drop_delay: float = 0.0
var _cached_player: Node2D = null
var _redraw_tick: int = 0

func _ready() -> void:
	add_to_group("exp_gems")

func setup_value(val: float) -> void:
	exp_value = maxf(1.0, val)
	queue_redraw()

func pool_acquire() -> void:
	exp_value = 6.0
	target = null
	fly_speed = 40.0
	is_attracted = false
	lifetime = 45.0
	_age = 0.0
	_anim_t = randf() * TAU
	_drop_delay = 0.10
	_redraw_tick = randi() % 3
	visible = true
	modulate = Color.WHITE
	_try_merge_excess()

func _try_merge_excess() -> void:
	var gems := get_tree().get_nodes_in_group("exp_gems")
	if gems.size() <= MAX_ACTIVE_GEMS:
		return
	var candidates: Array = []
	for g in gems:
		if g != self and is_instance_valid(g) and not g.is_attracted:
			candidates.append(g)
	candidates.sort_custom(func(a, b): return a._age > b._age)
	if candidates.size() < 2:
		return
	var anchor = candidates[0]
	for i in range(1, mini(10, candidates.size())):
		var g = candidates[i]
		anchor.exp_value += g.exp_value
		ObjectPools.release(g)
	anchor.queue_redraw()

func attract_to(player: Node2D) -> void:
	target = player
	is_attracted = true
	_drop_delay = 0.0
	fly_speed = maxf(fly_speed, 260.0)

func _collect_by(player: Node2D) -> void:
	if player.has_method("gain_exp"):
		player.gain_exp(exp_value)
	if "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.on_xp_orb_collected()
	else:
		Sfx.play_gem_pickup()
	ObjectPools.release(self)

func _physics_process(delta: float) -> void:
	_anim_t += delta
	_age += delta
	if _drop_delay > 0.0:
		_drop_delay = maxf(0.0, _drop_delay - delta)

	if target == null or not is_instance_valid(target):
		target = null
		is_attracted = false

	if is_attracted:
		var aim_pos := target.global_position + Vector2(0.0, -8.0)
		var dir = (aim_pos - global_position).normalized()
		fly_speed += 880.0 * delta
		global_position += dir * fly_speed * delta
		if _dist_sq_to_player_visual(target) <= 400.0:
			_collect_by(target)
			return
		queue_redraw()
		return

	if _drop_delay <= 0.0:
		if _cached_player == null or not is_instance_valid(_cached_player):
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				_cached_player = players[0]
		if _cached_player != null:
			var dist_sq := _dist_sq_to_player_visual(_cached_player)
			if dist_sq <= PICKUP_RADIUS_SQ:
				_collect_by(_cached_player)
				return
			var mag_r := float(_cached_player.get("magnet_radius"))
			if mag_r > PICKUP_RADIUS and dist_sq <= mag_r * mag_r:
				attract_to(_cached_player)

	_redraw_tick = (_redraw_tick + 1) % 3
	if _redraw_tick == 0:
		queue_redraw()

func _dist_sq_to_player_visual(p: Node2D) -> float:
	var d_feet := global_position.distance_squared_to(p.global_position + Vector2(0.0, 8.0))
	var d_body := global_position.distance_squared_to(p.global_position + Vector2(0.0, -18.0))
	return minf(d_feet, d_body)

func _draw() -> void:
	var bob := sin(_anim_t * 5.0) * 1.8
	var sz := 20.0
	var tint := Color.WHITE
	if exp_value >= 140.0:
		sz = 34.0
		tint = Color(1.0, 0.45, 0.35, 1.0)
		draw_circle(Vector2(0.0, bob), 18.0, Color(1.0, 0.36, 0.24, 0.28))
	elif exp_value >= 40.0:
		sz = 28.0
		tint = Color(0.86, 0.56, 1.0, 1.0)
	elif exp_value >= 12.0:
		sz = 24.0
		tint = Color(1.0, 0.88, 0.45, 1.0)

	if TEX_GEM != null:
		draw_texture_rect(TEX_GEM, Rect2(-sz * 0.5, -sz * 0.5 + bob, sz, sz), false, tint)
	else:
		draw_circle(Vector2(0, bob), 5.0, Color(0.28, 0.92, 0.72, 0.95))
