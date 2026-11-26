extends Node2D
class_name DamageNumber

# 伤害飘字：独立 UI 场景，由主 agent 挂到 CanvasLayer 下（Node2D 根节点在 CanvasLayer 里
# 与在世界里都能用，位置是父节点坐标系）。
# 用固定宽度 Label + 居中对齐，避免数字位数变化时左右抖动。

var amount: float = 0.0
var crit: bool = false
var lifetime: float = 0.75
var rise_distance: float = 46.0
var drift: float = 16.0

var _elapsed: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _drift_dir: float = 0.0

@onready var label: Label = get_node_or_null("Label")

func pool_acquire() -> void:
	_elapsed = 0.0
	lifetime = 0.75
	rise_distance = 46.0
	scale = Vector2.ONE
	visible = true
	modulate = Color(1, 1, 1, 1)
	queue_redraw()

# 显示入口：amount 为伤害数值，crit 为是否暴击
func setup(value: float, is_crit: bool = false) -> void:
	amount = value
	crit = is_crit
	_elapsed = 0.0
	_origin = position
	_drift_dir = randf_range(-1.0, 1.0)
	if label == null:
		return
	label.text = _format(amount)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.16, 0.14, 0.95))
	if crit:
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
		label.add_theme_constant_override("outline_size", 5)
		scale = Vector2(1.5, 1.5)
	else:
		var col := Color(0.98, 0.97, 0.90)
		if amount >= 260.0:
			col = Color(1.0, 0.28, 0.30)
		elif amount >= 100.0:
			col = Color(1.0, 0.56, 0.22)
		elif amount >= 30.0:
			col = Color(1.0, 0.90, 0.48)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", col)
		label.add_theme_constant_override("outline_size", 4)
		scale = Vector2.ONE

func setup_reaction(label_text: String, color: Color) -> void:
	amount = 0.0
	crit = false
	_elapsed = 0.0
	lifetime = 0.90
	rise_distance = 54.0
	_origin = position
	_drift_dir = randf_range(-0.5, 0.5)
	if label == null:
		return
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.10, 0.10, 0.96))
	label.add_theme_constant_override("outline_size", 5)
	scale = Vector2(1.18, 1.18)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / maxf(0.01, lifetime), 0.0, 1.0)
	# 上飘带缓出，横向轻微漂移
	position = _origin + Vector2(_drift_dir * drift * t, -rise_distance * (1.0 - pow(1.0 - t, 3.0)))
	modulate.a = 1.0 - t * t
	if crit:
		var s := 1.0 + 0.45 * maxf(0.0, 1.0 - _elapsed / 0.18)
		scale = Vector2(s, s)
	if t >= 1.0:
		# 未登记到对象池的场景路径时，release 会退化为 queue_free
		ObjectPools.release(self)

func _format(value: float) -> String:
	return str(maxi(1, roundi(value))) if value > 0.0 else "0"
