extends SceneTree

func _init() -> void:
	var r: Resource = load("res://probe_meta.tres")
	print("PROBE meta null? ", r == null)
	if r:
		print("PROBE get_meta(max_run_speed)=", r.get_meta("max_run_speed", "<none>"))
		print("PROBE has_meta(move_response)=", r.has_meta("move_response"))
		var c: Resource = Resource.new()
	c.set_meta("x", 1.0)
	print("PROBE Resource.new() set/get_meta ok")
	quit(0)
