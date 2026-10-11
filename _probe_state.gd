extends SceneTree
## Temporary probe: what does Godot's loader ACTUALLY see for main.tscn and
## the sub-scenes? Compares raw file text vs loaded PackedScene state.

func _dump(path: String) -> void:
	print("========== %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("  FILE OPEN FAILED err=", FileAccess.get_open_error())
	else:
		var txt := f.get_as_text()
		print("  bytes=%d lines=%d" % [txt.length(), txt.count("\n")])
		for line: String in txt.split("\n"):
			if line.begins_with("[node"):
				print("    FILE: ", line)
	var ps: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if ps == null:
		print("  LOAD FAILED")
		return
	print("  scene_file_path=", ps.scene_file_path)
	var st := ps.get_state()
	print("  SceneState nodes=%d" % st.get_node_count())
	for i in st.get_node_count():
		print("    STATE[%d] name='%s' type='%s'" % [i, st.get_node_name(i), st.get_node_type(i)])
	var n := ps.instantiate()
	print("  instantiated root='%s' (%s) children=%d" % [n.name, n.get_class(), n.get_child_count()])
	_print_tree(n, "    ")
	n.free()

func _print_tree(node: Node, indent: String) -> void:
	for c in node.get_children():
		print("%s'%s' (%s) script=%s" % [indent, c.name, c.get_class(), "yes" if c.get_script() != null else "no"])
		_print_tree(c, indent + "  ")

func _init() -> void:
	_dump("res://src/bootstrap/main.tscn")
	_dump("res://src/player/player_avatar.tscn")
	_dump("res://src/world/city_block.tscn")
	quit(0)
