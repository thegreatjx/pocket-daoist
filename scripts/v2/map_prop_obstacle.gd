class_name MapPropObstacle
extends StaticBody2D

const FADE_ALPHA := 0.42

var collider_radius: float = 30.0
var _visual_w: float = 160.0
var _visual_h: float = 180.0
var _enable_occlusion_fade: bool = true
var _sprite: Sprite2D = null
var _player: Node2D = null
var _target_alpha: float = 1.0
var _shadow_rx: float = 42.0
var _shadow_ry: float = 17.0
var _shadow_x_off: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

func setup(tex: Texture2D, base_scale: float, flip_h: bool, collider_radius_override: float = -1.0) -> void:
	var tex_h := float(tex.get_height()) if tex != null else 256.0
	setup_sized(tex, tex_h * base_scale, 0.25, true, flip_h, collider_radius_override)

func setup_sized(
	tex: Texture2D,
	target_height: float,
	coll_ratio: float = 0.25,
	occlude: bool = true,
	flip_h: bool = false,
	collider_radius_override: float = -1.0
) -> void:
	setup_from_spec(tex, {
		"coll_rx": maxf(0.16, coll_ratio * 0.85),
		"occlude": occlude,
	}, target_height, flip_h, collider_radius_override)

func setup_from_spec(
	tex: Texture2D,
	spec: Dictionary,
	target_height: float,
	flip_h: bool = false,
	collider_radius_override: float = -1.0
) -> void:
	var tex_w := float(tex.get_width()) if tex != null else 256.0
	var tex_h := float(tex.get_height()) if tex != null else 256.0
	var base_scale := target_height / maxf(tex_h, 1.0)
	_visual_w = tex_w * base_scale
	_visual_h = target_height
	_enable_occlusion_fade = bool(spec.get("occlude", true))

	var foot_y_norm := clampf(float(spec.get("foot_y_norm", 0.92)), 0.50, 0.99)
	var foot_x_norm := float(spec.get("foot_x_norm", 0.0))
	var eff_x_norm := -foot_x_norm if flip_h else foot_x_norm
	var foot_x_px := -eff_x_norm * tex_w
	var foot_y_px := (0.5 - foot_y_norm) * tex_h

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.flip_h = flip_h
	_sprite.scale = Vector2(base_scale, base_scale)
	_sprite.offset = Vector2(foot_x_px, foot_y_px)
	add_child(_sprite)

	var shape_kind := String(spec.get("shape", "circle"))
	var coll_rx := float(spec.get("coll_rx", 0.20))
	var coll_ry := float(spec.get("coll_ry", 0.14))
	var col_x_off := eff_x_norm * _visual_w * 0.5
	_shadow_x_off = col_x_off

	var col := CollisionShape2D.new()
	if collider_radius_override > 0.0:
		collider_radius = collider_radius_override
		var cshape := CircleShape2D.new()
		cshape.radius = collider_radius
		col.shape = cshape
		col.position = Vector2(col_x_off, -collider_radius * 0.25)
	elif shape_kind == "capsule":
		var half_w := clampf(_visual_w * coll_rx, 24.0, 96.0)
		var half_d := clampf(_visual_h * coll_ry, 14.0, 44.0)
		var cap := CapsuleShape2D.new()
		cap.radius = half_d
		cap.height = maxf(half_d * 2.0, half_w * 2.0)
		col.shape = cap
		col.rotation = PI * 0.5
		col.position = Vector2(col_x_off, -half_d * 0.25)
		collider_radius = clampf(half_w * 0.85, 22.0, 64.0)
	else:
		collider_radius = clampf(_visual_w * coll_rx, 18.0, 56.0)
		var cshape := CircleShape2D.new()
		cshape.radius = collider_radius
		col.shape = cshape
		col.position = Vector2(col_x_off, -collider_radius * 0.25)

	if collider_radius_override == 0.0:
		col.disabled = true
	add_child(col)

	_shadow_rx = clampf(_visual_w * float(spec.get("shadow_rx", maxf(0.24, coll_rx * 1.25))), 20.0, 110.0)
	_shadow_ry = clampf(_visual_h * float(spec.get("shadow_ry", maxf(0.11, coll_ry * 1.15))), 10.0, 44.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not _enable_occlusion_fade or _sprite == null:
		return
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player") as Node2D
	if _player != null and is_instance_valid(_player):
		var p_pos := _player.global_position
		var g_pos := global_position
		var behind := (
			p_pos.y < g_pos.y - 6.0
			and p_pos.y > g_pos.y - _visual_h * 0.92
			and absf(p_pos.x - g_pos.x) < _visual_w * 0.44
		)
		_target_alpha = FADE_ALPHA if behind else 1.0
	else:
		_target_alpha = 1.0
	if not is_equal_approx(_sprite.modulate.a, _target_alpha):
		_sprite.modulate.a = move_toward(_sprite.modulate.a, _target_alpha, delta * 5.5)

func _draw() -> void:
	# 1. Soft directional cast shadow toward bottom-right (top-left 11 o'clock light source)
	draw_set_transform(Vector2(_shadow_x_off + _shadow_rx * 0.16, 4.0 + _shadow_ry * 0.20), 0.0, Vector2(1.05, _shadow_ry / maxf(1.0, _shadow_rx)))
	draw_circle(Vector2.ZERO, _shadow_rx, Color(0.03, 0.06, 0.05, 0.22))
	# 2. Tight contact shadow right under base
	draw_set_transform(Vector2(_shadow_x_off, 2.0), 0.0, Vector2(1.0, _shadow_ry / maxf(1.0, _shadow_rx)))
	draw_circle(Vector2.ZERO, _shadow_rx * 0.88, Color(0.02, 0.05, 0.04, 0.40))
	draw_circle(Vector2.ZERO, _shadow_rx * 0.62, Color(0.02, 0.04, 0.03, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
