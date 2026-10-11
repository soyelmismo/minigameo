extends SceneTree
## Temporary probe: where does res:// actually point?

func _init() -> void:
	print("cwd=", OS.get_executable_path())
	print("resolved=", ProjectSettings.globalize_path("res://src/player/player_avatar.tscn"))
	var f := FileAccess.open("res://src/player/player_avatar.tscn", FileAccess.READ)
	if f == null:
		print("open failed: ", FileAccess.get_open_error())
	else:
		var txt := f.get_as_text()
		print("--- first 400 chars as Godot sees it ---")
		print(txt)
	quit(0)
