extends Node

const OUT_DIR := "res://screenshots/"

func _ready() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in range(10):
		await get_tree().process_frame

	var player: Node2D = main.get_node("Player")
	player.exp_multiplier = 0.0
	player.damage_reduction = 1.0

	var enemy_scene := preload("res://scenes/enemy.tscn")

	# Spawn all 7 species in a handsome semi-circle / showcase line in front of the player
	var species_configs = [
		{"species": 0, "offset": Vector2(-160, -80), "aid": "enemy_kiter_fox"},
		{"species": 1, "offset": Vector2(-110, -110), "aid": "enemy_swarm_imp"},
		{"species": 2, "offset": Vector2(-50, -130), "aid": "enemy_charger_boar"},
		{"species": 3, "offset": Vector2(0, -90), "aid": "enemy_hopper_jiangshi"},
		{"species": 4, "offset": Vector2(60, -130), "aid": "enemy_bulwark_jinchan"},
		{"species": 5, "offset": Vector2(120, -110), "aid": "enemy_skitter_shenjing"},
		{"species": 6, "offset": Vector2(170, -80), "aid": "enemy_charger_huodou"}
	]

	for cfg in species_configs:
		var e: CharacterBody2D = enemy_scene.instantiate()
		e.global_position = player.global_position + cfg["offset"]
		main.add_child(e)
		if e.has_method("setup_type"):
			e.setup_type(Enemy.Type.MINION, 10.0, cfg["species"])
		e.archetype_id = cfg["aid"]

	# Run a few frames to let rigs, animations and auras update
	for i in range(30):
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var err := img.save_png(OUT_DIR + "showcase_all_monsters.png")
	if err == OK:
		print("SHOWCASE_SHOT_SAVED screenshots/showcase_all_monsters.png")
	else:
		print("SHOWCASE_SHOT_FAILED err=", err)

	get_tree().quit(0)
