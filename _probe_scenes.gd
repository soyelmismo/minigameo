extends SceneTree


func _dump(node: Node, depth: int) -> void:
	var uniq := " [UNIQUE]" if node.unique_name_in_owner else ""
	print("  ".repeat(depth), "NAME=", node.name, " CLASS=", node.get_class(), uniq,
		" SCRIPT=", (node.get_script().resource_path if node.get_script() != null else "<NONE>"))
	for child: Node in node.get_children():
		_dump(child, depth + 1)


func _initialize() -> void:
	var p := "res://src/ui/screens/title_screen.tscn"
	var f := FileAccess.open(p, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	print("DISK md5=", raw.md5_text(), " len=", raw.length())
	print("DISK contains 'TitleScreen': ", raw.contains("TitleScreen"))
	print("DISK contains 'LogoPanel': ", raw.contains("LogoPanel"))

	print("--- loaded via load() ---")
	var ps: PackedScene = load(p)
	var n := ps.instantiate()
	_dump(n, 1)
	print("--- node names from disk file? ---")
	print("has child 'TitleScreen': ", n.has_node("TitleScreen"))
	print("has child 'Background': ", n.has_node("Background"))
	print("--- resource path / uid ---")
	print("ps resource_path=", ps.resource_path)
	var all_tscn: PackedStringArray = ResourceLoader.list_directory("res://src/ui/screens/")
	print("list_directory src/ui/screens: ", all_tscn)
	quit()
