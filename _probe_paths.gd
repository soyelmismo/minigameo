extends SceneTree
## Probe: resolve the node paths the project's scripts actually depend on,
## so the composition is grounded in runtime truth, not in displayed text.

func _check(scene_root: Node, path: String) -> void:
	var n: Node = scene_root.get_node_or_null(path)
	print("  %-46s -> %s" % [path, "OK '%s' (%s)" % [n.name, n.get_class()] if n != null else "MISSING"])

func _init() -> void:
	var ps: PackedScene = load("res://src/bootstrap/main.tscn")
	var main := ps.instantiate()
	print("=== main.tscn root='%s' (%s) script=%s" % [main.name, main.get_class(), "yes" if main.get_script() != null else "no"])
	for p: String in ["World", "UI", "World/WorldEnvironment", "World/DirectionalLight3D", "World/Ground", "World/Camera3D"]:
		_check(main, p)
	main.free()

	for pair: Array in [
		["res://src/world/city_block.tscn", "SpawnPoints"],
		["res://src/player/player_avatar.tscn", "PlayerMotor"],
		["res://src/player/player_avatar.tscn", "PlayerInput"],
		["res://src/ui/hud/hud.tscn", "Root"],
		["res://src/juice/screen_effects/screen_effects.tscn", "FlashRect"],
	]:
		var s: PackedScene = load(pair[0])
		var n := s.instantiate()
		print("=== %s root='%s'" % [pair[0], n.name])
		_check(n, String(pair[1]))
		n.free()
	quit(0)
