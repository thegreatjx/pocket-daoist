extends Node2D
class_name TreasureChest

const TEX_CHEST: Texture2D = preload("res://assets/props/treasure_chest.png")

var _anim_t: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("chests")

func _physics_process(delta: float) -> void:
	if _collected:
		return
	_anim_t += delta
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		if global_position.distance_to(players[0].global_position) <= 36.0:
			_collected = true
			get_tree().call_group("game_manager", "on_chest_collected")
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	var bob := sin(_anim_t * 4.8) * 3.0
	var glow_a := 0.28 + 0.12 * sin(_anim_t * 5.0)
	# 金色冲天指引光柱（淡柔不刺眼，方便满屏割草时一眼找到宝箱）
	draw_rect(Rect2(-14.0, -260.0, 28.0, 260.0), Color(1.0, 0.86, 0.36, glow_a * 0.35))
	draw_rect(Rect2(-6.0, -260.0, 12.0, 260.0), Color(1.0, 0.96, 0.72, glow_a * 0.55))
	draw_set_transform(Vector2(0.0, 16.0), 0.0, Vector2(1.0, 0.44))
	draw_circle(Vector2.ZERO, 24.0, Color(0.08, 0.18, 0.14, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, bob), 30.0, Color(1.0, 0.84, 0.32, glow_a))
	if TEX_CHEST != null:
		draw_texture_rect(TEX_CHEST, Rect2(-28.0, -34.0 + bob, 56.0, 56.0), false)
