extends SceneTree

func _init() -> void:
	var inner_cls: GDScript = load("res://src/player/player_motor.gd").get("PlayerMotorConfig")
	print("PROBE inner_cls null? ", inner_cls == null)
	if inner_cls == null:
		quit(1)
		return
	for path in ["res://probe_variant_a.tres", "res://probe_variant_b.tres"]:
		var r: Resource = load(path)
		print("PROBE ", path, " null? ", r == null)
		if r == null:
			continue
		var s: Script = r.get_script()
		print("  script null? ", s == null)
		if s != null:
			print("  script path=", s.resource_path)
			print("  script global_name=", s.get_global_name())
		print("  get(run_speed)=", r.get("run_speed"))
		var is_inner: bool = r.get_script() == inner_cls
		print("  script is inner class? ", is_inner)
	quit(0)
