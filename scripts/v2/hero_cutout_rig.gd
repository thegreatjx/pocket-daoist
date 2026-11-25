class_name HeroCutoutRig
extends Node2D

@export var sprite_scale: float = 0.30
@export var walk_freq: float = 12.0
@export var leg_swing_rad: float = 0.38
@export var arm_swing_rad: float = 0.24

var _root_pivot: Node2D
var _shadow: Polygon2D
var _ribbons: Sprite2D
var _pants_full: Sprite2D
var _leg_l: Sprite2D
var _leg_r: Sprite2D
var _torso: Sprite2D
var _arm_l: Sprite2D
var _arm_r: Sprite2D
var _head: Sprite2D

var _torso_base_scale: float = 0.192
var _pants_base_scale: float = 0.1665
var _phase: float = 0.0
var _facing: float = 1.0
var _flash_timer: float = 0.0
var _invuln_timer: float = 0.0

func _ready() -> void:
	_build_hierarchy()

func _build_hierarchy() -> void:
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 7.5))
	_shadow.polygon = pts
	_shadow.color = Color(0.05, 0.06, 0.1, 0.35)
	_shadow.position = Vector2(0, 2)
	_shadow.z_index = -3
	add_child(_shadow)

	_root_pivot = Node2D.new()
	add_child(_root_pivot)

	_torso_base_scale = sprite_scale * 0.640
	_pants_base_scale = sprite_scale * 0.555

	_ribbons = _make_part("res://assets/v2/hero/hero_ribbons.png", Vector2(-16, -264) * sprite_scale, -2, 0.536, Vector2(-65, 90))
	_pants_full = _make_part("res://assets/v2/hero/hero_pants_full.png", Vector2(8, -60) * sprite_scale, -1, 0.555)
	_leg_l = _make_part("res://assets/v2/hero/hero_leg_l.png", Vector2(28, -106) * sprite_scale, -1, 0.535, Vector2(0, 88))
	_leg_r = _make_part("res://assets/v2/hero/hero_leg_r.png", Vector2(-14, -106) * sprite_scale, -1, 0.535, Vector2(0, 88))
	_leg_l.visible = false
	_leg_r.visible = false

	_arm_l = _make_part("res://assets/v2/hero/hero_arm_l.png", Vector2(24, -184) * sprite_scale, 0, 0.445, Vector2(52, 76))
	_arm_r = _make_part("res://assets/v2/hero/hero_arm_r.png", Vector2(-22, -184) * sprite_scale, 0, 0.455, Vector2(-48, 76))
	_torso = _make_part("res://assets/v2/hero/hero_torso.png", Vector2(4, -142) * sprite_scale, 1, 0.640)
	_head = _make_part("res://assets/v2/hero/hero_head.png", Vector2(8, -196) * sprite_scale, 3, 0.615, Vector2(0, -94))

func _make_part(tex_path: String, pos: Vector2, z: int, rel_sc: float = 1.0, pivot_offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	var sp := Sprite2D.new()
	if ResourceLoader.exists(tex_path):
		sp.texture = load(tex_path)
	sp.offset = pivot_offset
	var sc := sprite_scale * rel_sc
	sp.scale = Vector2(sc, sc)
	sp.position = pos
	sp.z_index = z
	_root_pivot.add_child(sp)
	return sp

func update_motion(velocity: Vector2, delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	var t10: float = 1.0 - exp(-10.0 * safe_delta)
	var t12: float = 1.0 - exp(-12.0 * safe_delta)
	var t18: float = 1.0 - exp(-18.0 * safe_delta)

	var speed: float = velocity.length()
	if absf(velocity.x) > 8.0:
		_facing = -1.0 if velocity.x < 0.0 else 1.0
	_root_pivot.scale.x = lerpf(_root_pivot.scale.x, _facing, t18)

	var moving: bool = speed > 12.0
	if moving:
		_pants_full.visible = false
		_leg_l.visible = true
		_leg_r.visible = true

		_phase += safe_delta * walk_freq
		var s: float = sin(_phase)
		var c: float = cos(_phase * 2.0)
		_leg_l.rotation = s * leg_swing_rad
		_leg_r.rotation = -s * leg_swing_rad
		_arm_l.rotation = -s * arm_swing_rad
		_arm_r.rotation = s * arm_swing_rad
		_root_pivot.position.y = -absf(s) * 4.5
		_torso.scale = Vector2(_torso_base_scale * (1.0 + c * 0.05), _torso_base_scale * (1.0 - c * 0.05))
		_torso.rotation = 0.06
		_head.rotation = sin(_phase - 0.5) * 0.06
		_ribbons.rotation = -0.18 + sin(_phase - 1.1) * 0.16
		_shadow.scale = Vector2(1.0 - absf(s) * 0.12, 1.0 - absf(s) * 0.12)
	else:
		_phase += safe_delta * 3.0
		var breath: float = sin(_phase)
		_leg_l.rotation = lerpf(_leg_l.rotation, 0.0, t12)
		_leg_r.rotation = lerpf(_leg_r.rotation, 0.0, t12)
		var legs_settled: bool = absf(_leg_l.rotation) < 0.04 and absf(_leg_r.rotation) < 0.04
		_pants_full.visible = legs_settled
		_leg_l.visible = not legs_settled
		_leg_r.visible = not legs_settled
		_pants_full.scale = Vector2(_pants_base_scale * (1.0 + breath * 0.015), _pants_base_scale * (1.0 - breath * 0.015))

		_arm_l.rotation = lerpf(_arm_l.rotation, breath * 0.05, t10)
		_arm_r.rotation = lerpf(_arm_r.rotation, -breath * 0.05, t10)
		_root_pivot.position.y = lerpf(_root_pivot.position.y, 0.0, t12)
		_torso.scale = Vector2(_torso_base_scale * (1.0 + breath * 0.025), _torso_base_scale * (1.0 - breath * 0.025))
		_torso.rotation = lerpf(_torso.rotation, 0.0, t10)
		_head.rotation = lerpf(_head.rotation, breath * 0.02, t10)
		_ribbons.rotation = lerpf(_ribbons.rotation, breath * 0.08, t10)
		_shadow.scale = _shadow.scale.lerp(Vector2.ONE, t12)

	if _flash_timer > 0.0:
		_flash_timer -= safe_delta
		modulate = Color(2.5, 2.5, 2.5, 1.0) if _flash_timer > 0.0 else Color.WHITE
	elif _invuln_timer > 0.0:
		_invuln_timer -= safe_delta
		if _invuln_timer <= 0.0:
			modulate = Color.WHITE
		else:
			modulate.a = 0.45 if int(_invuln_timer * 20.0) % 2 == 0 else 1.0
	else:
		modulate = Color.WHITE

func trigger_hurt_feedback(invuln_sec: float = 0.45) -> void:
	_flash_timer = 0.09
	_invuln_timer = invuln_sec
