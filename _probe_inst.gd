extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://src/bootstrap/main.tscn")
	print("ps=", ps)
	var n := ps.instantiate()
	get_root().add_child(n)
	await process_frame
	_print(n, 0)
	quit(0)

func __print(node: Node, d: int) -> void:
	var ind := ""
	for i in d:
		ind += "  "
	print("%s'%s' (%s)" % [ind, node.name, node.get_class()])
	for c in node.get_children():
		_print(c, d + 1)
