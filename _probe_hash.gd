extends SceneTree
func _init() -> void:
	for p: String in ["res://_probe_known.txt", "res://src/bootstrap/main.tscn", "res://src/player/player_avatar.tscn"]:
		var f := FileAccess.open(p, FileAccess.READ)
		var t: String = f.get_as_text()
		print("godot ", p, " md5=", t.md5_text(), " len=", t.length())
	quit(0)
