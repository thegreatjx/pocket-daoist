extends SceneTree

# 无头集成测试：验证 bug 修复行为
var passes: int = 0
var fails: int = 0
var fail_names: Array = []

func check(label: String, cond: bool, info: String = "") -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		fail_names.append(label)
		print("FAIL ", label, " :: ", info)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	test_enemy_mask()
	await test_sword_single_hit()
	await test_dash_keeps_attacking()
	await test_multilevel_queue()
	await test_enemy_cap_and_despawn()
	await test_gem_lifetime()
	await test_game_over_flow()
	test_upgrade_weight_and_prereq()
	test_font_cjk()
	await test_smoke_long_run()
	print("RESULT passes=", passes, " fails=", fails)
	if fails > 0:
		print("FAILED: ", ", ".join(fail_names))
	quit(1 if fails > 0 else 0)

func _load_main() -> Node:
	var scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	return scene

# ---- 0. 敌人之间不再物理碰撞（性能炸弹修复）----
func test_enemy_mask() -> void:
	var e = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	check("enemy_mask_no_enemy_layer", (e.collision_mask & 4) == 0, "mask=%d still collides with enemies" % e.collision_mask)
	check("enemy_mask_has_player", (e.collision_mask & 1) != 0, "mask=%d lost player layer" % e.collision_mask)
	e.free()

# ---- 1. 飞剑对同一敌人只结算一次伤害 ----
func test_sword_single_hit() -> void:
	var enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	root.add_child(enemy)
	enemy.max_health = 99999.0
	enemy.current_health = 99999.0
	enemy.speed = 0.0
	await physics_frame
	enemy.global_position = Vector2(300, 300)
	var hp0 = enemy.current_health

	var sw = (load("res://scenes/sword.tscn") as PackedScene).instantiate()
	root.add_child(sw)
	sw.setup(Vector2.RIGHT, 10.0, 600.0, 5)
	sw.global_position = Vector2(295, 300)
	for i in range(8):
		await physics_frame
	check("sword_single_hit", is_equal_approx(enemy.current_health, hp0 - 10.0), "hp delta=%.1f expect exactly 10" % (hp0 - enemy.current_health))
	sw.queue_free()
	enemy.queue_free()
	await process_frame

# ---- 2. 冲刺期间飞剑照常发射 ----
func test_dash_keeps_attacking() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	# 放一个近处敌人当靶子
	var enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	m.add_child(enemy)
	enemy.speed = 0.0
	enemy.global_position = p.global_position + Vector2(120, 0)

	p.is_dashing = true
	p.dash_timer = 5.0
	p.dash_direction = Vector2.ZERO
	p.sword_interval = 0.1
	p.sword_timer = 0.0
	var swords_before = count_swords(m)
	for i in range(30):
		await physics_frame
	check("dash_still_attacking", count_swords(m) > swords_before, "no sword spawned while dashing (before=%d after=%d)" % [swords_before, count_swords(m)])
	check("dash_still_dashing", p.is_dashing, "dash ended early")
	p.is_dashing = false
	m.queue_free()
	await process_frame

func count_swords(parent: Node) -> int:
	var n = 0
	for c in parent.get_children():
		# 不用 `c is Sword`：headless --script 运行时全局类名缓存可能未生成
		var s = c.get_script()
		if s != null and String(s.resource_path).ends_with("sword.gd") and not c.is_queued_for_deletion():
			n += 1
	return n

# ---- 3. 连升多级 -> 逐次弹出，卡片不叠加 ----
func test_multilevel_queue() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var uui = m.get_node("UpgradeUI")
	var cont = uui.get_node("Panel/CardContainer")

	var lvl_before = p.level
	p.current_exp = 0.0
	p.exp_to_next_level = 10.0
	p.gain_exp(1000.0)
	var level_ups = p.level - lvl_before
	check("multi_level_up_happened", level_ups >= 3, "only %d level ups" % level_ups)
	await process_frame

	check("queue_first_shown", uui.is_showing and paused, "showing=%s paused=%s" % [str(uui.is_showing), str(paused)])
	check("queue_pending_correct", m.pending_level_ups == level_ups - 1, "pending=%d expect=%d" % [m.pending_level_ups, level_ups - 1])
	check("queue_cards_3", cont.get_child_count() == 3, "cards=%d expect 3" % cont.get_child_count())

	# 连续选完全部升级机会，每次都必须恰好 3 张卡且无叠加
	var rounds = 0
	while uui.is_showing and rounds < level_ups + 2:
		cont.get_child(0).emit_signal("pressed")
		await process_frame
		rounds += 1
		if uui.is_showing:
			check("queue_cards_3_round%d" % rounds, cont.get_child_count() == 3, "cards=%d expect 3 (overlap bug)" % cont.get_child_count())
	check("queue_all_rounds_shown", rounds == level_ups, "rounds=%d expect=%d" % [rounds, level_ups])
	check("queue_done_unpaused", not uui.is_showing and not paused, "still showing/paused")
	m.queue_free()
	await process_frame

# ---- 4. 敌人上限 + 远处回收 ----
func test_enemy_cap_and_despawn() -> void:
	var m = await _load_main()
	var sp = m.get_node("Spawner")
	sp.max_enemies = 5
	sp.base_spawn_interval = 0.001
	sp.min_spawn_interval = 0.001
	var p = m.get_node("Player")
	p.speed = 0.0
	for i in range(400):
		await process_frame
	check("enemy_cap", get_nodes_in_group("enemies").size() <= 5, "enemies=%d expect <=5" % get_nodes_in_group("enemies").size())

	# 把敌人移到远处，直接触发回收逻辑
	var e = null
	for cand in get_nodes_in_group("enemies"):
		if is_instance_valid(cand):
			e = cand
			break
	check("have_enemy_to_test", e != null, "no enemy alive")
	if e != null:
		e.global_position = p.global_position + Vector2(9000, 0)
		sp._cleanup_far_enemies()
		await process_frame
		check("far_enemy_despawned", not is_instance_valid(e) or e.is_queued_for_deletion(), "far enemy survived cleanup")
	m.queue_free()
	await process_frame

# ---- 5. 灵气珠超时自毁 ----
func test_gem_lifetime() -> void:
	var gem = (load("res://scenes/exp_gem.tscn") as PackedScene).instantiate()
	root.add_child(gem)
	gem.lifetime = 0.25
	for i in range(45):
		await physics_frame
	check("gem_lifetime_freed", gem.is_queued_for_deletion() or not is_instance_valid(gem), "gem still alive after lifetime")

# ---- 6. 死亡 -> 结算面板暂停，重开恢复 ----
func test_game_over_flow() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var gov = m.get_node("GameOverUI")
	p.take_damage(99999.0)
	await process_frame
	check("death_shows_summary", gov.visible and paused, "visible=%s paused=%s" % [str(gov.visible), str(paused)])
	var stats = gov.get_node("PanelContainer/VBox/StatsLabel").text
	check("death_stats_filled", stats.length() > 10 and stats.contains("修行时长"), "stats=%s" % stats)
	# 死亡后无敌帧/重复死亡保护
	p.take_damage(99999.0)
	check("death_once_flag", m.is_game_over, "game over flag lost")
	gov.get_node("PanelContainer/VBox/RestartButton").emit_signal("pressed")
	await process_frame
	check("restart_unpauses", not paused, "still paused after restart")
	m.queue_free()
	await process_frame

# ---- 7. 升级加权抽取 + 进化前置 ----
func test_upgrade_weight_and_prereq() -> void:
	var mgr = Node.new()
	mgr.set_script(load("res://scripts/upgrade_manager.gd"))
	root.add_child(mgr)
	for i in range(60):
		for c in mgr.get_random_choices(3):
			check("evo_locked_hidden", c["id"] != "super_wanjian", "evo appeared without prereq")
	mgr.upgrades["sword_amount"]["level"] = 2
	var seen_evo = false
	for i in range(120):
		for c in mgr.get_random_choices(3):
			if c["id"] == "super_wanjian":
				seen_evo = true
	check("evo_unlocked_visible", seen_evo, "evo never appeared in 120 draws")
	var dup = false
	for i in range(60):
		var ids = {}
		for c in mgr.get_random_choices(3):
			if ids.has(c["id"]):
				dup = true
			ids[c["id"]] = true
	check("choices_unique", not dup, "duplicate id in one draw")
	# 全部满级时返回空，main.gd 应跳过而不冻结
	for id in mgr.upgrades.keys():
		mgr.upgrades[id]["level"] = mgr.upgrades[id]["max_level"]
	check("all_maxed_empty", mgr.get_random_choices(3).size() == 0, "non-empty when all maxed")
	mgr.queue_free()

# ---- 8. 中文字体全局生效 ----
func test_font_cjk() -> void:
	var f = ThemeDB.fallback_font
	var ok = f != null
	for ch in ["修", "仙", "境", "【", "诛", "魔"]:
		ok = ok and f.has_char(ch.unicode_at(0))
	check("font_cjk_glyphs", ok, "fallback font missing CJK glyphs")

# ---- 9. 长时运行冒烟：60 秒游戏时间无报错、敌人数量受控 ----
func test_smoke_long_run() -> void:
	var m = await _load_main()
	var peak = 0
	for i in range(3600):
		await process_frame
		var n = get_nodes_in_group("enemies").size()
		if n > peak:
			peak = n
	check("smoke_enemy_bounded", peak <= 250, "peak enemies=%d" % peak)
	check("smoke_survived", is_instance_valid(m), "main scene died during smoke run")
	m.queue_free()
	await process_frame
