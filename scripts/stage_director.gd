extends Node

signal chapter_started(chapter: Dictionary)
signal chapter_boss_spawned(chapter: Dictionary)
signal chapter_cleared(chapter: Dictionary)
signal run_finished(victory: bool)

@export var auto_start: bool = false
@export var boss_timeout: float = 180.0
@export var advance_on_boss_kill: bool = true
@export var chapter_transition_delay: float = 1.2

var chapters: Array[Dictionary] = []
var chapter_index: int = -1
var chapter_elapsed: float = 0.0
var running: bool = false
var finished: bool = false
var endless_mode: bool = false
var endless_cycle: int = 0

var game_manager: Node = null
var spawner: Node = null
var background: Node = null
var ui: Node = null

var _pending_bosses: Array[Dictionary] = []
var _boss_spawned: bool = false
var _boss_plan: Array[Dictionary] = []
var _boss_plan_index: int = 0
var _boss_schedule_cfg: Dictionary = {}
var _finish_delay: float = 0.0
var _endless_timer: float = 0.0

func _ready() -> void:
	chapters = ChapterData.all()
	_resolve_nodes()
	if auto_start:
		begin_run.call_deferred()

func begin_run() -> void:
	if running:
		return
	_resolve_nodes()
	running = true
	finished = false
	endless_mode = false
	endless_cycle = 0
	_endless_timer = 0.0
	chapter_index = clampi(Stats.selected_stage_id - 1, 0, maxi(0, chapters.size() - 1))
	chapter_elapsed = 0.0
	_pending_bosses.clear()
	_boss_spawned = false
	_boss_plan.clear()
	_boss_plan_index = 0
	_finish_delay = 0.0
	_apply_current_stage()

func current_chapter() -> Dictionary:
	if chapter_index < 0 or chapter_index >= chapters.size():
		return {}
	return chapters[chapter_index]

func chapter_time() -> float:
	return chapter_elapsed

func chapter_time_remaining() -> float:
	var chapter := current_chapter()
	if chapter.is_empty():
		return 0.0
	return maxf(0.0, float(chapter.get("duration", 480.0)) - chapter_elapsed)

func notify_boss_killed(boss_name: String = "") -> void:
	if finished:
		return
	var index := _find_pending_boss(boss_name)
	if index < 0:
		return
	var entry: Dictionary = _pending_bosses[index]
	_pending_bosses.remove_at(index)
	if String(entry.get("state", "")) == "abandoned":
		return
	_clear_boss(entry, true)

func notify_player_failed() -> void:
	if finished:
		return
	finished = true
	running = false
	run_finished.emit(false)

func enter_endless_mode() -> void:
	finished = false
	running = true
	endless_mode = true
	endless_cycle += 1
	_endless_timer = 120.0
	_boss_spawned = false
	_finish_delay = 0.0
	_pending_bosses.clear()
	_resolve_nodes()
	if spawner != null and spawner.has_method("set_endless_level"):
		spawner.set_endless_level(endless_cycle)
	Music.play_track("battle", 0.8)
	if ui != null and ui.has_method("show_banner"):
		ui.show_banner("【无尽试炼 · 第 %d 劫开启！】" % endless_cycle)

func _process(delta: float) -> void:
	if _finish_delay > 0.0:
		_finish_delay -= delta
		if _finish_delay <= 0.0:
			_finish_delay = 0.0
			run_finished.emit(true)
		return

	if not running or finished:
		return

	chapter_elapsed += delta

	for entry in _pending_bosses:
		if String(entry.get("state", "")) != "waiting":
			continue
		entry["wait"] = float(entry["wait"]) + delta
		if float(entry["wait"]) >= boss_timeout:
			entry["state"] = "abandoned"
			_clear_boss(entry, false)
			if finished:
				return

	var chapter := current_chapter()
	if chapter.is_empty():
		return

	if endless_mode:
		if not _boss_spawned:
			_endless_timer -= delta
			if _endless_timer <= 0.0:
				_spawn_chapter_boss(chapter)
		return

	var duration := float(chapter.get("duration", 480.0))
	if _boss_plan_index < _boss_plan.size():
		var plan: Dictionary = _boss_plan[_boss_plan_index]
		if chapter_elapsed >= float(plan.get("at", duration)):
			_boss_plan_index += 1
			_spawn_plan_boss(plan)

func _advance_chapter() -> void:
	chapter_index += 1
	if chapter_index >= chapters.size():
		finished = true
		running = false
		run_finished.emit(true)
		return
	_apply_current_stage()

func _apply_current_stage() -> void:
	chapter_elapsed = 0.0
	_boss_spawned = false
	var chapter := chapters[chapter_index]
	_build_boss_plan()

	_resolve_nodes()
	if spawner != null and spawner.has_method("apply_chapter"):
		spawner.apply_chapter(chapter)
	if background != null and background.has_method("apply_chapter"):
		background.apply_chapter(chapter)
	if ui != null and ui.has_method("set_chapter"):
		ui.set_chapter(chapter)
	var tree := get_tree()
	if tree != null:
		var p := tree.get_first_node_in_group("player")
		if p != null and p.has_method("set_stage_speed_mult"):
			var mods = chapter.get("mods", {})
			var p_spd := float(mods.get("player_speed", 1.0)) if mods is Dictionary else 1.0
			p.set_stage_speed_mult(p_spd)

	chapter_started.emit(chapter)

func _spawn_plan_boss(plan: Dictionary) -> void:
	_resolve_nodes()
	var boss_inst: Node = null
	if spawner != null and spawner.has_method("spawn_boss_entry"):
		boss_inst = spawner.spawn_boss_entry(plan)
	_pending_bosses.append({
		"chapter": current_chapter(),
		"plan": plan,
		"boss_name": String(plan.get("name", "")),
		"wait": 0.0,
		"instance": boss_inst,
		"state": "waiting",
	})
	chapter_boss_spawned.emit(current_chapter())

func _build_boss_plan() -> void:
	_boss_plan.clear()
	_boss_plan_index = 0
	var chapter := current_chapter()
	if chapter.is_empty() or chapters.is_empty():
		return
	var duration := float(chapter.get("duration", 480.0))
	var cfg := _load_boss_schedule()
	var pcts: Array = cfg.get("schedule_pct", [0.55, 0.72, 0.88, 1.0])
	var mults: Array = cfg.get("hp_mult", [0.42, 0.52, 0.62, 1.0])
	var total := pcts.size()
	for k in range(total):
		var src_index := chapter_index
		if k < total - 1:
			src_index = (chapter_index + k + 1) % chapters.size()
		var src: Dictionary = chapters[src_index]
		_boss_plan.append({
			"at": duration * float(pcts[k]),
			"name": String(src.get("boss_name", "")),
			"type": String(src.get("boss_type", "wolf")),
			"hp": float(src.get("boss_hp", 4600.0)) * float(mults[clampi(k, 0, mults.size() - 1)]),
			"final": k == total - 1,
		})

func _load_boss_schedule() -> Dictionary:
	if not _boss_schedule_cfg.is_empty():
		return _boss_schedule_cfg
	var path := "res://data/v2/boss_schedule_v2.json"
	if not FileAccess.file_exists(path):
		push_error("Boss 调度表缺失：%s" % path)
		_boss_schedule_cfg = {"schedule_pct": [0.55, 0.72, 0.88, 1.0], "hp_mult": [0.42, 0.52, 0.62, 1.0]}
		return _boss_schedule_cfg
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_boss_schedule_cfg = parsed
	else:
		push_error("Boss 调度表解析失败：%s" % path)
		_boss_schedule_cfg = {"schedule_pct": [0.55, 0.72, 0.88, 1.0], "hp_mult": [0.42, 0.52, 0.62, 1.0]}
	return _boss_schedule_cfg

func _spawn_chapter_boss(chapter: Dictionary) -> void:
	_boss_spawned = true
	_resolve_nodes()
	var boss_inst: Node = null
	if spawner != null and spawner.has_method("spawn_chapter_boss"):
		spawner.spawn_chapter_boss(chapter)
		boss_inst = spawner.get("_boss_instance")
	_pending_bosses.append({
		"chapter": chapter,
		"boss_name": String(chapter.get("boss_name", "")),
		"wait": 0.0,
		"instance": boss_inst,
		"state": "waiting",
	})
	chapter_boss_spawned.emit(chapter)

func _clear_boss(entry: Dictionary, killed: bool) -> void:
	var chapter: Dictionary = entry.get("chapter", {})
	var plan: Dictionary = entry.get("plan", {})
	var is_final := bool(plan.get("final", true))
	var ch_id := int(chapter.get("id", 1))
	chapter_cleared.emit(chapter)

	if endless_mode:
		if killed:
			endless_cycle += 1
			_boss_spawned = false
			_endless_timer = 120.0
			if spawner != null and spawner.has_method("set_endless_level"):
				spawner.set_endless_level(endless_cycle)
			Music.play_track("battle", 0.9)
			if ui != null and ui.has_method("show_banner"):
				ui.show_banner("斩杀首领！无尽第 %d 劫即将降临！" % endless_cycle)
		else:
			finished = true
			running = false
			run_finished.emit(false)
		return

	if not is_final:
		if killed:
			if ui != null and ui.has_method("show_banner"):
				ui.show_banner("✦ 斩落【%s】· 宝箱已落！ ✦" % String(entry.get("boss_name", "首领")))
		return

	finished = true
	running = false
	if killed:
		Stats.mark_stage_cleared(ch_id)
		if ui != null and ui.has_method("show_banner"):
			ui.show_banner("✦ 斩落【%s】· 秘境大捷！ ✦" % String(entry.get("boss_name", "首领")))
		_finish_delay = chapter_transition_delay
	else:
		run_finished.emit(false)

func _find_pending_boss(boss_name: String) -> int:
	if _pending_bosses.is_empty():
		return -1
	if boss_name != "":
		for i in range(_pending_bosses.size()):
			if String(_pending_bosses[i].get("boss_name", "")) == boss_name:
				return i
	for i in range(_pending_bosses.size()):
		var inst: Variant = _pending_bosses[i].get("instance", null)
		if inst != null and is_instance_valid(inst) and bool(inst.get("is_dead")):
			return i
	return 0

func _resolve_nodes() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if game_manager == null or not is_instance_valid(game_manager):
		game_manager = tree.get_first_node_in_group("game_manager")
	if spawner == null or not is_instance_valid(spawner):
		spawner = tree.get_first_node_in_group("spawner")
	if background == null or not is_instance_valid(background):
		background = tree.get_first_node_in_group("background")
	if ui == null or not is_instance_valid(ui):
		ui = tree.get_first_node_in_group("ui")
