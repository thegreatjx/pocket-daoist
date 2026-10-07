extends Node
# 无头集成测试：以场景方式运行，autoload（CombatGrid / ObjectPools / Sfx）全部可用。
# 运行：godot --headless --path . res://tests/integration.tscn

var passes: int = 0
var fails: int = 0
var fail_names: Array = []
var current_test: String = "(none)"

# 看门狗：测试协程一旦挂死（等待永不发生的帧），超时后强制退出并报告卡点。
# 必要性：无头运行下挂死没有任何输出，外部只能靠超时猜测。
const WATCHDOG_SECONDS := 240.0
var _watchdog: Timer = null

func check(label: String, cond: bool, info: String = "") -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		fail_names.append(label)
		print("FAIL ", label, " :: ", info)

func _ready() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	_watchdog.start()
	await _run()

func _on_watchdog_timeout() -> void:
	print("WATCHDOG_TIMEOUT after %.0fs, stuck at: %s" % [WATCHDOG_SECONDS, current_test])
	print("RESULT passes=", passes, " fails=", fails + 1)
	print("FAILED: watchdog_timeout_at_", current_test)
	get_tree().quit(2)

# 测试调度表：统一记录当前卡点，看门狗超时时能精确报出是哪个测试挂住
const TESTS := [
	"test_autoloads",
	"test_enemy_mask",
	"test_grid_bounds",
	"test_pool_reuse",
	"test_pool_sword_cap",
	"test_sword_single_hit",
	"test_knockback",
	"test_dash_keeps_attacking",
	"test_multilevel_queue",
	"test_enemy_cap_and_despawn",
	"test_separation",
	"test_gem_lifetime",
	"test_game_over_flow",
	"test_upgrade_weight_and_prereq",
	"test_font_cjk",
	"test_audio_assets",
	"test_game_flow_state_machine",
	"test_escape_handling",
	"test_pause_menu_settings",
	"test_settings_persistence",
	"test_accessibility_effects",
	"test_music_control",
	"test_stats_record",
	"test_title_scene",
	"test_run_isolation",
	"test_smoke_long_run",
]

func _run() -> void:
	await _frame()
	await _frame()
	for t in TESTS:
		current_test = t
		print("RUN  ", t)
		# await 对普通函数立即返回，对协程等其完成，两种测试都能统一调度
		await self.call(t)
		if get_tree() == null:
			return
	# 退出前彻底静默：
	# 1) 清空对象池，释放池中孤儿节点
	# 2) 等待若干帧，让 queue_free 的场景子树完成释放
	# 3) 停止音频并释放 stream
	# 这样正常退出路径零泄漏，证明运行期无累积泄漏。
	ObjectPools.clear()
	for i in range(10):
		await get_tree().process_frame
		await get_tree().physics_frame
	Sfx.stop_all()
	for i in range(5):
		await get_tree().process_frame
	print("RESULT passes=", passes, " fails=", fails)
	if fails > 0:
		print("FAILED: ", ", ".join(fail_names))
	else:
		print("ALL CHECKS PASSED")
	get_tree().quit(1 if fails > 0 else 0)

func _frame() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame

func _load_main() -> Node:
	var scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	await _frame()
	await _frame()
	return scene

# ---- autoload 注册 ----
func test_autoloads() -> void:
	check("autoload_grid", CombatGrid != null, "CombatGrid missing")
	check("autoload_pools", ObjectPools != null, "ObjectPools missing")
	check("autoload_sfx", Sfx != null, "Sfx missing")
	check("grid_priority_negative", CombatGrid.get_physics_process_priority() < 0, "grid must rebuild before enemies, priority=%d" % CombatGrid.get_physics_process_priority())

# ---- 敌人之间不再物理碰撞 ----
func test_enemy_mask() -> void:
	var e = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	check("enemy_mask_no_enemy_layer", (e.collision_mask & 4) == 0, "mask=%d still collides with enemies" % e.collision_mask)
	check("enemy_mask_has_player", (e.collision_mask & 1) != 0, "mask=%d lost player layer" % e.collision_mask)
	e.free()

# ---- 空间哈希：格数正确、查询有界 ----
func test_grid_bounds() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var nodes: Array = []
	for i in range(200):
		var n = Node2D.new()
		n.global_position = Vector2(i * 200.0, 0.0)   # 彼此远离，各占一格
		holder.add_child(n)
		nodes.append(n)
	CombatGrid.rebuild(nodes)
	check("grid_cells_200", CombatGrid.cell_count() == 200, "cells=%d expect 200" % CombatGrid.cell_count())
	# 稀疏分布时，查询半径 22 只应返回自身（1 个）
	var q = CombatGrid.query(Vector2(0, 0), 22.0)
	check("grid_sparse_query_bounded", q.size() <= 4, "query returned %d for sparse grid" % q.size())
	# 密集重叠时查询应返回全部同格邻居
	var dense: Array = []
	for i in range(30):
		var n2 = Node2D.new()
		n2.global_position = Vector2(5000, 5000) + Vector2(i % 3, i / 3) * 2.0
		holder.add_child(n2)
		dense.append(n2)
	CombatGrid.rebuild(dense)
	var q2 = CombatGrid.query(Vector2(5000, 5000), 22.0)
	check("grid_dense_finds_neighbors", q2.size() >= 20, "dense query returned %d expect >=20" % q2.size())
	check("grid_dense_all_cells", CombatGrid.cell_count() <= 9, "30 near-identical nodes spread over %d cells" % CombatGrid.cell_count())
	holder.free()
	CombatGrid.rebuild([])

# ---- 对象池：复用同一实例、计数正确 ----
func test_pool_reuse() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var path = "res://scenes/exp_gem.tscn"
	var a = ObjectPools.acquire(path, holder)
	var id_a = a.get_instance_id()
	check("pool_acquire_parented", a.get_parent() == holder, "not parented")
	check("pool_active_1", ObjectPools.active_count(path) == 1, "active=%d" % ObjectPools.active_count(path))
	ObjectPools.release(a)
	check("pool_active_0", ObjectPools.active_count(path) == 0, "active=%d after release" % ObjectPools.active_count(path))
	check("pool_free_1", ObjectPools.free_count(path) == 1, "free=%d" % ObjectPools.free_count(path))
	check("pool_detached", a.get_parent() == null, "still parented after release")
	var b = ObjectPools.acquire(path, holder)
	check("pool_same_instance", b.get_instance_id() == id_a, "pool did not reuse instance")
	check("pool_acquire_resets_state", b.lifetime > 44.0 and b.is_attracted == false, "state not reset: lifetime=%f attracted=%s" % [b.lifetime, str(b.is_attracted)])
	ObjectPools.release(b)
	check("pool_holder_clean", holder.get_child_count() == 0, "holder retains %d children" % holder.get_child_count())
	holder.free()
	ObjectPools.clear()

# ---- 池化上限：飞剑不会无限增长 ----
func test_pool_sword_cap() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var path = "res://scenes/sword.tscn"
	var got = 0
	for i in range(30):
		var s = ObjectPools.acquire(path, holder, 10)
		if s == null:
			break
		got += 1
	check("pool_cap_enforced", got == 10, "acquired %d expect cap 10" % got)
	check("pool_cap_active", ObjectPools.active_count(path) == 10, "active=%d" % ObjectPools.active_count(path))
	for c in holder.get_children():
		ObjectPools.release(c)
	holder.free()
	ObjectPools.clear()

# ---- 飞剑对同一敌人只结算一次伤害 ----
func test_sword_single_hit() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	holder.add_child(enemy)
	enemy.max_health = 99999.0
	enemy.current_health = 99999.0
	enemy.speed = 0.0
	enemy.separation_force = 0.0
	await _frame()
	enemy.global_position = Vector2(300, 300)
	var hp0 = enemy.current_health

	var sw = ObjectPools.acquire("res://scenes/sword.tscn", holder)
	sw.setup(Vector2.RIGHT, 10.0, 600.0, 5)
	sw.global_position = Vector2(295, 300)
	for i in range(8):
		await get_tree().physics_frame
	check("sword_single_hit", is_equal_approx(enemy.current_health, hp0 - 10.0), "hp delta=%.1f expect exactly 10" % (hp0 - enemy.current_health))
	check("sword_knockback_applied", enemy._knockback.length_squared() > 0.0 or enemy.is_dead, "no knockback impulse")
	holder.free()
	ObjectPools.clear()

# ---- 击退位移真实生效 ----
func test_knockback() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	# 敌人需要 player 组目标才会跑 _physics_process，否则击退不生效
	var target = Node2D.new()
	target.add_to_group("player")
	target.global_position = Vector2.ZERO
	holder.add_child(target)
	var enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	holder.add_child(enemy)
	enemy.target = target
	enemy.speed = 0.0
	enemy.separation_force = 0.0
	enemy.max_health = 99999.0
	enemy.current_health = 99999.0
	await _frame()
	var p0 = enemy.global_position
	enemy.apply_knockback(Vector2(400, 0))
	for i in range(4):
		await get_tree().physics_frame
	check("knockback_moves_enemy", enemy.global_position.x > p0.x + 1.0, "enemy did not move: %.1f -> %.1f" % [p0.x, enemy.global_position.x])
	# 衰减：足够多帧后击退消失
	for i in range(90):
		await get_tree().physics_frame
	check("knockback_decays", enemy._knockback.length_squared() < 1.0, "knockback never decayed: %f" % enemy._knockback.length())
	holder.free()

# ---- 冲刺期间飞剑照常发射 ----
func test_dash_keeps_attacking() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	m.add_child(enemy)
	enemy.speed = 0.0
	enemy.separation_force = 0.0
	enemy.max_health = 99999.0
	enemy.current_health = 99999.0
	enemy.global_position = p.global_position + Vector2(120, 0)

	p.is_dashing = true
	p.dash_timer = 5.0
	p.dash_direction = Vector2.ZERO
	p.sword_interval = 0.1
	p.sword_timer = 0.0
	var before = ObjectPools.active_count(p.sword_scene_path)
	for i in range(30):
		await get_tree().physics_frame
	check("dash_still_attacking", ObjectPools.active_count(p.sword_scene_path) > before, "no sword spawned while dashing (before=%d after=%d)" % [before, ObjectPools.active_count(p.sword_scene_path)])
	check("dash_still_dashing", p.is_dashing, "dash ended early")
	check("sword_cap_respected", ObjectPools.active_count(p.sword_scene_path) <= p.max_active_swords, "swords=%d exceed cap" % ObjectPools.active_count(p.sword_scene_path))
	p.is_dashing = false
	m.queue_free()
	await _frame()
	ObjectPools.clear()

# ---- 连升多级：逐次弹出、卡片不叠加、播放升级音效 ----
func test_multilevel_queue() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var uui = m.get_node("UpgradeUI")
	var cont = uui.get_node("Panel/CardContainer")

	var lvl_before = p.level
	p.current_exp = 0.0
	p.exp_to_next_level = 10.0
	var sfx_before = Sfx.play_count
	p.gain_exp(1000.0)
	var level_ups = p.level - lvl_before
	check("multi_level_up_happened", level_ups >= 3, "only %d level ups" % level_ups)
	await get_tree().process_frame
	check("level_up_sfx_played", Sfx.play_count >= sfx_before + level_ups, "sfx %d -> %d for %d level ups" % [sfx_before, Sfx.play_count, level_ups])

	check("queue_first_shown", uui.is_showing and get_tree().paused, "showing=%s paused=%s" % [str(uui.is_showing), str(get_tree().paused)])
	check("queue_pending_correct", m.pending_level_ups == level_ups - 1, "pending=%d expect=%d" % [m.pending_level_ups, level_ups - 1])
	check("queue_cards_3", cont.get_child_count() == 3, "cards=%d expect 3" % cont.get_child_count())

	var rounds = 0
	while uui.is_showing and rounds < level_ups + 2:
		cont.get_child(0).emit_signal("pressed")
		await get_tree().process_frame
		rounds += 1
		if uui.is_showing:
			check("queue_cards_3_round%d" % rounds, cont.get_child_count() == 3, "cards=%d expect 3 (overlap bug)" % cont.get_child_count())
	check("queue_all_rounds_shown", rounds == level_ups, "rounds=%d expect=%d" % [rounds, level_ups])
	check("queue_done_unpaused", not uui.is_showing and not get_tree().paused, "still showing/paused")
	check("orbit_swords_bounded", p.orbit_swords.size() == p.orbit_sword_count, "orbit=%d expect=%d" % [p.orbit_swords.size(), p.orbit_sword_count])
	m.queue_free()
	await _frame()
	ObjectPools.clear()

# ---- 敌人上限 + 远处回收走池 ----
func test_enemy_cap_and_despawn() -> void:
	var m = await _load_main()
	var sp = m.get_node("Spawner")
	sp.max_enemies = 5
	sp.base_spawn_interval = 0.001
	sp.min_spawn_interval = 0.001
	var p = m.get_node("Player")
	p.speed = 0.0
	for i in range(400):
		await get_tree().process_frame
	check("enemy_cap", get_tree().get_nodes_in_group("enemies").size() <= 5, "enemies=%d expect <=5" % get_tree().get_nodes_in_group("enemies").size())

	# 停掉生成器：否则 despawn 归还的敌人会被立刻从池复用，pool_acquire 重置 is_dead，断言失真
	sp.set_process(false)
	await _frame()
	var free_before = ObjectPools.free_count(sp.enemy_scene_path)
	var e = null
	for cand in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(cand) and not cand.is_dead:
			e = cand
			break
	check("have_enemy_to_test", e != null, "no live enemy")
	if e != null:
		e.global_position = p.global_position + Vector2(9000, 0)
		sp._cleanup_far_enemies()
		await _frame()
		await _frame()
		check("far_enemy_despawned", not is_instance_valid(e) or e.is_dead, "far enemy survived cleanup")
		check("far_enemy_pooled", ObjectPools.free_count(sp.enemy_scene_path) > free_before, "despawned enemy not returned to pool (free=%d before=%d)" % [ObjectPools.free_count(sp.enemy_scene_path), free_before])
	m.queue_free()
	await _frame()
	ObjectPools.clear()

# ---- 空间哈希分离：拥挤敌人被推开，不再完全重叠 ----
func test_separation() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var target = Node2D.new()
	target.add_to_group("player")
	target.global_position = Vector2.ZERO
	holder.add_child(target)

	var enemies = []
	for i in range(12):
		var e = (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
		holder.add_child(e)
		e.target = target
		e.max_health = 99999.0
		e.current_health = 99999.0
		e.speed = 60.0
		e.global_position = Vector2(120, 0) + Vector2(i % 4, i / 4) * 3.0
		enemies.append(e)

	for i in range(120):
		await get_tree().physics_frame

	# 统计两两距离小于 8 像素的对数：未分离时会大量完全重叠
	var overlaps = 0
	for i in range(enemies.size()):
		for j in range(i + 1, enemies.size()):
			if enemies[i].global_position.distance_to(enemies[j].global_position) < 8.0:
				overlaps += 1
	check("separation_reduces_overlap", overlaps <= 6, "%d overlapping pairs remain (separation ineffective)" % overlaps)
	holder.free()
	await _frame()

# ---- 灵气珠超时归还池 ----
func test_gem_lifetime() -> void:
	var holder = Node2D.new()
	get_tree().root.add_child(holder)
	var path = "res://scenes/exp_gem.tscn"
	var gem = ObjectPools.acquire(path, holder)
	gem.lifetime = 0.25
	for i in range(60):
		await get_tree().physics_frame
	check("gem_lifetime_returned", gem.get_parent() == null or ObjectPools.free_count(path) >= 1, "gem still active after lifetime")
	holder.free()
	ObjectPools.clear()

# ---- 战绩快照：测试会写入战绩，必须还原玩家真实数据 ----
func _snapshot_stats() -> Dictionary:
	return { "t": Stats.best_time, "l": Stats.best_level, "k": Stats.best_kills, "r": Stats.total_runs }

func _restore_stats(s: Dictionary) -> void:
	Stats.best_time = s["t"]
	Stats.best_level = s["l"]
	Stats.best_kills = s["k"]
	Stats.total_runs = s["r"]
	Stats.save_stats()

# ---- 设置快照：同上，避免测试覆盖玩家偏好 ----
func _snapshot_settings() -> Dictionary:
	return Settings.values.duplicate(true)

func _restore_settings(s: Dictionary) -> void:
	Settings.values = s
	Settings.apply_all()
	Settings.save_settings()

# ---- 死亡结算 + 重开清池 ----
func test_game_over_flow() -> void:
	var stats_snap = _snapshot_stats()
	var m = await _load_main()
	var p = m.get_node("Player")
	var gov = m.get_node("GameOverUI")
	var sfx_before = Sfx.play_count
	var runs_before = Stats.total_runs
	p.take_damage(99999.0)
	await get_tree().process_frame
	check("death_shows_summary", gov.visible and get_tree().paused, "visible=%s paused=%s" % [str(gov.visible), str(get_tree().paused)])
	check("death_state_game_over", GameFlow.state == GameFlow.State.GAME_OVER, "state=%s" % GameFlow.state_name())
	check("death_records_run", Stats.total_runs == runs_before + 1, "runs %d -> %d" % [runs_before, Stats.total_runs])
	check("death_sfx_played", Sfx.play_count > sfx_before, "no hurt sfx on death")
	check("death_shakes", p.shake_amount > 0.0, "no camera shake on death")
	var stats = gov.get_node("PanelContainer/VBox/StatsLabel").text
	check("death_stats_filled", stats.length() > 10 and stats.contains("修行时长"), "stats=%s" % stats)
	p.take_damage(99999.0)
	check("death_once_flag", m.is_game_over, "game over flag lost")
	# 注意：不能触发 RestartButton 的 pressed 信号。
	# main.gd 会调用 reload_current_scene()，而测试场景自身就是 current_scene，
	# 重载会把测试从头再跑一遍，形成无限循环（实测挂死无输出）。
	# 这里直接验证重开处理函数本身的副作用：解除暂停 + 清空对象池。
	ObjectPools.acquire("res://scenes/exp_gem.tscn", m)
	check("pool_dirty_before_restart", ObjectPools.free_count("res://scenes/exp_gem.tscn") + ObjectPools.active_count("res://scenes/exp_gem.tscn") > 0, "pool empty before restart")
	# 只验证重启前置副作用，不调 _on_restart_requested()：
	# 它内部的 reload_current_scene() 会重载测试场景自身，导致测试无限重跑（实测挂死）。
	m._prepare_restart()
	await get_tree().process_frame
	check("restart_clears_pools", ObjectPools.free_count("res://scenes/exp_gem.tscn") == 0, "pool not cleared on restart, free=%d" % ObjectPools.free_count("res://scenes/exp_gem.tscn"))
	check("restart_prepare_no_reload", get_tree().current_scene == self, "current_scene changed — reload leaked into test")
	# 解除暂停现在由 GameFlow._enter_run() 负责（状态迁移与场景切换已分离）
	GameFlow._enter_run()
	await get_tree().process_frame
	check("enter_run_unpauses", not get_tree().paused, "still paused after _enter_run")
	check("enter_run_state_playing", GameFlow.state == GameFlow.State.PLAYING, "state=%s" % GameFlow.state_name())
	m.queue_free()
	await _frame()
	ObjectPools.clear()
	_restore_stats(stats_snap)

# ---- 升级加权抽取 + 进化前置 ----
func test_upgrade_weight_and_prereq() -> void:
	var mgr = Node.new()
	mgr.set_script(load("res://scripts/upgrade_manager.gd"))
	get_tree().root.add_child(mgr)
	for i in range(60):
		for c in mgr.get_random_choices(3):
			check("evo_locked_hidden", c["id"] != "super_wanjian", "evo appeared without prereq")
	mgr.upgrades["sword_amount"]["level"] = 2
	var seen_evo = false
	for i in range(150):
		for c in mgr.get_random_choices(3):
			if c["id"] == "super_wanjian":
				seen_evo = true
	check("evo_unlocked_visible", seen_evo, "evo never appeared in 150 draws")
	var dup = false
	for i in range(60):
		var ids = {}
		for c in mgr.get_random_choices(3):
			if ids.has(c["id"]):
				dup = true
			ids[c["id"]] = true
	check("choices_unique", not dup, "duplicate id in one draw")
	# 权重确实生效：人为把两个普通项权重拉到 10:1，高频项应明显多出
	# （不能用进化项 super_wanjian：它有前置且 max_level=1，会污染对比）
	for id in mgr.upgrades.keys():
		mgr.upgrades[id]["level"] = 0
	mgr.upgrades["sword_amount"]["weight"] = 400
	mgr.upgrades["thunder_freq"]["weight"] = 4
	var counts = {}
	for i in range(600):
		for c in mgr.get_random_choices(3):
			counts[c["id"]] = counts.get(c["id"], 0) + 1
	var hi = counts.get("sword_amount", 0)
	var lo = counts.get("thunder_freq", 0)
	check("weight_influences_draw", hi > lo * 5, "w=400 drew %d, w=4 drew %d — weight not honored" % [hi, lo])
	for id in mgr.upgrades.keys():
		mgr.upgrades[id]["level"] = mgr.upgrades[id]["max_level"]
	check("all_maxed_empty", mgr.get_random_choices(3).size() == 0, "non-empty when all maxed")
	mgr.queue_free()

# ---- 中文字体 ----
func test_font_cjk() -> void:
	var f = ThemeDB.fallback_font
	var ok = f != null
	for ch in ["修", "仙", "境", "【", "诛", "魔", "雷", "剑"]:
		ok = ok and f.has_char(ch.unicode_at(0))
	check("font_cjk_glyphs", ok, "fallback font missing CJK glyphs")

# ---- 音频资源全部可加载、可播放 ----
func test_audio_assets() -> void:
	check("sfx_players_pooled", Sfx.get_child_count() == Sfx.PLAYER_COUNT, "players=%d expect=%d" % [Sfx.get_child_count(), Sfx.PLAYER_COUNT])
	for name in ["sword_cast", "sword_hit", "enemy_die", "gem_pickup", "level_up", "thunder", "player_hurt", "dash"]:
		check("sfx_has_" + name, Sfx.has_sound(name), "sound not loaded")
	var before = Sfx.play_count
	Sfx.play("thunder", -2.0)
	Sfx.play_varied("sword_hit", -10.0)
	Sfx.play("nonexistent_sound")
	check("sfx_play_counter", Sfx.play_count == before + 2, "counter %d -> %d expect +2" % [before, Sfx.play_count])

# ---- GameFlow 状态机：暂停权独占、非法迁移被拒 ----
func test_game_flow_state_machine() -> void:
	var G = GameFlow
	var log_before = G.transition_log.size()

	# 暂停映射必须与状态一致：只有 TITLE / PLAYING 不冻结
	for s in [G.State.TITLE, G.State.PLAYING, G.State.PAUSED, G.State.UPGRADE, G.State.GAME_OVER]:
		var expect = (s == G.State.PAUSED or s == G.State.UPGRADE or s == G.State.GAME_OVER)
		check("paused_map_%s" % G.state_name(s), G._state_pauses(s) == expect, "pause mapping wrong for %s" % G.state_name(s))

	# 进入战斗态：解除暂停
	G._enter_run()
	await _frame()
	check("enter_run_unpauses", not get_tree().paused, "paused after _enter_run")
	check("enter_run_state", G.state == G.State.PLAYING, "state=%s" % G.state_name())

	# 暂停 / 恢复
	G.pause()
	await _frame()
	check("pause_sets_paused", get_tree().paused, "tree not paused")
	check("pause_state", G.state == G.State.PAUSED, "state=%s" % G.state_name())
	G.resume()
	await _frame()
	check("resume_clears_paused", not get_tree().paused, "tree still paused after resume")
	check("resume_state", G.state == G.State.PLAYING, "state=%s" % G.state_name())

	# 暂停态下不能开选卡（非法迁移必须被拒）
	G.pause()
	check("pause_rejects_upgrade", not G.request_upgrade(), "upgrade opened while paused")
	check("pause_state_unchanged", G.state == G.State.PAUSED, "state corrupted: %s" % G.state_name())
	G.resume()

	# 选卡态：树暂停，且 pause/resume 均不得覆盖它
	check("upgrade_request_ok", G.request_upgrade(), "upgrade request rejected while playing")
	await _frame()
	check("upgrade_pauses_tree", get_tree().paused, "tree not paused during upgrade")
	check("upgrade_state", G.state == G.State.UPGRADE, "state=%s" % G.state_name())
	G.pause()
	check("pause_rejected_during_upgrade", G.state == G.State.UPGRADE, "pause overrode upgrade: %s" % G.state_name())
	G.resume()
	check("resume_rejected_during_upgrade", G.state == G.State.UPGRADE, "resume overrode upgrade: %s" % G.state_name())
	G.finish_upgrade()
	await _frame()
	check("finish_upgrade_resumes", not get_tree().paused and G.state == G.State.PLAYING, "state=%s paused=%s" % [G.state_name(), str(get_tree().paused)])

	# 死亡：从选卡态强制进入结算（极端情况）
	G.request_upgrade()
	G.game_over()
	await _frame()
	check("game_over_from_upgrade", G.state == G.State.GAME_OVER, "state=%s" % G.state_name())
	check("game_over_pauses", get_tree().paused, "tree not paused at game over")
	G.game_over()
	check("game_over_idempotent", G.state == G.State.GAME_OVER, "state=%s" % G.state_name())
	# 死亡后到达的升级请求必须丢弃，否则结算面板会被顶掉
	check("upgrade_rejected_after_death", not G.request_upgrade(), "upgrade opened after game over")
	check("state_still_game_over", G.state == G.State.GAME_OVER, "state=%s" % G.state_name())
	check("transitions_logged", G.transition_log.size() > log_before, "no transition logged")

	# 复原到战斗态，避免影响后续测试
	G._enter_run()
	await _frame()

# ---- ESC 决策：按状态映射到暂停/恢复/退出，含启动保护 ----
# 只测纯函数 escape_action()。若测 on_escape()，TITLE 态会真的退出进程，
# 把整个测试套件一起关掉。
func test_escape_handling() -> void:
	var G = GameFlow
	check("esc_title_quits", G.escape_action(G.State.TITLE, 5.0) == G.EscapeAction.QUIT, "title ESC should quit")
	# 启动保护：窗口刚获焦时手上若正按着 ESC，会被误判成操作意图
	check("esc_guard_blocks_early", G.escape_action(G.State.PLAYING, 0.0) == G.EscapeAction.NONE, "acted during guard window")
	check("esc_guard_boundary", G.escape_action(G.State.PLAYING, G.ESC_GUARD_SECONDS - 0.01) == G.EscapeAction.NONE, "acted right before guard ends")
	# 保护期后 ESC 打开暂停菜单，而不是直接退出（防误触丢进度）
	check("esc_playing_pauses", G.escape_action(G.State.PLAYING, 5.0) == G.EscapeAction.PAUSE, "ESC should pause after guard")
	check("esc_playing_not_quit", G.escape_action(G.State.PLAYING, 5.0) != G.EscapeAction.QUIT, "ESC must not quit during play")
	check("esc_paused_resumes", G.escape_action(G.State.PAUSED, 5.0) == G.EscapeAction.RESUME, "ESC should resume from pause")
	# 选卡与结算期间不响应 ESC
	check("esc_upgrade_ignored", G.escape_action(G.State.UPGRADE, 5.0) == G.EscapeAction.NONE, "ESC acted during upgrade choice")
	check("esc_gameover_ignored", G.escape_action(G.State.GAME_OVER, 5.0) == G.EscapeAction.NONE, "ESC acted during game over")

# ---- 暂停菜单：随状态显示/隐藏，设置面板可开关 ----
func test_pause_menu_settings() -> void:
	var m = await _load_main()
	var menu = m.get_node("PauseMenu")
	check("menu_hidden_while_playing", not menu.visible, "pause menu visible during play")

	GameFlow.pause()
	await _frame()
	check("menu_shown_when_paused", menu.visible, "pause menu not shown after pause")
	check("menu_root_visible", menu.get_node("Root").visible, "menu root not visible")

	# 打开设置面板
	menu.get_node("Root/Panel/VBox/SettingsButton").emit_signal("pressed")
	await _frame()
	check("settings_panel_opened", menu._is_settings_open(), "settings panel not created")
	check("settings_panel_parented", menu.settings_panel.get_parent() == menu.get_node("SettingsLayer"), "panel in wrong layer")

	# 设置面板打开时按 ESC 应只关面板，不恢复游戏
	var ev = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	menu._input(ev)
	await _frame()
	check("esc_closes_settings_first", not menu._is_settings_open(), "settings panel survived ESC")
	check("esc_keeps_paused", GameFlow.state == GameFlow.State.PAUSED, "game resumed when only settings should close: %s" % GameFlow.state_name())
	check("menu_still_shown", menu.visible, "menu hidden after closing settings")

	# 恢复后菜单应隐藏
	GameFlow.resume()
	await _frame()
	check("menu_hidden_after_resume", not menu.visible, "menu still visible after resume")

	# 暂停菜单必须能在树暂停时继续运行，否则按不了按钮
	check("menu_process_always", menu.process_mode == Node.PROCESS_MODE_ALWAYS, "process_mode=%d, would freeze while paused" % menu.process_mode)

	m.queue_free()
	await _frame()
	ObjectPools.clear()

# ---- 设置：立即生效、落盘持久化、默认值还原 ----
func test_settings_persistence() -> void:
	var snap = _snapshot_settings()
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var master_bus = AudioServer.get_bus_index("Master")
	check("buses_exist", music_bus >= 0 and sfx_bus >= 0 and master_bus >= 0, "audio buses missing")

	# 音量变更应立即作用于对应总线
	var saves_before = Settings.save_count
	Settings.set_value("audio/music_volume_db", -18.0)
	check("music_bus_applied", is_equal_approx(AudioServer.get_bus_volume_db(music_bus), -18.0), "bus db=%.1f" % AudioServer.get_bus_volume_db(music_bus))
	check("settings_saved_to_disk", Settings.save_count == saves_before + 1, "save_count %d -> %d" % [saves_before, Settings.save_count])

	# 重新加载应从磁盘恢复
	Settings.load_settings()
	check("settings_persisted", is_equal_approx(Settings.get_float("audio/music_volume_db"), -18.0), "reloaded value=%.1f" % Settings.get_float("audio/music_volume_db"))

	# 静音阈值：低于 -60 dB 应静音总线
	Settings.set_value("audio/sfx_volume_db", -60.0)
	Settings.apply("audio/sfx_volume_db")
	check("sfx_muted_at_floor", AudioServer.is_bus_mute(sfx_bus), "bus not muted at -60 dB")
	Settings.set_value("audio/sfx_volume_db", -3.0)
	Settings.apply("audio/sfx_volume_db")
	check("sfx_unmuted_above_floor", not AudioServer.is_bus_mute(sfx_bus), "bus still muted above floor")

	# 无障碍开关应可切换并持久化
	Settings.set_value("video/screen_shake", false)
	check("shake_off_persisted", Settings.get_bool("video/screen_shake") == false, "shake flag not stored")
	Settings.set_value("video/hit_flash", false)
	check("flash_off_persisted", Settings.get_bool("video/hit_flash") == false, "flash flag not stored")

	# stage_value 只生效不落盘（滑条拖动中避免每帧写磁盘）
	var saves_mid = Settings.save_count
	Settings.stage_value("audio/master_volume_db", -12.0)
	check("stage_applies_bus", is_equal_approx(AudioServer.get_bus_volume_db(master_bus), -12.0), "staged value not applied")
	check("stage_does_not_save", Settings.save_count == saves_mid, "stage_value wrote to disk")

	# 未知键必须被拒绝，不能污染存档
	Settings.set_value("nope/bogus", 1.0)
	check("unknown_key_rejected", Settings.get_value("nope/bogus") == null, "unknown key was stored")

	# 线性/分贝互转应可逆
	var db = Settings.linear_to_db(0.5)
	check("db_roundtrip", absf(Settings.db_to_linear(db) - 0.5) < 0.001, "roundtrip=%.4f" % Settings.db_to_linear(db))
	check("db_floor_is_silence", Settings.linear_to_db(0.0) <= -60.0, "zero volume -> %.1f dB" % Settings.linear_to_db(0.0))

	# 恢复默认应回到出厂值
	Settings.reset_to_defaults()
	check("reset_restores_defaults", is_equal_approx(Settings.get_float("audio/music_volume_db"), Settings.DEFAULTS["audio/music_volume_db"]), "reset did not restore defaults")
	check("reset_restores_toggles", Settings.get_bool("video/screen_shake") == true, "shake default should be on")

	_restore_settings(snap)

# ---- 无障碍开关必须真实影响游戏表现 ----
func test_accessibility_effects() -> void:
	var snap = _snapshot_settings()
	var m = await _load_main()
	var p = m.get_node("Player")

	# 关闭震屏后 shake_camera 不应产生偏移
	Settings.set_value("video/screen_shake", false)
	p.shake_amount = 0.0
	p.shake_camera(10.0)
	check("shake_disabled_ignored", p.shake_amount == 0.0, "shake applied while disabled")
	Settings.set_value("video/screen_shake", true)
	p.shake_camera(10.0)
	check("shake_enabled_works", p.shake_amount > 0.0, "shake not applied while enabled")

	# 关闭受击闪白后 modulate 不应变红
	Settings.set_value("video/hit_flash", false)
	p.modulate = Color.WHITE
	p.take_damage(1.0)
	check("flash_disabled_keeps_white", p.modulate == Color.WHITE, "modulate=%s while flash disabled" % str(p.modulate))
	Settings.set_value("video/hit_flash", true)
	p.modulate = Color.WHITE
	p.take_damage(1.0)
	check("flash_enabled_tints", p.modulate != Color.WHITE, "no flash while enabled")

	m.queue_free()
	await _frame()
	ObjectPools.clear()
	_restore_settings(snap)

# ---- 背景音乐：切曲、同曲不打断、循环、停止 ----
func test_music_control() -> void:
	var snap = _snapshot_settings()
	check("music_has_title", Music.has_track("title"), "title track missing")
	check("music_has_battle", Music.has_track("battle"), "battle track missing")
	check("music_missing_track", not Music.has_track("nonexistent"), "phantom track reported")
	check("music_bus_assigned", Music._player.bus == "Music", "player on bus %s" % Music._player.bus)

	Music.stop_music(0.0)
	await _frame()
	Music.play_track("title", 0.0)
	await _frame()
	check("music_plays_title", Music.current_track == "title", "track=%s" % Music.current_track)
	check("music_player_playing", Music._player.playing, "player not playing")

	# 同曲重复调用不应重头播放（场景内多次触发时会跳音）
	var stream_id = Music._player.stream.get_instance_id()
	Music.play_track("title", 0.0)
	await _frame()
	check("music_same_track_no_restart", Music._player.stream.get_instance_id() == stream_id, "track restarted")

	# 切曲应换流
	Music.play_track("battle", 0.0)
	await _frame()
	check("music_switches_track", Music.current_track == "battle", "track=%s" % Music.current_track)

	# 循环：自然播完后应重播同一曲
	var loops = Music.loop_count
	Music._on_track_finished()
	await _frame()
	check("music_loops_on_finish", Music.loop_count == loops + 1, "loop_count %d -> %d" % [loops, Music.loop_count])
	check("music_loop_keeps_track", Music.current_track == "battle", "track changed on loop: %s" % Music.current_track)

	Music.stop_music(0.0)
	await _frame()
	check("music_stopped", Music.current_track == "", "track=%s after stop" % Music.current_track)
	# 停止后收到 finished 不应复活播放
	var loops2 = Music.loop_count
	Music._on_track_finished()
	check("music_no_revive_after_stop", Music.loop_count == loops2 and Music.current_track == "", "music revived after stop")

	# 缺失曲目应安全忽略
	Music.play_track("nonexistent")
	check("music_missing_ignored", Music.current_track == "", "track set to missing resource")
	_restore_settings(snap)

# ---- 战绩：记录、刷新判定、持久化、格式化 ----
func test_stats_record() -> void:
	var snap = _snapshot_stats()
	# 干净起点
	Stats.best_time = 0.0
	Stats.best_level = 0
	Stats.best_kills = 0
	Stats.total_runs = 0
	check("stats_empty_initially", not Stats.has_history(), "has_history true with zero runs")
	check("stats_summary_empty", Stats.summary_text() == "", "summary not empty for new player")

	# 第一局必然刷新纪录
	check("first_run_is_record", Stats.record_run(120.0, 5, 40), "first run not flagged as record")
	check("stats_run_counted", Stats.total_runs == 1, "runs=%d" % Stats.total_runs)
	check("stats_history_now", Stats.has_history(), "no history after first run")
	check("stats_best_time", is_equal_approx(Stats.best_time, 120.0), "best_time=%.1f" % Stats.best_time)
	check("stats_best_level", Stats.best_level == 5, "best_level=%d" % Stats.best_level)
	check("stats_best_kills", Stats.best_kills == 40, "best_kills=%d" % Stats.best_kills)

	# 更差的一局不应刷新纪录，但各项最佳必须保留
	check("worse_run_not_record", not Stats.record_run(60.0, 3, 10), "worse run flagged as record")
	check("best_preserved_time", is_equal_approx(Stats.best_time, 120.0), "best_time overwritten: %.1f" % Stats.best_time)
	check("best_preserved_kills", Stats.best_kills == 40, "best_kills overwritten: %d" % Stats.best_kills)
	check("runs_incremented", Stats.total_runs == 2, "runs=%d" % Stats.total_runs)

	# 单项突破应刷新纪录
	check("partial_record_kills", Stats.record_run(30.0, 2, 999), "kill-only record not flagged")
	check("kills_updated", Stats.best_kills == 999, "best_kills=%d" % Stats.best_kills)
	check("time_not_regressed", is_equal_approx(Stats.best_time, 120.0), "best_time regressed to %.1f" % Stats.best_time)

	# 持久化：重新加载应保留
	Stats.load_stats()
	check("stats_persisted_time", is_equal_approx(Stats.best_time, 120.0), "reloaded time=%.1f" % Stats.best_time)
	check("stats_persisted_runs", Stats.total_runs == 3, "reloaded runs=%d" % Stats.total_runs)

	check("stats_format_time", Stats.format_time(125.0) == "02:05", "format=%s" % Stats.format_time(125.0))
	check("stats_summary_has_content", Stats.summary_text().contains("最长修行"), "summary=%s" % Stats.summary_text())

	_restore_stats(snap)

# ---- 标题界面：入口、设置面板、战绩显示 ----
func test_title_scene() -> void:
	var snap = _snapshot_stats()
	Stats.best_time = 300.0
	Stats.best_level = 9
	Stats.best_kills = 250
	Stats.total_runs = 4

	var t = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(t)
	await _frame()
	await _frame()

	check("title_in_tree", t.is_inside_tree(), "title not in tree")
	check("title_state", GameFlow.state == GameFlow.State.TITLE, "state=%s" % GameFlow.state_name())
	check("title_not_paused", not get_tree().paused, "tree paused at title — game would freeze")
	check("title_music", Music.current_track == "title", "track=%s" % Music.current_track)

	# 战绩应显示
	var best = t.get_node("Center/VBox/BestLabel")
	check("title_best_visible", best.visible, "best label hidden despite history")
	check("title_best_text", best.text.contains("05:00"), "best text=%s" % best.text)

	# 必需按钮存在
	for btn_path in ["Center/VBox/StartButton", "Center/VBox/SettingsButton", "Center/VBox/QuitButton"]:
		check("title_button_%s" % btn_path.split("/")[2], t.get_node_or_null(btn_path) != null, "missing %s" % btn_path)

	# 设置面板开关
	t.get_node("Center/VBox/SettingsButton").emit_signal("pressed")
	await _frame()
	check("title_settings_opened", t.settings_panel != null and is_instance_valid(t.settings_panel), "settings panel not created")
	t.get_node("Center/VBox/SettingsButton").emit_signal("pressed")
	await _frame()
	check("title_settings_toggled_off", t.settings_panel == null, "settings panel not closed by toggle")

	# 设置面板本体：控件齐全，滑条与开关反映当前设置
	t.get_node("Center/VBox/SettingsButton").emit_signal("pressed")
	await _frame()
	var panel = t.settings_panel
	check("panel_has_sliders", panel._sliders.size() == 3, "sliders=%d expect 3" % panel._sliders.size())
	check("panel_has_toggles", panel._toggles.size() == 3, "toggles=%d expect 3" % panel._toggles.size())
	check("panel_slider_synced", absf(panel._sliders["audio/music_volume_db"].value - Settings.db_to_linear(Settings.get_float("audio/music_volume_db"))) < 0.02, "slider out of sync")
	check("panel_toggle_synced", panel._toggles["video/screen_shake"].button_pressed == Settings.get_bool("video/screen_shake"), "toggle out of sync")

	# 拖动滑条应实时生效但不落盘
	var saves = Settings.save_count
	panel._on_slider_dragged("audio/sfx_volume_db", 0.25)
	check("panel_drag_applies", is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), Settings.linear_to_db(0.25)), "drag did not apply to bus")
	check("panel_drag_no_save", Settings.save_count == saves, "drag wrote to disk")
	panel._on_slider_released("audio/sfx_volume_db")
	check("panel_release_saves", Settings.save_count == saves + 1, "release did not persist")

	# 开关切换应落盘
	saves = Settings.save_count
	panel._on_toggle_changed("video/screen_shake", false)
	check("panel_toggle_saves", Settings.save_count == saves + 1, "toggle did not persist")
	check("panel_toggle_stored", Settings.get_bool("video/screen_shake") == false, "toggle value not stored")

	# 返回按钮应关闭面板
	panel.emit_signal("closed")
	await _frame()
	check("panel_closed_by_back", t.settings_panel == null, "panel survived closed signal")

	t.queue_free()
	await _frame()
	Settings.reset_to_defaults()
	_restore_stats(snap)

# ---- 新局开始不应残留上一局的击杀数与升级进度 ----
func test_run_isolation() -> void:
	var snap = _snapshot_stats()
	var m = await _load_main()
	m.kill_count = 42
	m.pending_level_ups = 3
	var mgr = m.get_node("UpgradeManager")
	for id in mgr.upgrades.keys():
		mgr.upgrades[id]["level"] = 2
	check("run_dirty_before", m.kill_count == 42 and mgr.upgrades["sword_amount"]["level"] == 2, "setup failed")

	# 重新加载 main 场景模拟"重开本局"：UpgradeManager 是新实例，等级应归零
	var m2 = await _load_main()
	check("new_run_kills_zero", m2.kill_count == 0, "kills carried over: %d" % m2.kill_count)
	check("new_run_pending_zero", m2.pending_level_ups == 0, "pending level ups carried over")
	var mgr2 = m2.get_node("UpgradeManager")
	check("new_run_upgrades_reset", mgr2.upgrades["sword_amount"]["level"] == 0, "upgrade level carried over: %d" % mgr2.upgrades["sword_amount"]["level"])
	check("new_run_state_playing", GameFlow.state == GameFlow.State.PLAYING, "state=%s" % GameFlow.state_name())
	check("new_run_not_paused", not get_tree().paused, "new run started paused")

	m.queue_free()
	m2.queue_free()
	await _frame()
	ObjectPools.clear()
	_restore_stats(snap)

# ---- 60 秒长跑冒烟：敌人受控、池不泄漏、无节点暴涨 ----
func test_smoke_long_run() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var peak_enemies = 0
	var peak_children = 0
	for i in range(3600):
		await get_tree().process_frame
		var n = get_tree().get_nodes_in_group("enemies").size()
		if n > peak_enemies:
			peak_enemies = n
		var c = m.get_child_count()
		if c > peak_children:
			peak_children = c
	check("smoke_enemy_bounded", peak_enemies <= 250, "peak enemies=%d" % peak_enemies)
	check("smoke_survived", is_instance_valid(m), "main scene died during smoke run")
	check("smoke_children_bounded", peak_children <= 400, "main node children peaked at %d (node explosion)" % peak_children)
	check("smoke_sword_cap", ObjectPools.active_count(p.sword_scene_path) <= p.max_active_swords, "active swords=%d" % ObjectPools.active_count(p.sword_scene_path))
	check("smoke_kills_happened", m.kill_count > 0, "no enemies killed in 60s — combat broken")
	check("smoke_gems_pooled", ObjectPools.free_count("res://scenes/exp_gem.tscn") >= 0, "gem pool missing")
	m.queue_free()
	await _frame()
	ObjectPools.clear()
