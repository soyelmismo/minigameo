extends GutTest
## Bootstrap composition tests — the main scene (scaffold §5, §6).
##
## Gate: main.tscn loads headless, composes the four layers every system
## expects (World / Player / HUD / Effects), keeps the world rig the
## CameraDirector adopts by name, and leaves the player registered in
## GameServices so other systems resolve it duck-typed (AGENTS.md §1.1)
## instead of reaching into the scene tree.
##
## GPU-free: the 3D nodes are a camera, an environment, a light and greybox
## meshes — all resolve under the dummy headless renderer.

const MAIN_SCENE := "res://src/bootstrap/main.tscn"

var _had_player: bool = false
var _previous_player: Object = null


func before_each() -> void:
	# Snapshot the locator so a registration made here cannot leak into the
	# rest of the suite (other tests resolve &"player" through it).
	var locator: Object = _locator()
	_had_player = locator != null and locator.has_service(&"player")
	_previous_player = locator.resolve(&"player") if _had_player else null


func after_each() -> void:
	# Restore the previous registration when there was one and it is still
	# alive; otherwise unregister the player this test published, so the
	# locator never hands out a freed instance (§1.4: no dirty state).
	var locator: Object = _locator()
	if locator == null:
		return
	if _had_player and _previous_player != null and is_instance_valid(_previous_player):
		locator.register(&"player", _previous_player)
	elif locator.has_method("unregister"):
		locator.unregister(&"player")


## Resolve the service locator by PATH (never by class_name): autoload
## singletons expose no global class_name, and this keeps the test honest
## about how the game itself finds the locator.
func _locator() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameServices")


func _instantiate_main() -> Node:
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "main.tscn loads")
	if scene == null:
		return null
	var main: Node = scene.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


# --- Composition (§5: the scene only hosts layers) ---

func test_main_scene_loads() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "main.tscn loads as a PackedScene")


func test_main_composes_the_four_layers() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	assert_not_null(main.get_node_or_null("World"), "World layer exists")
	assert_not_null(main.get_node_or_null("World/Player"), "Player instanced under World")
	assert_not_null(main.get_node_or_null("HUD"), "HUD layer exists")
	assert_not_null(main.get_node_or_null("Effects"), "screen-effects overlay exists")


func test_main_hosts_the_world_rig() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	# Matched by type, not by node name: the scene's node names are unstable
	# placeholders, and a name-based lookup silently found nothing.
	assert_not_null(_first_of_type(main, "WorldEnvironment"), "environment present")
	assert_not_null(_first_of_type(main, "DirectionalLight3D"), "sun present")
	assert_not_null(_first_of_type(main, "Camera3D"), "camera present")


## Depth-first search for the first node of a given class under `root`.
func _first_of_type(root: Node, type_name: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_class(type_name):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func test_effects_layer_sits_above_the_hud() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	var hud: CanvasLayer = main.get_node_or_null("HUD") as CanvasLayer
	var effects: CanvasLayer = main.get_node_or_null("Effects") as CanvasLayer
	assert_not_null(hud, "HUD present")
	assert_not_null(effects, "Effects present")
	if hud == null or effects == null:
		return
	assert_gt(effects.layer, hud.layer, "flash overlay renders above the HUD")


# --- Player registration (§6) ---

func test_player_is_registered_in_game_services() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	var player: Node = main.get_node_or_null("World/Player")
	assert_not_null(player, "player instanced under World")
	var locator: Object = _locator()
	assert_not_null(locator, "GameServices locator available")
	if locator == null or player == null:
		return
	assert_true(locator.has_service(&"player"), "player published as a service")
	assert_eq(locator.resolve(&"player"), player, "the registered service IS the scene player")


func test_player_spawn_position_is_applied_from_data() -> void:
	var main := await _instantiate_main()
	if main == null:
		return
	var player: Node3D = main.get_node_or_null("World/Player") as Node3D
	assert_not_null(player, "player instanced under World")
	if player == null:
		return
	# Default export from main.gd — no magic numbers inline (§1.3).
	assert_almost_eq(player.position.y, 1.0, 0.001, "avatar spawns one unit above the block")
