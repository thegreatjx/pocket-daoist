extends Node
# 空间哈希网格：把敌人分离的开销从 O(n^2) 降到 O(n * k)，k 为同格邻居数。
# 每物理帧在所有敌人之前重建一次，敌人只需查询自身所在格的 3x3 邻域。

const CELL_SIZE := 48.0

var cells: Dictionary = {}
var last_node_count: int = 0

func _ready() -> void:
	# 负优先级保证先于敌人执行，敌人查询时网格已是本帧数据
	set_physics_process_priority(-100)

func _physics_process(_delta: float) -> void:
	var nodes = get_tree().get_nodes_in_group("enemies")
	last_node_count = nodes.size()
	rebuild(nodes)

func rebuild(nodes: Array) -> void:
	cells.clear()
	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue
		var key = _key(n.global_position)
		if cells.has(key):
			cells[key].append(n)
		else:
			cells[key] = [n]

func _key(pos: Vector2) -> Vector2i:
	return Vector2i(int(floorf(pos.x / CELL_SIZE)), int(floorf(pos.y / CELL_SIZE)))

# 返回半径内的候选节点。只扫覆盖半径所需的格，结果可能含少量超距项，
# 调用方仍需自行判距。网格未重建时返回空数组，调用方安全降级。
func query(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	if cells.is_empty():
		return result
	var center = _key(pos)
	var span = int(ceilf(radius / CELL_SIZE))
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var k = Vector2i(center.x + dx, center.y + dy)
			if cells.has(k):
				result.append_array(cells[k])
	return result

func cell_count() -> int:
	return cells.size()
