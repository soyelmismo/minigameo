extends SceneTree

func _init() -> void:
	var cfg: Resource = load("res://scratch_cfg.tres")
	if cfg == null:
		print("PROBE: tres load failed")
		quit(1)
		return
	print("PROBE: loaded ok, run_speed=", cfg.get("run_speed"))
	print("PROBE: script_path=", cfg.get_script().resource_path if cfg.get_script() else "<none>")
	quit(0)
