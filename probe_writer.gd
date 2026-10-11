extends SceneTree

func _init() -> void:
	var cfg: Resource = load("res://src/player/player_motor.gd").new() if false else null
	# instantiate inner class via the outer script's constants
	var outer: GDScript = load("res://src/player/player_motor.gd")
	var cfg_class: GDScript = outer.get("PlayerMotorConfig")
	var c: Resource = cfg_class.new()
	c.set("run_speed", 9.5)
	var err: int = ResourceSaver.save(c, "res://src/player/player_motor.tres")
	print("PROBE save err=", err)
	var back: Resource = load("res://src/player/player_motor.tres")
	print("PROBE back null? ", back == null)
	if back:
		print("PROBE back run_speed=", back.get("run_speed"))
	quit(0)
