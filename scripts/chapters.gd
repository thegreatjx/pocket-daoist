class_name ChapterData

const STAGES_JSON_PATH := "res://data/v2/stages_v2.json"

static var _cached_stages: Array[Dictionary] = []

static func _ensure_loaded() -> void:
	if not _cached_stages.is_empty():
		return
	if not FileAccess.file_exists(STAGES_JSON_PATH):
		push_error("ChapterData: Missing %s" % STAGES_JSON_PATH)
		return
	var txt := FileAccess.get_file_as_string(STAGES_JSON_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("ChapterData: Invalid JSON in %s" % STAGES_JSON_PATH)
		return
	for raw_st in (parsed as Dictionary).get("stages", []):
		if raw_st is Dictionary:
			_cached_stages.append(V2DataLoader.normalize_stage(raw_st))

static func all() -> Array[Dictionary]:
	_ensure_loaded()
	var out: Array[Dictionary] = []
	for st in _cached_stages:
		out.append(st.duplicate(true))
	return out

static func count() -> int:
	_ensure_loaded()
	return _cached_stages.size()

static func get_chapter(index: int) -> Dictionary:
	_ensure_loaded()
	if index < 0 or index >= _cached_stages.size():
		return {}
	return _cached_stages[index].duplicate(true)
