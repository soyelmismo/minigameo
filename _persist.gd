extends SceneTree
func _initialize() -> void:
	var mgr: Object = root.get_node_or_null("/root/SettingsManager") as Object
	var out: Array = []
	mgr.set_value("shake_intensity", 0.3)
	mgr.set_value("colorblind_indicators", true)
	mgr.set_value("subtitles_enabled", false)
	mgr.set_value("text_speed", 1.7)
	mgr.set_value("flashes_enabled", false)
	out.append("written: shake=" + str(mgr.get_value("shake_intensity")) + " cb=" + str(mgr.get_value("colorblind_indicators")) + " sub=" + str(mgr.get_value("subtitles_enabled")) + " speed=" + str(mgr.get_value("text_speed")) + " flash=" + str(mgr.get_value("flashes_enabled")))
	var w := FileAccess.open("res://_persist_out.txt", FileAccess.WRITE)
	w.store_string("\n".join(out))
	w.close()
	quit(0)
