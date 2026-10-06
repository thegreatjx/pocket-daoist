extends Node2D

@onready var player = $Player
@onready var ui = $UI
@onready var upgrade_ui = $UpgradeUI
@onready var upgrade_mgr = $UpgradeManager
@onready var game_over_ui = $GameOverUI

var kill_count: int = 0
var pending_level_ups: int = 0
var is_game_over: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	if player:
		player.health_changed.connect(ui.update_health)
		player.exp_changed.connect(ui.update_exp)
		player.leveled_up.connect(_on_player_leveled_up)
		player.died.connect(_on_player_died)

	if upgrade_ui:
		upgrade_ui.upgrade_selected.connect(_on_upgrade_chosen)

	if game_over_ui:
		game_over_ui.restart_requested.connect(_on_restart_requested)

func on_enemy_killed() -> void:
	kill_count += 1

func _on_player_leveled_up(_new_lvl: int) -> void:
	# 连升多级时排队，逐次弹出机缘选择，不再互相覆盖
	pending_level_ups += 1
	_show_next_upgrade_choice()

func _show_next_upgrade_choice() -> void:
	if is_game_over or pending_level_ups <= 0:
		return
	if upgrade_ui == null or upgrade_ui.is_showing:
		return
	var choices = upgrade_mgr.get_random_choices(3)
	if choices.size() == 0:
		# 全部修满，机缘自动跳过，不冻结玩家
		pending_level_ups = 0
		return
	pending_level_ups -= 1
	upgrade_ui.show_choices(choices, pending_level_ups)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	upgrade_mgr.apply_upgrade(upgrade_id, player)
	_show_next_upgrade_choice()

func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	pending_level_ups = 0
	if upgrade_ui:
		upgrade_ui.hide_and_unpause()
	if game_over_ui:
		game_over_ui.show_summary(ui.game_time, player.level, kill_count)

func _on_restart_requested() -> void:
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()
