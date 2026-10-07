extends Node
# 战绩存档：记录历史最佳与累计局数，持久化到 user://stats.cfg。
# 独立于 Settings：重置设置不应清空玩家战绩。

const PATH := "user://stats.cfg"
const SECTION := "best"

var best_time: float = 0.0
var best_level: int = 0
var best_kills: int = 0
var total_runs: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_stats()

func load_stats() -> void:
	var cf = ConfigFile.new()
	if cf.load(PATH) != OK:
		return   # 首次运行：保持零值
	best_time = float(cf.get_value(SECTION, "best_time", 0.0))
	best_level = int(cf.get_value(SECTION, "best_level", 0))
	best_kills = int(cf.get_value(SECTION, "best_kills", 0))
	total_runs = int(cf.get_value(SECTION, "total_runs", 0))

func save_stats() -> bool:
	var cf = ConfigFile.new()
	cf.set_value(SECTION, "best_time", best_time)
	cf.set_value(SECTION, "best_level", best_level)
	cf.set_value(SECTION, "best_kills", best_kills)
	cf.set_value(SECTION, "total_runs", total_runs)
	var err = cf.save(PATH)
	if err != OK:
		push_warning("Stats: 保存失败 err=%d" % err)
		return false
	return true

# 每局结束（死亡或主动放弃）调用。返回本局是否刷新了纪录。
func record_run(time_sec: float, level: int, kills: int) -> bool:
	total_runs += 1
	var improved = false
	if time_sec > best_time:
		best_time = time_sec
		improved = true
	if level > best_level:
		best_level = level
		improved = true
	if kills > best_kills:
		best_kills = kills
		improved = true
	save_stats()
	return improved

func has_history() -> bool:
	return total_runs > 0

func format_time(seconds: float) -> String:
	var s = int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]

func summary_text() -> String:
	if not has_history():
		return ""
	return "最长修行 %s · 最高境界 Lv.%d · 最多诛魔 %d · 累计 %d 局" % [
		format_time(best_time), best_level, best_kills, total_runs
	]
