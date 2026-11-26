class_name MapPropObstacle
extends StaticBody2D

const FADE_ALPHA := 0.42

var collider_radius: float = 30.0
var _visual_w: float = 160.0
var _visual_h: float = 180.0
var _sprite: Sprite2D = null
var _player: Node2D = null
var _target_alpha: float = 1.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

func setup(tex: Texture2D, base_scale: float, flip_h: bool, collider_radius_override: float = -1.0) -> void:
	var tex_w := float(tex.get_width()) if tex != null else 256.0
	var tex_h := float(tex.get_height()) if tex != null else 256.0
	_visual_w = tex_w * base_scale
	_visual_h = tex_h * base_scale
	collider_radius = collider_radius_override if collider_radius_override > 0.0 else clampf(_visual_w * 0.21, 24.0, 44.0)

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.flip_h = flip_h
	_sprite.scale = Vector2(base_scale, base_scale)
	var foot_pad := 12.0 if int(tex_h) == 512 else tex_h * 0.04
	_sprite.offset = Vector2(0.0, -tex_h * 0.5 + foot_pad)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collider_radius
	col.shape = shape
	col.position = Vector2(0.0, -collider_radius * 0.35)
	add_child(col)
	queue_redraw()

func _process(delta: float) -> void:
	if _sprite == null:
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
			and p_pos.y > g_pos.y - _visual_h * 0.95
			and absf(p_pos.x - g_pos.x) < _visual_w * 0.44
		)
		_target_alpha = FADE_ALPHA if behind else 1.0
	else:
		_target_alpha = 1.0
	if not is_equal_approx(_sprite.modulate.a, _target_alpha):
		_sprite.modulate.a = move_toward(_sprite.modulate.a, _target_alpha, delta * 6.0)

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.15, 0.42))
	draw_circle(Vector2.ZERO, maxf(24.0, collider_radius * 1.15), Color(0.04, 0.08, 0.07, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
