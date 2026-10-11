extends SceneTree

func _dump(path: String) -> void:
	print("========== %s" % path)
	var ps: PackedScene = load(path)
	var n := ps.instantiate()
	print("  root name='%s' class=%s script=%s" % [n.name, n.get_class(), n.get_script()])
	for c in n.get_children():
		print("  child '%s' (%s)" % [c.name, c.get_class()])
	n.free()

func _init() -> void:
	_dump("res://_probe_plain.tscn")
	_dump("res://_probe_classname.tscn")
	_dump("res://_probe_child.tscn")
	quit(0)
