extends CanvasLayer

@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var realm_label: Label = $HUD/RealmLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var kill_label: Label = $HUD/KillLabel

# 操作提示停留时长，之后淡出，不干扰战斗视野
const HINT_VISIBLE_SECONDS := 9.0
const HINT_FADE_SECONDS := 2.0

var game_time: float = 0.0
var kill_count_shown: int = -1

var _banner_panel: PanelContainer = null
var _banner_label: Label = null
var _banner_tween: Tween = null

var _boss_bar_container: VBoxContainer = null
var _boss_name_label: Label = null
var _boss_hp_bar: ProgressBar = null
var _boss_hp_label: Label = null

func _ready() -> void:
	add_to_group("ui")
	# ESC 已由 GameFlow 统一处理（本节点在树暂停时会被冻结，无法自行响应按键）。
	# 这里只负责计时、状态显示与提示淡出。
	_setup_hint()
	_setup_banner()
	_setup_boss_bar()

func _exit_tree() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
		_banner_tween = null

func _setup_hint() -> void:
	if hint_label == null:
		return
	if not Settings.get_bool("ui/hint_enabled"):
		hint_label.visible = false
		return
	var t = create_tween()
	t.tween_interval(HINT_VISIBLE_SECONDS)
	t.tween_property(hint_label, "modulate:a", 0.0, HINT_FADE_SECONDS)

func _process(delta: float) -> void:
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	_update_kill_count()

func _update_kill_count() -> void:
	if kill_label == null:
		return
	# 向 game_manager 拉取击杀数，变化时才更新文本，避免每帧重排 Label
	var mgrs = get_tree().get_nodes_in_group("game_manager")
	if mgrs.size() == 0:
		return
	var kills = mgrs[0].kill_count
	if kills != kill_count_shown:
		kill_count_shown = kills
		kill_label.text = "诛魔 %d" % kills

func update_health(curr: float, max_h: float) -> void:
	hp_bar.max_value = max_h
	hp_bar.value = curr

func update_exp(curr: float, max_e: float, level: int) -> void:
	exp_bar.max_value = max_e
	exp_bar.value = curr
	var realms = [
		"炼气前期", "炼气中期", "炼气后期",
		"筑基前期", "筑基中期", "筑基后期",
		"金丹前期", "金丹中期", "金丹后期",
		"元婴大能"
	]
	var idx = clamp(level - 1, 0, realms.size() - 1)
	realm_label.text = "【境界】%s (Lv.%d)" % [realms[idx], level]

func _setup_banner() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.visible = false
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.offset_left = -300.0
	_banner_panel.offset_right = 300.0
	_banner_panel.offset_top = 130.0
	_banner_panel.offset_bottom = 190.0
	_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.03, 0.03, 0.88)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.7, 0.2, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	_banner_panel.add_theme_stylebox_override("panel", style)

	_banner_label = Label.new()
	_banner_label.name = "BannerLabel"
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 26)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_banner_label.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.05, 0.9))
	_banner_label.add_theme_constant_override("shadow_offset_x", 2)
	_banner_label.add_theme_constant_override("shadow_offset_y", 2)
	_banner_panel.add_child(_banner_label)

	hud.add_child(_banner_panel)

func show_banner(msg: String) -> void:
	if _banner_panel == null or _banner_label == null:
		return
	_banner_label.text = msg
	_banner_panel.visible = true
	_banner_panel.modulate.a = 0.0
	_banner_panel.scale = Vector2(0.85, 0.85)
	_banner_panel.pivot_offset = Vector2(300.0, 30.0)

	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_property(_banner_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(3.0)
	_banner_tween.chain().tween_property(_banner_panel, "modulate:a", 0.0, 0.8)
	_banner_tween.chain().tween_callback(func(): _banner_panel.visible = false)

func _setup_boss_bar() -> void:
	var hud = get_node_or_null("HUD")
	if hud == null:
		return
	_boss_bar_container = VBoxContainer.new()
	_boss_bar_container.name = "BossBarContainer"
	_boss_bar_container.visible = false
	_boss_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_container.anchors_preset = Control.PRESET_CENTER_TOP
	_boss_bar_container.anchor_left = 0.5
	_boss_bar_container.anchor_right = 0.5
	_boss_bar_container.offset_left = -260.0
	_boss_bar_container.offset_right = 260.0
	_boss_bar_container.offset_top = 48.0
	_boss_bar_container.offset_bottom = 96.0
	_boss_bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_boss_name_label = Label.new()
	_boss_name_label.name = "BossNameLabel"
	_boss_name_label.text = "【大荒凶煞·啸月狼王】"
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 20)
	_boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_boss_name_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.0, 0.0, 0.8))
	_boss_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_boss_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_boss_bar_container.add_child(_boss_name_label)

	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.name = "BossProgressBar"
	_boss_hp_bar.custom_minimum_size = Vector2(520, 16)
	_boss_hp_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.05, 0.05, 0.9)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.75, 0.25, 0.2, 0.9)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	_boss_hp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	_boss_hp_bar.add_theme_stylebox_override("fill", fill_style)

	_boss_bar_container.add_child(_boss_hp_bar)

	_boss_hp_label = Label.new()
	_boss_hp_label.name = "BossHpLabel"
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_label.add_theme_font_size_override("font_size", 14)
	_boss_hp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_boss_bar_container.add_child(_boss_hp_label)

	hud.add_child(_boss_bar_container)

func activate_boss_bar(max_hp: float) -> void:
	if _boss_bar_container == null:
		return
	_boss_bar_container.visible = true
	_boss_bar_container.modulate.a = 0.0
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = max_hp
		_boss_hp_bar.value = max_hp
	if _boss_hp_label != null:
		_boss_hp_label.text = "%d / %d" % [int(max_hp), int(max_hp)]
	var t = create_tween()
	t.tween_property(_boss_bar_container, "modulate:a", 1.0, 0.6)

func update_boss_hp(curr: float, max_h: float) -> void:
	if _boss_bar_container == null or not _boss_bar_container.visible:
		return
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = max_h
		_boss_hp_bar.value = maxf(0.0, curr)
	if _boss_hp_label != null:
		_boss_hp_label.text = "%d / %d" % [max(0, int(curr)), int(max_h)]
	if curr <= 0:
		var t = create_tween()
		t.tween_property(_boss_bar_container, "modulate:a", 0.0, 0.8)
		t.tween_callback(func(): _boss_bar_container.visible = false)
