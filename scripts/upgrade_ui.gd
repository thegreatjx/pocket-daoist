extends CanvasLayer
class_name UpgradeUI

signal upgrade_selected(upgrade_id: String)

var is_showing: bool = false

@onready var container: HBoxContainer = $Panel/CardContainer
@onready var title_label: Label = $Panel/TitleLabel

func show_choices(choices: Array, remaining_after: int = 0) -> void:
	# 清空旧卡片：先脱离容器，再延迟释放。
	# 不能用 free()：卡片按钮正在发射 pressed 信号时对象被锁定，free() 会报错。
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

	if remaining_after > 0:
		title_label.text = "境界精进 · 机缘降临（其后还有 %d 次机缘）" % remaining_after
	else:
		title_label.text = "境界精进 · 机缘降临"

	visible = true
	is_showing = true
	get_tree().paused = true

	for item in choices:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(250, 320)
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		# 顶部标签
		var tag_lbl = Label.new()
		tag_lbl.text = "\n" + item["tag"]
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.modulate = Color(0.4, 0.9, 1.0)
		vbox.add_child(tag_lbl)

		# 标题
		var name_lbl = Label.new()
		name_lbl.text = item["title"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 22)
		if item.get("is_evo", false):
			name_lbl.modulate = Color(1.0, 0.85, 0.2)
		vbox.add_child(name_lbl)

		# 分割
		var hs = HSeparator.new()
		vbox.add_child(hs)

		# 等级显示
		var lvl_lbl = Label.new()
		lvl_lbl.text = "修习进度: %d / %d" % [item["level"], item["max_level"]]
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(lvl_lbl)

		# 描述
		var desc_lbl = Label.new()
		desc_lbl.text = "\n" + item["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(desc_lbl)

		# 点击信号
		var uid = item["id"]
		btn.pressed.connect(func():
			_on_card_pressed(uid)
		)
		container.add_child(btn)

func _on_card_pressed(uid: String) -> void:
	visible = false
	is_showing = false
	get_tree().paused = false
	emit_signal("upgrade_selected", uid)

func hide_and_unpause() -> void:
	visible = false
	is_showing = false
	get_tree().paused = false
