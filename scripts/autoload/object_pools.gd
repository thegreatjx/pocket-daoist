extends Node
# 通用对象池：归还时把节点移出场景树但保留实例，取用时再挂回。
# 省掉 instantiate() 与 queue_free() 的分配与垃圾回收开销。
# 被池化的对象需实现 pool_acquire()，用于取用时重置自身状态。

var _pools: Dictionary = {}   # scene_path -> { "scene", "free", "active" }

func _ready() -> void:
	# 池数组独占持有已脱离场景树的节点，Godot 不会自动释放这类孤儿节点。
	# 退出场景树时必须显式释放，否则进程退出时报 RID / ObjectDB 泄漏。
	tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	clear()

func _get_pool(scene_path: String) -> Dictionary:
	if not _pools.has(scene_path):
		var scene = load(scene_path)
		if scene == null:
			push_error("ObjectPools: 无法加载场景 %s" % scene_path)
			return {}
		_pools[scene_path] = { "scene": scene, "free": [], "active": 0 }
	return _pools[scene_path]

func active_count(scene_path: String) -> int:
	if not _pools.has(scene_path):
		return 0
	return _pools[scene_path]["active"]

func free_count(scene_path: String) -> int:
	if not _pools.has(scene_path):
		return 0
	return _pools[scene_path]["free"].size()

func pooled_scenes() -> Array:
	return _pools.keys()

# 取用一个对象并挂到 parent 下。max_active > 0 时超额返回 null（用于特效限流）。
func acquire(scene_path: String, parent: Node, max_active: int = 0) -> Node:
	var pool = _get_pool(scene_path)
	if pool.is_empty():
		return null
	if parent == null or not is_instance_valid(parent):
		return null
	if max_active > 0 and pool["active"] >= max_active:
		return null

	var obj: Node = null
	while pool["free"].size() > 0:
		var cand = pool["free"].pop_back()
		if cand != null and is_instance_valid(cand):
			obj = cand
			break
	if obj == null:
		obj = pool["scene"].instantiate()

	parent.add_child(obj)
	obj.visible = true
	pool["active"] += 1
	if obj.has_method("pool_acquire"):
		obj.pool_acquire()
	return obj

# 归还对象。非池化对象（scene_file_path 未注册）退化为正常释放。
func release(obj: Node) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var path = obj.scene_file_path
	if path == "" or not _pools.has(path):
		obj.queue_free()
		return
	var pool = _pools[path]
	if obj.get_parent() != null:
		obj.get_parent().remove_child(obj)
	obj.visible = false
	pool["active"] = maxi(0, pool["active"] - 1)
	pool["free"].append(obj)

# 清空所有池：场景重载与进程退出前调用
func clear() -> void:
	for path in _pools.keys():
		var pool = _pools[path]
		for obj in pool["free"]:
			if obj != null and is_instance_valid(obj):
				obj.free()
		pool["free"].clear()
		pool["active"] = 0
