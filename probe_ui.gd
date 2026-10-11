extends SceneTree

func _initialize() -> void:
	var s: GDScript = load("res://src/ui/hud/widgets/timer_widget.gd")
	print("loaded: %s" % s)
	quit(0)
