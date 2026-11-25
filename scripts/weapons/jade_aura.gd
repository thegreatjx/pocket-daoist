extends Node2D
class_name JadeAura

# 净灵护体波 / 超武「净世莲台」：贴地透视青莲光环，震退减速妖物，超武击杀回血。
const TEX_AURA: Texture2D = preload("res://assets/sprites/fx_jade_lotus_aura.png")

var radius: float = 95.0
var damage: float = 16.0
var tick_interval: float = 0.62
var knockback: float = 70.0
var slow_ratio: float = 0.0
var crit_chance: float = 0.12
var crit_mult: float = 1.65
var is_evolved: bool = false
var owner_player: Node = null

var _tick_t: float = 0.0
var _anim_t: float = 0.0
var _pulse_flash: float = 0.0

func configure(rad: float, dmg: float, interval: float, kb: float, slow: float, evolved: bool, player: Node, crit_c: float = 0.12, crit_m: float = 1.65) -> void:
	radius = rad
	damage = dmg
	tick_interval = interval
	knockback = kb
	slow_ratio = slow
	is_evolved = evolved
	owner_player = player
	crit_chance = crit_c
	crit_mult = crit_m

func _physics_process(delta: float) -> void:
	_anim_t += delta
	if _pulse_flash > 0.0:
		_pulse_flash = maxf(0.0, _pulse_flash - delta * 3.5)
	_tick_t += delta
	if _tick_t >= tick_interval:
		_tick_t = 0.0
		_pulse_damage()
	queue_redraw()

func _pulse_damage() -> void:
	_pulse_flash = 1.0
	var healed := false
	var nearby := CombatGrid.query(global_position, radius + 40.0)
	var candidates: Array = nearby if not nearby.is_empty() else get_tree().get_nodes_in_group("enemies")
	for e in candidates:
		if not is_instance_valid(e) or e.is_dead:
			continue
		var dist := global_position.distance_to(e.global_position)
		if dist <= radius:
			var d := damage * (crit_mult if randf() < crit_chance else 1.0)
			e.take_damage(d)
			if slow_ratio > 0.0 and e.has_method("apply_slow"):
				e.apply_slow(slow_ratio, tick_interval + 0.35)
			if e.has_method("apply_knockback"):
				var away: Vector2 = (e.global_position - global_position).normalized() if dist > 1.0 else Vector2.RIGHT
				e.apply_knockback(away * knockback)
			if is_evolved and e.is_dead and not healed and owner_player != null and is_instance_valid(owner_player):
				healed = true
				if owner_player.has_method("heal"):
					owner_player.heal(2.0)
	for jar in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(jar) and jar.has_method("take_damage"):
			if global_position.distance_to(jar.global_position) <= radius:
				jar.take_damage(damage)

func _draw() -> void:
	var scale_pulse := 1.0 + _pulse_flash * 0.07 + sin(_anim_t * 3.0) * 0.025
	var sz := radius * 2.15 * scale_pulse
	var alpha := (0.58 if is_evolved else 0.44) + _pulse_flash * 0.18
	var tint := Color(1.0, 0.96, 0.72, alpha) if is_evolved else Color(0.92, 1.0, 0.98, alpha)
	# 贴地 2.5D 椭圆透视（先绕中心旋转，再纵向压扁贴地，不晃动）
	var rot_m := Transform2D(_anim_t * (0.45 if is_evolved else 0.25), Vector2.ZERO)
	var persp_m := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 0.74), Vector2(0.0, 14.0))
	draw_set_transform_matrix(persp_m * rot_m)
	if TEX_AURA != null:
		draw_texture_rect(TEX_AURA, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
