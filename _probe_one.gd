extends SceneTree
## Temporary probe: in ONE process, compare raw bytes vs loaded scene.

func _dump(path: String) -> void:
	print("========== %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	var txt: String = f.get_as_text() if f != null else "<open failed %d>" % FileAccess.get_open_error()
	print("  FILE length=%d" % txt.length())
	for line: String in txt.split("\n"):
		if line.begins_with("[node"):
			print("    FILE: ", line)
	var ps: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	print("  load -> ", ps, " resource_path=", ps.resource_path if ps != null else "-")
	var st := ps.get_state()
	print("  SceneState nodes=%d" % st.get_node_count())
	for i in st.get_node_count():
		print("    STATE[%d] name='%s' type='%s'" % [i, st.get_node_name(i), st.get_node_type(i)])
	var n := ps.instantiate()
	print("  instantiated root='%s' (%s)" % [n.name, n.get_class()])
	for c in n.get_children():
		print("    child '%s' (%s)" % [c.name, c.get_class()])
	n.free()

func _init() -> void:
	_dump("res://src/player/player_avatar.tscn")
	quit(0)
