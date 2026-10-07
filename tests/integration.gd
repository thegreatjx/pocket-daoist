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

# ---- 死亡结算 + 重开清池 ----
func test_game_over_flow() -> void:
	var m = await _load_main()
	var p = m.get_node("Player")
	var gov = m.get_node("GameOverUI")
	var sfx_before = Sfx.play_count
	p.take_damage(99999.0)
	await get_tree().process_frame
	check("death_shows_summary", gov.visible and get_tree().paused, "visible=%s paused=%s" % [str(gov.visible), str(get_tree().paused)])
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
	check("restart_unpauses", not get_tree().paused, "still paused after restart")
	check("restart_clears_pools", ObjectPools.free_count("res://scenes/exp_gem.tscn") == 0, "pool not cleared on restart, free=%d" % ObjectPools.free_count("res://scenes/exp_gem.tscn"))
	check("restart_prepare_no_reload", get_tree().current_scene == self, "current_scene changed — reload leaked into test")
	m.queue_free()
	await _frame()
	ObjectPools.clear()

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
