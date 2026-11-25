extends Node
# 截图脚本：实机捕获标题页、战斗实景（含剑气/火莲/青莲光环/6+6槽位）、升级选卡（含超武提示）、天机宝箱超武进化、终章 Boss。

const OUT_DIR := "res://screenshots/"

func _ready() -> void:
	await _capture_title()
	await _capture_battle_and_boss()
	await _capture_upgrade()
	await _capture_chest_evo()
	get_tree().quit(0)

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)

func _capture_title() -> void:
	var scene := (load("res://scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	for i in range(25):
		await get_tree().process_frame
	await _save("title.png")
	scene.queue_free()
	await get_tree().process_frame

func _capture_battle_and_boss() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	for i in range(5):
		await get_tree().process_frame
	var stage: Node = main.get_node("StageDirector")
	var spawner: Node = main.get_node("Spawner")
	var player: Node = main.get_node("Player")
	player.exp_multiplier = 0.0
	player.damage_reduction = 1.0

	# 给玩家配几件核心武器与法宝，实景展示剑气、飞剑、红莲、青莲光环、6+6 HUD、青瓷罐与天机宝箱
	var wm: WeaponManager = player.weapon_mgr
	wm.add_or_upgrade_weapon("lotus_slash")
	wm.add_or_upgrade_weapon("flying_sword")
	wm.add_or_upgrade_weapon("fire_lotus")
	wm.add_or_upgrade_weapon("jade_aura")
	wm.add_or_upgrade_passive("sword_jade")
	wm.add_or_upgrade_passive("spirit_gourd")

	# 放一个青瓷灵罐和天机宝箱在视野附近方便验收外观
	var jar = (load("res://scenes/breakable_jar.tscn") as PackedScene).instantiate()
	jar.global_position = player.global_position + Vector2(-170, 95)
	main.add_child(jar)
	var chest = (load("res://scenes/treasure_chest.tscn") as PackedScene).instantiate()
	chest.global_position = player.global_position + Vector2(210, -110)
	main.add_child(chest)

	await get_tree().create_timer(3.2).timeout
	# 挥出一道青莲剑气定格截图
	wm.trigger_dash_slash(Vector2.RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("battle_ch1.png")

	# 走到地图最右边缘，验证左侧无黑屏且离屏宝箱指示箭头正常显示
	var orig_pos: Vector2 = player.global_position
	player.global_position = Vector2(1755.0, 260.0)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		cam.reset_smoothing()
	for _i in range(6):
		await get_tree().process_frame
	await _save("battle_edge.png")
	player.global_position = orig_pos
	if cam != null:
		cam.reset_smoothing()
	for _i in range(4):
		await get_tree().process_frame

	# 切到终章并召出仙狼王 Boss（无任何遮挡剧情卡）
	stage.chapter_index = 3
	stage.chapter_elapsed = 0.0
	stage._boss_spawned = false
	stage._advance_chapter()
	await get_tree().create_timer(0.3).timeout
	spawner.spawn_chapter_boss(stage.chapters[4])
	# 把 Boss 移进视野右上，方便看清外貌与血条
	var boss = spawner.get("_boss_instance")
	if boss != null and is_instance_valid(boss):
		boss.global_position = player.global_position + Vector2(260, -70)
	await get_tree().create_timer(0.8).timeout
	await _save("battle_ch6_boss.png")

	main.queue_free()
	await get_tree().process_frame
	ObjectPools.clear()

func _capture_upgrade() -> void:
	var panel := (load("res://scenes/upgrade_ui.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	panel.show_choices([
		{
			"id": "weapon:lotus_slash", "tag": "【剑诀】", "title": "青莲剑气",
			"desc": WeaponCatalog.weapon_level_desc("lotus_slash", 8),
			"level": 7, "next_level": 8, "max_level": 8,
			"icon": "res://assets/icons/icon_qingzhu_sword.png",
			"synergy_hint": WeaponCatalog.evolution_hint_for_weapon("lotus_slash"),
			"is_new": false, "is_relic": false, "is_evo": false,
		},
		{
			"id": "weapon:fire_lotus", "tag": "【符箓】", "title": "朱砂爆炎符",
			"desc": WeaponCatalog.weapon_level_desc("fire_lotus", 1),
			"level": 0, "next_level": 1, "max_level": 8,
			"icon": "res://assets/icons/icon_taiyi_talisman.png",
			"synergy_hint": WeaponCatalog.evolution_hint_for_weapon("fire_lotus"),
			"is_new": true, "is_relic": false, "is_evo": false,
		},
		{
			"id": "passive:sword_jade", "tag": "【法宝】", "title": "剑心玉佩",
			"desc": str(WeaponCatalog.get_passive("sword_jade")["desc"]),
			"level": 0, "next_level": 1, "max_level": 5,
			"icon": "res://assets/icons/relic_insight.png",
			"synergy_hint": WeaponCatalog.evolution_hint_for_passive("sword_jade"),
			"is_new": true, "is_relic": true, "is_evo": false,
		},
	], 0, 2, 2, 3)
	await get_tree().process_frame
	await _save("upgrade_panel.png")
	panel.queue_free()
	await get_tree().process_frame

func _capture_chest_evo() -> void:
	var cui := (load("res://scenes/chest_ui.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(cui)
	await get_tree().process_frame
	await get_tree().process_frame
	cui.show_rewards([{
		"is_evo": true,
		"title": "【超武质变】青莲剑歌",
		"subtitle": "青莲剑气 + 剑心玉佩 灵韵合一！",
		"desc": str(WeaponCatalog.get_weapon("lotus_slash")["evo_desc"]),
		"icon": "res://assets/icons/icon_qingzhu_sword.png",
	}])
	await get_tree().create_timer(0.32).timeout
	await _save("chest_evo.png")
	cui.queue_free()
	await get_tree().process_frame

func _save(file_name: String) -> void:
	_ensure_dir()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT_DIR + file_name
	var err := img.save_png(path)
	if err == OK:
		print("SHOT ", path)
	else:
		print("SHOT FAILED ", path, " err=", err)
