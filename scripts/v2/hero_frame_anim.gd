class_name HeroFrameAnim
extends RefCounted

var atlas: Texture2D = null
var cell: Vector2 = Vector2.ZERO
var columns: int = 1
var frames: int = 0
var fps: float = 24.0
var loop: bool = false
var anchor: Vector2 = Vector2.ZERO
var duration: float = 0.0

var _time: float = 0.0

func load_clip(atlas_path: String, meta_path: String) -> bool:
	if not ResourceLoader.exists(atlas_path) or not FileAccess.file_exists(meta_path):
		return false
	atlas = load(atlas_path) as Texture2D
	if atlas == null:
		return false
	var f := FileAccess.open(meta_path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var meta: Dictionary = parsed
	var pages: Array = (meta.get("fallback", {}) as Dictionary).get("pages", [])
	if pages.is_empty():
		return false
	var page: Dictionary = pages[0]
	var size_arr: Array = meta.get("encodedSize", [0, 0])
	cell = Vector2(float(size_arr[0]), float(size_arr[1]))
	columns = maxi(1, int(page.get("columns", 1)))
	frames = maxi(0, int(page.get("frameCount", meta.get("frameCount", 0))))
	fps = maxf(1.0, float(meta.get("fps", 24.0)))
	loop = bool(meta.get("loop", false))
	duration = maxf(0.001, float(meta.get("durationSeconds", float(frames) / fps)))
	var anchor_arr: Array = meta.get("encodedAnchor", [cell.x * 0.5, cell.y])
	anchor = Vector2(float(anchor_arr[0]), float(anchor_arr[1]))
	return frames > 0 and cell.x > 0.0 and cell.y > 0.0

func reset() -> void:
	_time = 0.0

func update(delta: float) -> void:
	if frames <= 0:
		return
	_time += maxf(0.0, delta)
	if loop:
		_time = fmod(_time, duration)
	else:
		_time = minf(_time, duration)

func frame() -> int:
	if frames <= 0:
		return 0
	return clampi(int(floor(_time * fps)), 0, frames - 1)

func finished() -> bool:
	return not loop and _time >= duration - 0.0001
