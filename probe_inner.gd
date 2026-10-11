extends SceneTree

func _init() -> void:
	# A: inner class via :: path
	var inner: GDScript = load("res://src/player/player_motor.gd::PlayerMotorConfig")
	print("PROBE inner-class path load null? ", inner == null)
	if inner:
		var c: Resource = inner.new()
		print("PROBE inner default run_speed=", c.get("run_speed"))

	# B: script-less .tres with custom props
	var err: int = ResourceSaver.save(make_plain(), "res://probe_plain.tres")
	print("PROBE plain save err=", err)
	var back: Resource = load("res://probe_plain.tres")
	print("PROBE plain back null? ", back == null)
	if back:
		print("PROBE plain get(run_speed)=", back.get("run_speed"), " has_method_meta=", back.has_meta("run_speed"))
		print("PROBE plain get_meta=", back.get_meta("run_speed", "<none>"))
	print("PROBE plain file:")
	var f: FileAccess = FileAccess.open("res://probe_plain.tres", FileAccess.READ)
	if f:
		print(f.get_as_text())
	quit(0)

func make_plain() -> Resource:
	var r: Resource = Resource.new()
	r.set_meta("run_speed", 9.5)
	return r
