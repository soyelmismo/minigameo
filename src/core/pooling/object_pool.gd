class_name ObjectPool
extends RefCounted
## Generic scene pool (scaffold §6 core + §1.4 clean-teardown rule).
##
## acquire() returns a node from the pool (instantiating lazily up to the
## max size); release() returns it. Hot paths (minigames, impacts) use this
## instead of queue_free to avoid GC spikes (scaffold §7 budgets).

var _scene: PackedScene
var _parent: Node
var _max: int
var _auto_grow: bool
var _free: Array[Node] = []
var _live: int = 0


func _init(scene: PackedScene, parent: Node, max_size: int = 64, auto_grow: bool = true) -> void:
	_scene = scene
	_parent = parent
	_max = max_size
	_auto_grow = auto_grow


## Borrow a node. The caller must release() it when done.
func acquire() -> Node:
	if not _free.is_empty():
		var reused: Node = _free.pop_back()
		_set_active(reused, true)
		_live += 1
		return reused
	if _live >= _max and not _auto_grow:
		return null
	if _scene == null or _parent == null:
		return null
	var node: Node = _scene.instantiate()
	_parent.add_child(node)
	_live += 1
	return node


## Return a node to the pool. Hides it and parks it; never queue_free in
## hot paths (AGENTS.md §1.4).
func release(node: Node) -> void:
	if node == null:
		return
	_set_active(node, false)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_parent.add_child(node)
	if _free.size() < _max:
		_free.append(node)
	else:
		node.queue_free()
	_live = maxi(_live - 1, 0)


## Toggle visibility/collision across node kinds (Node base has no `visible`).
func _set_active(node: Node, active: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = active
	if node is CollisionObject3D:
		(node as CollisionObject3D).process_mode = (
			Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		)
	if node is Node3D:
		(node as Node3D).visible = active


## Nodes currently borrowed.
func live_count() -> int:
	return _live


## Nodes parked in the pool.
func idle_count() -> int:
	return _free.size()


## Free everything (match teardown / shutdown).
func clear() -> void:
	for node in _free:
		if is_instance_valid(node):
			node.queue_free()
	_free.clear()
	_live = 0
