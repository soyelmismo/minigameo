extends SceneTree
func _sep(s: String) -> String:
	var o := ""
	for ch: String in s:
		o += ch + "|"
	return o
func _init() -> void:
	var f := FileAccess.open("res://src/bootstrap/main.tscn", FileAccess.READ)
	var t: String = f.get_as_text()
	print("len=", t.length())
	for line: String in t.split("\n"):
		if line.strip_edges() != "":
			print(_sep(line))
	quit(0)
