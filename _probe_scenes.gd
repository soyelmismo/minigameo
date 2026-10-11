extends SceneTree


func _initialize() -> void:
	var out: Array = []
	var ts: GDScript = load("res://src/ui/screens/title_screen.gd") as GDScript
	out.append("title_screen.gd null=" + str(ts == null))
	if ts != null:
		out.append("can_instantiate=" + str(ts.can_instantiate()))
		out.append("reload_keep_state=" + str(ts.reload(true) == OK))
		out.append("after_reload can_instantiate=" + str(ts.can_instantiate()))
	for p: String in [
		"res://src/ui/screens/title_screen.gd",
		"res://src/ui/screens/pause_menu.gd",
		"res://src/ui/screens/results_screen.gd",
		"res://src/ui/screens/settings_panel.gd",
		"res://src/ui/screens/accessibility_settings.gd",
	]:
		var s: GDScript = load(p) as GDScript
		var ok: bool = s != null and s.can_instantiate() and s.reload(true) == OK
		out.append(String(p) + " COMPILES=" + str(ok))
	var w := FileAccess.open("res://_probe_out.txt", FileAccess.WRITE)
	w.store_string("\n".join(out))
	w.close()
	quit()
