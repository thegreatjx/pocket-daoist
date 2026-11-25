extends Node
# 玩家设置读写与持久化，保存到 user://settings.cfg。
# 写入即保存并立即生效，界面只需调用 set_value()。

const PATH := "user://settings.cfg"

# 默认值。键格式为 "分区/键名"，与 ConfigFile 的两级结构对应。
const DEFAULTS := {
	"audio/master_volume_db": 0.0,
	"audio/music_volume_db": -6.0,
	"audio/sfx_volume_db": -3.0,
	"video/screen_shake": true,
	"video/hit_flash": true,
	"video/hitstop": true,
	"ui/hint_enabled": true,
}

const BUS_OF := {
	"audio/master_volume_db": "Master",
	"audio/music_volume_db": "Music",
	"audio/sfx_volume_db": "SFX",
}

var values: Dictionary = {}
var save_count: int = 0      # 供测试断言
var last_load_error: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()

func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cf = ConfigFile.new()
	last_load_error = cf.load(PATH)
	if last_load_error != OK:
		# 首次运行或文件损坏：用默认值，不视为错误
		return
	for key in DEFAULTS.keys():
		var parts = key.split("/")
		if cf.has_section_key(parts[0], parts[1]):
			values[key] = cf.get_value(parts[0], parts[1], DEFAULTS[key])

func save_settings() -> bool:
	var cf = ConfigFile.new()
	for key in values.keys():
		var parts = key.split("/")
		cf.set_value(parts[0], parts[1], values[key])
	var err = cf.save(PATH)
	if err != OK:
		push_warning("Settings: 保存失败 err=%d" % err)
		return false
	save_count += 1
	return true

func get_value(key: String):
	return values.get(key, DEFAULTS.get(key, null))

func get_bool(key: String) -> bool:
	return bool(get_value(key))

func get_float(key: String) -> float:
	return float(get_value(key))

# 仅生效、不落盘。滑条拖动过程中调用，避免每帧写磁盘。
func stage_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = value
	apply(key)

# 生效并立即落盘。滑条松手、开关切换时调用。
func set_value(key: String, value) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: 未知设置项 %s" % key)
		return
	values[key] = value
	apply(key)
	save_settings()

func reset_to_defaults() -> void:
	values = DEFAULTS.duplicate()
	apply_all()
	save_settings()

func apply_all() -> void:
	for key in values.keys():
		apply(key)

func apply(key: String) -> void:
	if BUS_OF.has(key):
		var bus = AudioServer.get_bus_index(BUS_OF[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, float(values[key]))
			AudioServer.set_bus_mute(bus, float(values[key]) <= -60.0)

# 供 UI 把滑条值（线性 0..1）与分贝互转。
# 低于 -60 dB 视为静音，避免对数在 0 附近发散。
func linear_to_db(linear: float) -> float:
	if linear <= 0.001:
		return -60.0
	return 20.0 * log(linear) / log(10.0)

func db_to_linear(db_value: float) -> float:
	if db_value <= -60.0:
		return 0.0
	return pow(10.0, db_value / 20.0)
