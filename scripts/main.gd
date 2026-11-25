extends Node2D

@onready var player = $Player
@onready var ui = $UI
@onready var upgrade_ui = $UpgradeUI
@onready var chest_ui = $ChestUI
@onready var upgrade_mgr = $UpgradeManager
@onready var game_over_ui = $GameOverUI
@onready var stage_director = $StageDirector
@onready var spawner = $Spawner

const SHOP_LEVEL_INTERVAL := 5
const CHEST_LEVEL_INTERVAL := 4
const TREASURE_CHEST_SCENE: PackedScene = preload("res://scenes/treasure_chest.tscn")

var shop_ui: V2ShopUI = null
var debug_sandbox: V2DebugSandbox = null
var kill_count: int = 0
var pending_level_ups: int = 0
var pending_chests: int = 0
var pending_shop_wave: int = 0
var _queued_shop_wave: int = 0
var _shop_delay_timer: float = 0.0
var is_game_over: bool = false
var jars_broken_count: int = 0
var _show_scheduled: bool = false
var _current_upgrade_is_breakthrough: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	GameFlow.sync_after_scene_load(GameFlow.State.PLAYING)
	ObjectPools.clear()
	Music.play_track("battle")

	if upgrade_mgr and upgrade_mgr.has_method("reset_run_controls"):
		upgrade_mgr.reset_run_controls()

	if player:
		player.health_changed.connect(ui.update_health)
		player.exp_changed.connect(ui.update_exp)
		player.leveled_up.connect(_on_player_leveled_up)
		player.died.connect(_on_player_died)
		if player.weapon_mgr != null:
			player.weapon_mgr.loadout_changed.connect(_refresh_hud_loadout)
		if "v2_combat" in player and player.v2_combat != null:
			player.v2_combat.v2_loadout_changed.connect(_refresh_hud_loadout)
			player.v2_combat.gold_changed.connect(ui.update_gold)
			player.v2_combat.realm_slot_unlocked.connect(_on_realm_slot_unlocked)
			ui.update_gold(player.v2_combat.run_gold)

	shop_ui = V2ShopUI.new()
	shop_ui.name = "V2ShopUI"
	add_child(shop_ui)
	shop_ui.closed.connect(_on_shop_closed)

	debug_sandbox = V2DebugSandbox.new()
	debug_sandbox.name = "V2DebugSandbox"
	add_child(debug_sandbox)
	debug_sandbox.setup(self, player, spawner)

	if spawner != null and spawner.has_signal("wave_completed"):
		spawner.wave_completed.connect(_on_wave_completed)

	if upgrade_ui:
		upgrade_ui.upgrade_selected.connect(_on_upgrade_chosen)
		upgrade_ui.reroll_requested.connect(_on_reroll_requested)
		upgrade_ui.banish_selected.connect(_on_banish_selected)
		upgrade_ui.skip_requested.connect(_on_skip_requested)

	if chest_ui:
		chest_ui.closed.connect(_on_chest_closed)

	if game_over_ui:
		game_over_ui.restart_requested.connect(_on_restart_requested)
		game_over_ui.title_requested.connect(_on_title_requested)
		if game_over_ui.has_signal("next_stage_requested"):
			game_over_ui.next_stage_requested.connect(_on_next_stage_requested)
		if game_over_ui.has_signal("endless_requested"):
			game_over_ui.endless_requested.connect(_on_endless_requested)

	_refresh_hud_loadout()

	if stage_director:
		stage_director.run_finished.connect(_on_run_finished)
		stage_director.begin_run.call_deferred()

func _refresh_hud_loadout() -> void:
	if ui == null or player == null:
		return
	if "v2_combat" in player and player.v2_combat != null and ui.has_method("refresh_v2_loadout"):
		ui.refresh_v2_loadout(player.v2_combat)
	elif player.weapon_mgr != null and ui.has_method("refresh_loadout"):
		ui.refresh_loadout(player.weapon_mgr)

func _process(delta: float) -> void:
	if _queued_shop_wave > 0 and _shop_delay_timer > 0.0 and not is_game_over:
		_shop_delay_timer -= delta
		if _shop_delay_timer <= 0.0:
			pending_shop_wave = _queued_shop_wave
			_queued_shop_wave = 0
			_schedule_modal()
	if stage_director == null or ui == null:
		return
	var chapter: Dictionary = stage_director.current_chapter()
	if chapter.is_empty():
		return
	ui.update_chapter_progress(stage_director.chapter_time(), float(chapter.get("duration", 480.0)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F9 and not is_game_over:
			open_debug_sandbox()
			get_viewport().set_input_as_handled()

func open_debug_sandbox() -> void:
	if debug_sandbox != null and is_instance_valid(debug_sandbox) and not is_game_over:
		debug_sandbox.toggle_panel()

func _on_wave_completed(_completed_wave: int, _next_wave: int) -> void:
	return

func on_jar_broken() -> void:
	jars_broken_count += 1

func on_enemy_killed() -> void:
	kill_count += 1

func on_elite_killed() -> void:
	if player != null and "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.notify_elite_killed()

func update_boss_hp(curr: float, max_h: float) -> void:
	if ui != null and ui.has_method("update_boss_hp"):
		ui.update_boss_hp(curr, max_h)

func on_boss_killed() -> void:
	if stage_director:
		stage_director.notify_boss_killed()

func on_chest_collected() -> void:
	if is_game_over:
		return
	pending_chests += 1
	_schedule_modal()

func _on_run_finished(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	pending_level_ups = 0
	pending_chests = 0
	pending_shop_wave = 0
	_queued_shop_wave = 0
	if upgrade_ui:
		upgrade_ui.hide_panel()
	if chest_ui:
		chest_ui.hide_panel()
	if shop_ui:
		shop_ui.hide_panel()
	Sfx.play("level_up", 0.0)
	var stone_mult := 1.0
	if stage_director != null:
		var ch: Dictionary = stage_director.current_chapter()
		stone_mult = float(ch.get("stone_mult", 1.0))
	var curse_pct := 0.0
	if player != null and "v2_combat" in player and player.v2_combat != null and player.v2_combat.has_method("get_curse_pct"):
		curse_pct = float(player.v2_combat.get_curse_pct())
	var stones_earned := Stats.calc_run_stones(ui.game_time, kill_count, victory, stone_mult, curse_pct)
	Stats.add_spirit_stones(stones_earned)
	var is_record = Stats.record_run(ui.game_time, player.level, kill_count)
	var run_reactions := 0
	var run_fusions := 0
	if player != null and "v2_combat" in player and player.v2_combat != null:
		run_reactions = int(player.v2_combat.get("reaction_count"))
		run_fusions = int(player.v2_combat.count_fusions_owned()) if player.v2_combat.has_method("count_fusions_owned") else 0
	if Stats.has_method("evaluate_run_achievements"):
		Stats.evaluate_run_achievements({
			"run_time": ui.game_time,
			"run_level": player.level,
			"run_kills": kill_count,
			"victory": victory,
			"curse_pct": curse_pct,
			"run_reactions": run_reactions,
			"run_fusions": run_fusions,
			"run_jars_broken": jars_broken_count,
		})
	GameFlow.game_over()
	if game_over_ui:
		if victory:
			var has_next := Stats.selected_stage_id < ChapterData.count()
			game_over_ui.show_victory(ui.game_time, player.level, kill_count, is_record, stones_earned, has_next)
		else:
			game_over_ui.show_summary(ui.game_time, player.level, kill_count, is_record, stones_earned)

func _on_player_leveled_up(new_lvl: int) -> void:
	Sfx.play("level_up", -4.0)
	pending_level_ups += 1
	if new_lvl > 0 and new_lvl % CHEST_LEVEL_INTERVAL == 0 and player != null and is_instance_valid(player):
		if TREASURE_CHEST_SCENE != null:
			var chest := TREASURE_CHEST_SCENE.instantiate() as Node2D
			if chest != null:
				chest.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * 78.0
				add_child(chest)
		if ui != null and ui.has_method("show_banner"):
			ui.show_banner("【机缘降世 · Lv.%d 赐福宝箱已落于身侧！】" % new_lvl)
	if new_lvl > 0 and new_lvl % SHOP_LEVEL_INTERVAL == 0:
		_queued_shop_wave = maxi(1, new_lvl / SHOP_LEVEL_INTERVAL)
		_shop_delay_timer = 0.45
		if ui != null and ui.has_method("show_banner"):
			ui.show_banner("【境界精进至 Lv.%d · 选卡后开启天机阁！】" % new_lvl)
	_schedule_modal()

func _on_realm_slot_unlocked(new_slots: int, realm_name: String, reason: String) -> void:
	_refresh_hud_loadout()
	if ui == null or not ui.has_method("show_banner"):
		return
	if reason == "elite":
		ui.show_banner("【大妖伏诛 · 天赐机缘，第 %d 个法宝槽开启（%s）】" % [new_slots, realm_name])
		return
	var next_info: Dictionary = {}
	if player != null and "v2_combat" in player and player.v2_combat != null:
		next_info = player.v2_combat.get_next_slot_unlock_info()
	var tail := ""
	if not next_info.is_empty():
		tail = " · 下一槽 Lv.%d" % int(next_info.get("level", 0))
	ui.show_banner("【破境%s · 法宝槽扩至 %d%s】" % [realm_name, new_slots, tail])

func _schedule_modal() -> void:
	if not _show_scheduled:
		_show_scheduled = true
		call_deferred("_show_next_modal")

func _show_next_modal() -> void:
	_show_scheduled = false
	if is_game_over:
		return
	if (upgrade_ui != null and upgrade_ui.is_showing) or (chest_ui != null and chest_ui.is_showing) or (shop_ui != null and shop_ui.is_showing):
		return

	if pending_chests > 0 and chest_ui != null:
		if GameFlow.state != GameFlow.State.UPGRADE:
			if not GameFlow.request_upgrade():
				return
		pending_chests -= 1
		var rewards: Array[Dictionary] = upgrade_mgr.roll_v2_chest_rewards(player)
		_refresh_hud_loadout()
		chest_ui.show_rewards(rewards)
		return

	if pending_level_ups > 0 and upgrade_ui != null:
		var draw_count := 3
		var is_bt := false
		if player != null and "v2_combat" in player and player.v2_combat != null:
			draw_count = player.v2_combat.roll_level_choice_count(3)
			is_bt = player.v2_combat.should_offer_breakthrough_pick()
		_current_upgrade_is_breakthrough = is_bt
		var choices = upgrade_mgr.get_v2_level_choices(player, draw_count)
		var is_limit := false
		if choices.size() == 0:
			choices = upgrade_mgr.get_limit_break_choices(player, draw_count)
			is_limit = true
			_current_upgrade_is_breakthrough = false
		if choices.size() == 0:
			pending_level_ups = 0
			_current_upgrade_is_breakthrough = false
		else:
			if GameFlow.state != GameFlow.State.UPGRADE:
				if not GameFlow.request_upgrade():
					return
			pending_level_ups -= 1
			upgrade_ui.show_choices(
				choices,
				pending_level_ups,
				upgrade_mgr.rerolls_left,
				upgrade_mgr.banishes_left,
				upgrade_mgr.skips_left,
				is_limit,
				is_bt,
				player.v2_combat if (player != null and "v2_combat" in player) else null
			)
			return

	if pending_shop_wave > 0 and shop_ui != null and "v2_combat" in player and player.v2_combat != null:
		if GameFlow.state != GameFlow.State.UPGRADE:
			if not GameFlow.request_upgrade():
				return
		var w := pending_shop_wave
		pending_shop_wave = 0
		shop_ui.open_shop(w, player.v2_combat, upgrade_mgr.banished_ids if upgrade_mgr != null else {})
		return

	_finish_upgrade_queue()

func _on_upgrade_chosen(upgrade_id: String) -> void:
	if _current_upgrade_is_breakthrough and player != null and "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.consume_breakthrough_pick()
	_current_upgrade_is_breakthrough = false
	upgrade_mgr.apply_v2_upgrade(upgrade_id, player)
	_refresh_hud_loadout()
	if (pending_chests > 0 or pending_level_ups > 0 or pending_shop_wave > 0) and not is_game_over:
		_show_next_modal()
	else:
		_finish_upgrade_queue()

func _on_reroll_requested() -> void:
	if upgrade_mgr.rerolls_left <= 0:
		return
	upgrade_mgr.rerolls_left -= 1
	var draw_count := 3
	var is_bt := _current_upgrade_is_breakthrough
	if player != null and "v2_combat" in player and player.v2_combat != null:
		draw_count = player.v2_combat.roll_level_choice_count(3)
		is_bt = player.v2_combat.should_offer_breakthrough_pick()
	_current_upgrade_is_breakthrough = is_bt
	var choices = upgrade_mgr.get_v2_level_choices(player, draw_count)
	var is_limit := false
	if choices.size() == 0:
		choices = upgrade_mgr.get_limit_break_choices(player, draw_count)
		is_limit = true
		_current_upgrade_is_breakthrough = false
	upgrade_ui.show_choices(
		choices,
		pending_level_ups,
		upgrade_mgr.rerolls_left,
		upgrade_mgr.banishes_left,
		upgrade_mgr.skips_left,
		is_limit,
		is_bt,
		player.v2_combat if (player != null and "v2_combat" in player) else null
	)

func _on_banish_selected(upgrade_id: String) -> void:
	if _current_upgrade_is_breakthrough and player != null and "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.consume_breakthrough_pick()
	_current_upgrade_is_breakthrough = false
	upgrade_mgr.banish_choice(upgrade_id)
	if (pending_chests > 0 or pending_level_ups > 0 or pending_shop_wave > 0) and not is_game_over:
		_show_next_modal()
	else:
		_finish_upgrade_queue()

func _on_skip_requested() -> void:
	if _current_upgrade_is_breakthrough and player != null and "v2_combat" in player and player.v2_combat != null:
		player.v2_combat.consume_breakthrough_pick()
	_current_upgrade_is_breakthrough = false
	if upgrade_mgr.skips_left > 0:
		upgrade_mgr.skips_left -= 1
		if player != null and player.has_method("heal"):
			player.heal(15.0)
	if (pending_chests > 0 or pending_level_ups > 0 or pending_shop_wave > 0) and not is_game_over:
		_show_next_modal()
	else:
		_finish_upgrade_queue()

func _on_chest_closed() -> void:
	_refresh_hud_loadout()
	if (pending_chests > 0 or pending_level_ups > 0 or pending_shop_wave > 0) and not is_game_over:
		_show_next_modal()
	else:
		_finish_upgrade_queue()

func _on_shop_closed() -> void:
	_refresh_hud_loadout()
	if (pending_chests > 0 or pending_level_ups > 0 or pending_shop_wave > 0) and not is_game_over:
		_show_next_modal()
	else:
		_finish_upgrade_queue()

func _finish_upgrade_queue() -> void:
	GameFlow.finish_upgrade()

func _on_player_died() -> void:
	if is_game_over:
		return
	if stage_director:
		stage_director.notify_player_failed()
		return
	_on_run_finished(false)

func _on_next_stage_requested() -> void:
	Stats.selected_stage_id = mini(ChapterData.count(), Stats.selected_stage_id + 1)
	Stats.save_stats()
	_prepare_restart()
	GameFlow.restart_run()

func _on_endless_requested() -> void:
	is_game_over = false
	if game_over_ui:
		game_over_ui.hide_panel()
	GameFlow._enter_run()
	if stage_director and stage_director.has_method("enter_endless_mode"):
		stage_director.enter_endless_mode()

func _on_restart_requested() -> void:
	_prepare_restart()
	GameFlow.restart_run()

func _on_title_requested() -> void:
	_prepare_restart()
	GameFlow.to_title()

func _prepare_restart() -> void:
	ObjectPools.clear()
