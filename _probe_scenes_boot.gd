extends SceneTree
## Temporary probe (integration agent): verify the sub-scenes to be instanced
## in main.tscn load and instantiate headless. Deleted after use.

func _init() -> void:
	for path in [
		"res://src/world/city_block.tscn",
		"res://src/player/player_avatar.tscn",
		"res://src/ui/hud/hud.tscn",
		"res://src/juice/screen_effects/screen_effects.tscn",
	]:
		print("=== %s" % path)
		var s: PackedScene = load(path)
		print("  packed: ", s)
		if s == null:
			continue
		var n := s.instantiate()
		print("  root: '%s' (%s) children=%d" % [n.name, n.get_class(), n.get_child_count()])
		for c in n.get_children():
			print("    child: '%s' (%s)" % [c.name, c.get_class()])
		n.free()
	quit(0)
