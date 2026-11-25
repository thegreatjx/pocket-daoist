extends Node2D

const FX := preload("res://scripts/v2/v2_attack_fx.gd")


class DummyCtrl:
	extends Node

	func get_dot_mult() -> float:
		return 1.0

	func deal_v2_damage(_e: Node, _dmg: float, _elem: String, _opts: Dictionary) -> void:
		pass


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.49, 0.27, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -20
	add_child(bg)

	var ctrl := DummyCtrl.new()
	add_child(ctrl)

	var fx := FX.new()
	add_child(fx)
	fx.setup_burn_zone(
		ctrl,
		Vector2(380.0, 330.0),
		Vector2(380.0, 380.0),
		28.0,
		130.0,
		3.0,
		18.0,
		Color(1.0, 0.52, 0.18, 0.32),
		false,
		1.0,
		false,
		1.8
	)

	var fx2 := FX.new()
	add_child(fx2)
	fx2.setup_burn_zone(
		ctrl,
		Vector2(900.0, 330.0),
		Vector2(900.0, 380.0),
		28.0,
		130.0,
		3.0,
		18.0,
		Color(1.0, 0.52, 0.18, 0.32),
		false,
		1.0,
		true,
		1.8
	)

	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/fire_preview.png")
	print("SHOT fire_preview")
	get_tree().quit()
