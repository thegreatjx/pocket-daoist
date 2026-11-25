extends Control

@onready var best_label: Label = $Center/VBox/BestLabel
@onready var start_btn: Button = $Center/VBox/StartButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var quit_btn: Button = $Center/VBox/QuitButton
@onready var vbox: VBoxContainer = $Center/VBox

var settings_panel: SettingsPanel = null
var sect_panel: Control = null
var _stage_title_lbl: Label = null
var _stage_meta_lbl: Label = null
var _char_title_lbl: Label = null
var _char_meta_lbl: Label = null
var _char_trait_lbl: Label = null
var _char_portrait: TextureRect = null
var _sect_btn: Button = null
var _debug_btn: Button = null
var _stone_lbl: Label = null
var _preload_started: bool = false
var _starting_game: bool = false
var _loading_overlay: ColorRect = null
var _loading_lbl: Label = null

func _ready() -> void:
	GameFlow.sync_after_scene_load(GameFlow.State.TITLE)
	Music.play_track("title")
	_build_character_selector()
	_build_stage_selector()
	_build_sect_button()
	_apply_qinglv_theme()
	_refresh_best()
	_refresh_character_ui()
	_refresh_stage_ui()
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	_begin_scene_preload()

func _begin_scene_preload() -> void:
	if _preload_started or DisplayServer.get_name() == "headless":
		return
	_preload_started = true
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(GameFlow.GAME_SCENE, "", true)

func _process(_delta: float) -> void:
	if not _starting_game:
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_starting_game = false
		var packed := ResourceLoader.load_threaded_get(GameFlow.GAME_SCENE) as PackedScene
		GameFlow.start_game_packed(packed)
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _loading_lbl != null and not progress.is_empty():
			var pct := clampi(roundi(float(progress[0]) * 100.0), 0, 99)
			_loading_lbl.text = "踏入秘境中… %d%%" % pct
	else:
		_starting_game = false
		GameFlow.start_game()

func _show_loading_overlay() -> void:
	if _loading_overlay != null and is_instance_valid(_loading_overlay):
		return
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.11, 0.09, 0.72)
	var plate := PanelContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plate.offset_left = -180.0
	plate.offset_right = 180.0
	plate.offset_top = -42.0
	plate.offset_bottom = 42.0
	plate.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_DARK, XianxiaUITheme.COL_GOLD, 10, 16))
	overlay.add_child(plate)
	var lbl := Label.new()
	lbl.text = "踏入秘境中…"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(lbl, 3)
	plate.add_child(lbl)
	$SettingsLayer.add_child(overlay)
	_loading_overlay = overlay
	_loading_lbl = lbl

func _build_character_selector() -> void:
	var card := PanelContainer.new()
	card.name = "CharacterSelector"
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(640, 126)
	card.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 10, 12))
	XianxiaUITheme.attach_ornaments(card, XianxiaUITheme.COL_GOLD, 12.0, 5.0)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(42, 82)
	prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(func(): _shift_character(-1))
	XianxiaUITheme.style_button(prev_btn, "dark_gold")
	hbox.add_child(prev_btn)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(82, 82)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pst := StyleBoxFlat.new()
	pst.bg_color = XianxiaUITheme.COL_PLATE_DARK
	pst.border_color = XianxiaUITheme.COL_GOLD
	pst.set_border_width_all(2)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(5)
	portrait_frame.add_theme_stylebox_override("panel", pst)
	hbox.add_child(portrait_frame)

	_char_portrait = TextureRect.new()
	_char_portrait.custom_minimum_size = Vector2(70, 70)
	_char_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(_char_portrait)

	var info_box := VBoxContainer.new()
	info_box.clip_contents = true
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_box.add_theme_constant_override("separation", 4)
	hbox.add_child(info_box)

	_char_title_lbl = Label.new()
	_char_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_title_lbl.custom_minimum_size = Vector2(10, 0)
	_char_title_lbl.clip_text = true
	_char_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_char_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_title_lbl.add_theme_font_size_override("font_size", 20)
	_char_title_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_char_title_lbl, 3)
	info_box.add_child(_char_title_lbl)

	_char_meta_lbl = Label.new()
	_char_meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_meta_lbl.custom_minimum_size = Vector2(10, 0)
	_char_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_meta_lbl.add_theme_font_size_override("font_size", 14)
	_char_meta_lbl.add_theme_color_override("font_color", Color(0.88, 0.96, 0.91))
	info_box.add_child(_char_meta_lbl)

	_char_trait_lbl = Label.new()
	_char_trait_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_trait_lbl.custom_minimum_size = Vector2(10, 0)
	_char_trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_char_trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_trait_lbl.add_theme_font_size_override("font_size", 14)
	_char_trait_lbl.add_theme_color_override("font_color", Color(0.56, 0.96, 0.76))
	info_box.add_child(_char_trait_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(42, 82)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(func(): _shift_character(1))
	XianxiaUITheme.style_button(next_btn, "dark_gold")
	hbox.add_child(next_btn)

	vbox.add_child(card)
	vbox.move_child(card, start_btn.get_index())

func _shift_character(delta_idx: int) -> void:
	var chars := CharacterData.all()
	if chars.is_empty():
		return
	var cur_idx := 0
	for i in range(chars.size()):
		if str(chars[i]["id"]) == Stats.selected_character_id:
			cur_idx = i
			break
	var next_idx := (cur_idx + delta_idx + chars.size()) % chars.size()
	Stats.selected_character_id = str(chars[next_idx]["id"])
	Stats.save_stats()
	_refresh_character_ui()

func _refresh_character_ui() -> void:
	if _char_title_lbl == null or _char_meta_lbl == null:
		return
	var chars := CharacterData.all()
	var c := CharacterData.get_character(Stats.selected_character_id)
	var cur_idx := 1
	for i in range(chars.size()):
		if str(chars[i]["id"]) == str(c.get("id", "")):
			cur_idx = i + 1
			break
	var w_cfg := WeaponCatalog.get_weapon(str(c.get("start_weapon", "lotus_slash")))
	var w_name := str(w_cfg.get("name", "青莲剑气"))
	var mode := str(c.get("motion_mode", "hover_ride"))
	var mount := str(c.get("mount_type", "none"))
	var mode_tag := "灵体"
	if mode == "hover_ride":
		match mount:
			"sword": mode_tag = "御剑"
			"cloud": mode_tag = "踏云"
			"fire_wheel": mode_tag = "火轮"
			"gourd": mode_tag = "御葫"
			_: mode_tag = "御空"
	elif mode == "sheet":
		mode_tag = "火铳"
	if _char_portrait != null:
		var sp_path := str(c.get("sprite", ""))
		_char_portrait.texture = load(sp_path) as Texture2D if (sp_path != "" and ResourceLoader.exists(sp_path)) else null
	_char_title_lbl.text = "%s · %s [%s] (%d/%d)" % [str(c.get("name", "沈砚")), str(c.get("role", "御剑道君")), mode_tag, cur_idx, maxi(1, chars.size())]
	_char_meta_lbl.text = "初始【%s】· 身法【%s】· 气血 %d · 移速 %d" % [
		w_name, str(c.get("active_name", "御剑瞬步")), int(c.get("max_health", 120.0)), int(c.get("speed", 250.0))
	]
	if _char_trait_lbl != null:
		_char_trait_lbl.text = "命格：%s" % str(c.get("trait_summary", "均衡全能"))

func _build_stage_selector() -> void:
	var card := PanelContainer.new()
	card.name = "StageSelector"
	card.clip_contents = true
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(640, 82)
	card.add_theme_stylebox_override("panel", XianxiaUITheme.make_hud_plate(XianxiaUITheme.COL_PLATE_BG, XianxiaUITheme.COL_GOLD, 10, 10))
	XianxiaUITheme.attach_ornaments(card, XianxiaUITheme.COL_GOLD, 12.0, 5.0)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(42, 52)
	prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(func(): _shift_stage(-1))
	XianxiaUITheme.style_button(prev_btn, "dark_gold")
	hbox.add_child(prev_btn)

	var info_box := VBoxContainer.new()
	info_box.clip_contents = true
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_box.add_theme_constant_override("separation", 3)
	hbox.add_child(info_box)

	_stage_title_lbl = Label.new()
	_stage_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_title_lbl.custom_minimum_size = Vector2(10, 0)
	_stage_title_lbl.clip_text = true
	_stage_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stage_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_title_lbl.add_theme_font_size_override("font_size", 20)
	_stage_title_lbl.add_theme_color_override("font_color", XianxiaUITheme.COL_GOLD_BRIGHT)
	XianxiaUITheme.apply_text_outline(_stage_title_lbl, 3)
	info_box.add_child(_stage_title_lbl)

	_stage_meta_lbl = Label.new()
	_stage_meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_meta_lbl.custom_minimum_size = Vector2(10, 0)
	_stage_meta_lbl.clip_text = true
	_stage_meta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stage_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_meta_lbl.add_theme_font_size_override("font_size", 14)
	_stage_meta_lbl.add_theme_color_override("font_color", Color(0.86, 0.95, 0.90))
	info_box.add_child(_stage_meta_lbl)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(42, 52)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(func(): _shift_stage(1))
	XianxiaUITheme.style_button(next_btn, "dark_gold")
	hbox.add_child(next_btn)

	vbox.add_child(card)
	vbox.move_child(card, start_btn.get_index())

func _build_sect_button() -> void:
	var row := HBoxContainer.new()
	row.name = "SectDebugRow"
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.custom_minimum_size = Vector2(360, 42)
	row.add_theme_constant_override("separation", 10)

	_sect_btn = Button.new()
	_sect_btn.name = "SectButton"
	_sect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sect_btn.custom_minimum_size = Vector2(0, 42)
	_sect_btn.add_theme_font_size_override("font_size", 19)
	_sect_btn.pressed.connect(_on_sect_pressed)
	row.add_child(_sect_btn)

	_debug_btn = Button.new()
	_debug_btn.name = "DebugSandboxModeButton"
	_debug_btn.text = "演武调试模式"
	_debug_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_btn.custom_minimum_size = Vector2(0, 42)
	_debug_btn.add_theme_font_size_override("font_size", 19)
	_debug_btn.pressed.connect(_on_debug_mode_pressed)
	row.add_child(_debug_btn)

	vbox.add_child(row)
	vbox.move_child(row, start_btn.get_index() + 1)

func _shift_stage(delta_idx: int) -> void:
	var total := ChapterData.count()
	var idx := (Stats.selected_stage_id - 1 + delta_idx + total) % total
	Stats.selected_stage_id = idx + 1
	Stats.save_stats()
	_refresh_stage_ui()

func _refresh_stage_ui() -> void:
	var ch := ChapterData.get_chapter(Stats.selected_stage_id - 1)
	if ch.is_empty():
		return
	var cleared_mark := "  [已通关]" if Stats.is_stage_cleared(int(ch["id"])) else ""
	var mins := int(round(float(ch.get("duration", 480.0)) / 60.0))
	_stage_title_lbl.text = "秘境 %d：%s%s" % [int(ch["id"]), str(ch["name"]), cleared_mark]
	_stage_meta_lbl.text = "%d分钟 · %s · 关底【%s】· 灵石×%.1f" % [
		mins, str(ch.get("difficulty", "")), str(ch.get("boss_name", "")), float(ch.get("stone_mult", 1.0))
	]
	if _sect_btn != null:
		_sect_btn.text = "宗门修炼（灵石 %d）" % Stats.spirit_stones

func _apply_qinglv_theme() -> void:
	XianxiaUITheme.style_button(start_btn, "cinnabar")
	if _sect_btn != null:
		XianxiaUITheme.style_button(_sect_btn, "primary")
	if _debug_btn != null:
		XianxiaUITheme.style_button(_debug_btn, "dark_gold")
	XianxiaUITheme.style_button(settings_btn, "dark_gold")
	XianxiaUITheme.style_button(quit_btn, "dark_gold")

func _refresh_best() -> void:
	best_label.text = Stats.summary_text()
	best_label.visible = Stats.has_history()

func _on_start_pressed() -> void:
	if _starting_game:
		return
	_close_settings()
	_close_sect()
	Music.play_track("battle")
	var status := ResourceLoader.load_threaded_get_status(GameFlow.GAME_SCENE)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(GameFlow.GAME_SCENE) as PackedScene
		GameFlow.start_game_packed(packed)
		return
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_starting_game = true
		start_btn.disabled = true
		_show_loading_overlay()
		return
	GameFlow.start_game()

func _on_quit_pressed() -> void:
	GameFlow.quit_game()

func _on_debug_mode_pressed() -> void:
	if _starting_game:
		return
	_close_settings()
	_close_sect()
	Music.play_track("battle")
	GameFlow.start_debug_sandbox()

func _on_settings_pressed() -> void:
	_close_sect()
	if settings_panel != null and is_instance_valid(settings_panel):
		_close_settings()
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(_close_settings)
	$SettingsLayer.add_child(settings_panel)

func _close_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.queue_free()
	settings_panel = null

func _on_sect_pressed() -> void:
	_close_settings()
	if sect_panel != null and is_instance_valid(sect_panel):
		_close_sect()
		return
	_open_sect_panel()

func _close_sect() -> void:
	if sect_panel != null and is_instance_valid(sect_panel):
		sect_panel.queue_free()
	sect_panel = null
	_refresh_stage_ui()

func _open_sect_panel() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.14, 0.12, 0.52)

	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.offset_left = -350.0
	pc.offset_right = 350.0
	pc.offset_top = -280.0
	pc.offset_bottom = 280.0
	pc.add_theme_stylebox_override("panel", XianxiaUITheme.make_scroll_panel(XianxiaUITheme.COL_GOLD, 18))
	XianxiaUITheme.attach_ornaments(pc, XianxiaUITheme.COL_GOLD, 14.0, 6.0)
	overlay.add_child(pc)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	pc.add_child(root_box)

	var head := Label.new()
	head.text = "宗门修炼 · 十四脉永久根基"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tf = load("res://assets/title_font.tres")
	if tf != null:
		head.add_theme_font_override("font", tf)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", XianxiaUITheme.COL_INK)
	root_box.add_child(head)

	_stone_lbl = Label.new()
	_stone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stone_lbl.add_theme_font_size_override("font_size", 18)
	_stone_lbl.add_theme_color_override("font_color", Color(0.68, 0.36, 0.10))
	root_box.add_child(_stone_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.name = "ListBox"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 7)
	scroll.add_child(list_box)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root_box.add_child(btn_row)

	var recycle_btn := Button.new()
	recycle_btn.name = "RecycleButton"
	recycle_btn.text = "全部回收返还灵石"
	recycle_btn.custom_minimum_size = Vector2(210, 42)
	XianxiaUITheme.style_button(recycle_btn, "cinnabar")
	recycle_btn.pressed.connect(func():
		if Stats.recycle_sect_upgrades() > 0:
			Sfx.play("level_up", -6.0)
			_rebuild_sect_rows(list_box)
			_refresh_stage_ui()
	)
	btn_row.add_child(recycle_btn)

	var close_btn := Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(160, 42)
	XianxiaUITheme.style_button(close_btn, "primary")
	close_btn.pressed.connect(_close_sect)
	btn_row.add_child(close_btn)

	sect_panel = overlay
	$SettingsLayer.add_child(overlay)
	_rebuild_sect_rows(list_box)

func _rebuild_sect_rows(list_box: VBoxContainer) -> void:
	for c in list_box.get_children():
		c.queue_free()
	var invested := Stats.get_sect_invested_stones()
	if _stone_lbl != null:
		_stone_lbl.text = "当前可用灵石：%d · 已投入：%d" % [Stats.spirit_stones, invested]
	for item in Stats.SECT_CATALOG:
		var uid := str(item["id"])
		var lv := Stats.get_sect_level(uid)
		var max_lv := int(item["max"])
		var cost := Stats.get_sect_cost(uid)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "%s (Lv.%d/%d) — %s" % [str(item["name"]), lv, max_lv, str(item["desc"])]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.14, 0.24, 0.22))
		row.add_child(lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(112, 34)
		if cost < 0:
			buy_btn.text = "已圆满"
			buy_btn.disabled = true
		else:
			buy_btn.text = "%d 灵石" % cost
			buy_btn.disabled = Stats.spirit_stones < cost
			buy_btn.pressed.connect(func():
				if Stats.buy_sect_upgrade(uid):
					Sfx.play("level_up", -6.0)
					_rebuild_sect_rows(list_box)
					_refresh_stage_ui()
			)
		XianxiaUITheme.style_button(buy_btn, "primary")
		row.add_child(buy_btn)
		list_box.add_child(row)
