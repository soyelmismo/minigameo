extends SceneTree


func _dump(node: Node, depth: int) -> void:
	var uniq := " [UNIQUE]" if node.unique_name_in_owner else ""
	print("  ".repeat(depth), node.name, " (", node.get_class(), ")", uniq)
	for child: Node in node.get_children():
		_dump(child, depth + 1)


func _initialize() -> void:
	for path: String in [
		"res://src/ui/screens/title_screen.tscn",
		"res://src/ui/screens/pause_menu.tscn",
		"res://src/ui/screens/results_screen.tscn",
		"res://src/ui/screens/settings_panel.tscn",
	]:
		print("===== ", path)
		var ps: PackedScene = load(path)
		if ps == null:
			print("  FAILED TO LOAD")
			continue
		var n := ps.instantiate()
		_dump(n, 1)
		n.free()
	quit()
