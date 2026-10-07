extends Node2D

@onready var player = $Player
@onready var ui = $UI
@onready var upgrade_ui = $UpgradeUI
@onready var upgrade_mgr = $UpgradeManager
@onready var game_over_ui = $GameOverUI

var kill_count: int = 0
var pending_level_ups: int = 0
var is_game_over: bool = false
var _show_scheduled: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	# 校正流程状态：从标题切入或重开时，可能残留 PAUSED/GAME_OVER 与暂停标志
	GameFlow.sync_after_scene_load(GameFlow.State.PLAYING)
	# 清池：上一局随场景销毁的对象会让池计数失真，且游离实例不属于本场景
	ObjectPools.clear()
	Music.play_track("battle")

	if player:
		player.health_changed.connect(ui.update_health)
		player.exp_changed.connect(ui.update_exp)
		player.leveled_up.connect(_on_player_leveled_up)
		player.died.connect(_on_player_died)

	if upgrade_ui:
		upgrade_ui.upgrade_selected.connect(_on_upgrade_chosen)

	if game_over_ui:
		game_over_ui.restart_requested.connect(_on_restart_requested)
		game_over_ui.title_requested.connect(_on_title_requested)

func on_enemy_killed() -> void:
	kill_count += 1

func update_boss_hp(curr: float, max_h: float) -> void:
	if ui != null and ui.has_method("update_boss_hp"):
		ui.update_boss_hp(curr, max_h)

func on_boss_killed() -> void:
	if is_game_over:
		return
	is_game_over = true
	pending_level_ups = 0
	if upgrade_ui:
		upgrade_ui.hide_panel()
	Sfx.play("level_up", 0.0)
	var is_record = Stats.record_run(ui.game_time, player.level, kill_count)
	GameFlow.game_over()
	if game_over_ui:
		game_over_ui.show_victory(ui.game_time, player.level, kill_count, is_record)

func _on_player_leveled_up(_new_lvl: int) -> void:
	# 连升多级时排队，逐次弹出机缘选择，不再互相覆盖
	Sfx.play("level_up", -4.0)
	pending_level_ups += 1
	# gain_exp 在同一次调用中同步发出全部 leveled_up，若立即弹窗，
	# 第一张卡会显示"剩余 0 次机缘"。延迟一帧等计数累加完再弹。
	if not _show_scheduled:
		_show_scheduled = true
		call_deferred("_show_next_upgrade_choice")

func _show_next_upgrade_choice() -> void:
	_show_scheduled = false
	if is_game_over or pending_level_ups <= 0:
		return
	if upgrade_ui == null or upgrade_ui.is_showing:
		return
	var choices = upgrade_mgr.get_random_choices(3)
	if choices.size() == 0:
		# 全部修满，机缘自动跳过，不冻结玩家
		pending_level_ups = 0
		_finish_upgrade_queue()
		return
	# 向 GameFlow 申请进入选卡态；失败说明已死亡或已在其它状态
	if GameFlow.state != GameFlow.State.UPGRADE:
		if not GameFlow.request_upgrade():
			return
	pending_level_ups -= 1
	upgrade_ui.show_choices(choices, pending_level_ups)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	upgrade_mgr.apply_upgrade(upgrade_id, player)
	if pending_level_ups > 0 and not is_game_over:
		_show_next_upgrade_choice()
	else:
		_finish_upgrade_queue()

# 选卡队列走完：交还控制权给 GameFlow，由它解除暂停
func _finish_upgrade_queue() -> void:
	GameFlow.finish_upgrade()

func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	pending_level_ups = 0
	if upgrade_ui:
		upgrade_ui.hide_panel()
	# 记录战绩（独立于设置存档，重开不清空）；返回值用于显示刷新纪录
	var is_record = Stats.record_run(ui.game_time, player.level, kill_count)
	# 由 GameFlow 统一冻结游戏，再显示结算面板
	GameFlow.game_over()
	if game_over_ui:
		game_over_ui.show_summary(ui.game_time, player.level, kill_count, is_record)

func _on_restart_requested() -> void:
	_prepare_restart()
	GameFlow.restart_run()

func _on_title_requested() -> void:
	_prepare_restart()
	GameFlow.to_title()

# 重启前置：清空对象池，防止池持有已随场景销毁的实例。
# 拆成独立函数便于测试验证副作用，而不触发真实场景重载。
func _prepare_restart() -> void:
	ObjectPools.clear()
