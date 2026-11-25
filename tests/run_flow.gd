extends Node
# 单关单首领跑通测试：加载真实 main.tscn，压缩单关时长并模拟玩家斩杀首领，
# 验证「关卡开启 → 首领出场 → 斩杀结算 → 标记通关 → 胜利面板」整条链路接通。
# 运行：godot --headless --path . res://tests/run_flow.tscn

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	await _run()

func _run() -> void:
	var stats_snap := {
		"best_time": Stats.best_time,
		"best_level": Stats.best_level,
		"best_kills": Stats.best_kills,
		"total_runs": Stats.total_runs,
		"spirit_stones": Stats.spirit_stones,
		"selected_stage_id": Stats.selected_stage_id,
		"cleared_stages": Stats.cleared_stages.duplicate(),
	}
	Stats.selected_stage_id = 1

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var player: Node = main.get_node("Player")
	var stage: Node = main.get_node("StageDirector")
	var spawner: Node = main.get_node("Spawner")
	var ui: Node = main.get_node("UI")
	var game_over_ui: Node = main.get_node("GameOverUI")

	var started: Array[int] = []
	var boss_hp: Array[float] = []
	var cleared: Array[int] = []
	stage.chapter_started.connect(func(ch: Dictionary) -> void:
		started.append(int(ch.get("id", 0))))
	stage.chapter_boss_spawned.connect(func(_ch: Dictionary) -> void:
		var boss = spawner.get("_boss_instance")
		if boss != null and is_instance_valid(boss):
			boss_hp.append(float(boss.max_health)))
	stage.chapter_cleared.connect(func(ch: Dictionary) -> void:
		cleared.append(int(ch.get("id", 0))))
	var finished: Array = [null]
	stage.run_finished.connect(func(victory: bool) -> void: finished[0] = victory)

	get_tree().root.add_child.call_deferred(main)
	for i in range(5):
		await get_tree().process_frame

	# 测试环境改造：玩家不受伤、不升级，避免升级弹窗把整棵树暂停掉
	player.damage_reduction = 1.0
	player.exp_multiplier = 0.0
	stage.chapter_transition_delay = 0.1
	stage.boss_timeout = 30.0
	for ch in stage.chapters:
		ch["duration"] = 0.4

	# 等首领出现后秒杀并等待单关结算完成
	var deadline := Time.get_ticks_msec() + 30000
	while finished[0] == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var boss = spawner.get("_boss_instance")
		if boss != null and is_instance_valid(boss) and not bool(boss.get("is_dead")):
			boss.take_damage(999999.0)

	check("run_finished_emitted", finished[0] != null, "run_finished 一直没触发")
	check("run_finished_victory", finished[0] == true, "结局=%s，期望 true" % str(finished[0]))
	check("single_stage_started", started == [1], "实际关卡序列=%s" % str(started))
	check("single_boss_spawned", boss_hp.size() == 1 and boss_hp[0] > 0.0, "首领血量序列=%s" % str(boss_hp))
	check("stage_cleared_emitted", cleared == [1], "实际通关信号=%s" % str(cleared))
	check("stage_marked_cleared", Stats.is_stage_cleared(1), "第1关未被标记通关")
	check("chapter_label_updated", ui.get("_chapter_label") != null and ui.get("_chapter_label").text != "", "章节标签未更新")
	check("victory_panel_visible", game_over_ui.visible, "通关后结算面板没有显示")

	main.queue_free()
	ObjectPools.clear()
	Sfx.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame

	Stats.best_time = float(stats_snap["best_time"])
	Stats.best_level = int(stats_snap["best_level"])
	Stats.best_kills = int(stats_snap["best_kills"])
	Stats.total_runs = int(stats_snap["total_runs"])
	Stats.spirit_stones = int(stats_snap["spirit_stones"])
	Stats.selected_stage_id = int(stats_snap["selected_stage_id"])
	Stats.cleared_stages.assign(stats_snap["cleared_stages"])
	Stats.save_stats()

	print("RUN_FLOW checks=", checks, " fails=", failures.size())
	for f in failures:
		print("FAIL ", f)
	if failures.is_empty():
		print("RUN_FLOW OK")
	get_tree().quit(1 if failures.size() > 0 else 0)

func check(label: String, cond: bool, info: String = "") -> void:
	checks += 1
	if cond:
		return
	failures.append(label)
	print("FAIL ", label, " :: ", info)
