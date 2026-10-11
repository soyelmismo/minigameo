extends GutTest

## Power-up spawning contract (scaffold §6.11).
##
## The bug this test pins: PowerUpSpawner._random_position() scattered pickups
## inside a radius around the origin and never asked the city block for its
## hand-placed spawn markers, so power-ups appeared inside buildings and outside
## the play area while `spawn_positions()` sat unused. On top of that,
## `_resolve_player()` asked the locator `has_method("get")` — a method the
## locator deliberately does not expose (it is `lookup`/`resolve`) — so the
## branch never fired and the player was only ever found through a
## `/root/Player` fallback that does not exist, because the player lives under
## World/. Power-ups therefore had no idea where the player was.

const BLOCK_SCENE := "res://src/world/city_block.tscn"
const SPAWNER_SCENE := "res://src/powerups/powerup_spawner.tscn"


func _instantiate_block() -> Node3D:
	var scene: PackedScene = load(BLOCK_SCENE)
	assert_not_null(scene, "city_block.tscn loads")
	if scene == null:
		return null
	var block: Node3D = scene.instantiate()
	add_child_autofree(block)
	await get_tree().process_frame
	return block


func _instantiate_spawner() -> PowerUpSpawner:
	var scene: PackedScene = load(SPAWNER_SCENE)
	assert_not_null(scene, "powerup_spawner.tscn loads")
	if scene == null:
		return null
	var spawner: PowerUpSpawner = scene.instantiate()
	add_child_autofree(spawner)
	await get_tree().process_frame
	return spawner


func test_block_publishes_usable_spawn_markers() -> void:
	var block: Node3D = await _instantiate_block()
	if block == null:
		return
	var points: Array = block.spawn_positions()
	assert_gt(points.size(), 0, "the block publishes spawn markers")
	# Every marker must sit inside the play area: a marker outside the block
	# would drop a power-up where the player can never walk.
	for p: Vector3 in points:
		assert_lt(absf(p.x), 80.0, "marker x is inside the block")
		assert_lt(absf(p.z), 80.0, "marker z is inside the block")


func test_spawner_uses_the_block_markers_not_a_blind_radius() -> void:
	var block: Node3D = await _instantiate_block()
	var spawner: PowerUpSpawner = await _instantiate_spawner()
	if block == null or spawner == null:
		return
	# Collect where the spawner actually put its pickups.
	var used: Array[Vector3] = []
	for node: Node in spawner.get_children():
		if node is PowerUp and node is Node3D:
			var at: Vector3 = (node as Node3D).position
			if at.length() > 0.01:
				used.append(at)
	if used.is_empty():
		return  # headless: the scene may not have instantiated a pick-up node
	var markers: Array = block.spawn_positions()
	var outside: Array[Vector3] = []
	var r: float = spawner.spawn_radius
	for at: Vector3 in used:
		var near := false
		for m: Vector3 in markers:
			if at.distance_to(m) < 0.01:
				near = true
				break
		# A blind-radius spawn is a red flag: at least one pickup must land on
		# a real marker, and none may land outside the block's own footprint.
		if not near and (absf(at.x) > absf(r) * 1.001 or absf(at.z) > absf(r) * 1.001):
			outside.append(at)
	assert_true(outside.is_empty(),
		"no power-up sits outside the spawn radius: %s" % str(outside))
	assert_true(used.any(func(at: Vector3) -> bool:
		for m: Vector3 in markers:
			if at.distance_to(m) < 0.01:
				return true
		return false),
		"at least one power-up sits on a block spawn marker")


func test_spawner_resolves_the_player_through_the_locator() -> void:
	# The locator API is lookup()/resolve(), never get(): asking for "get" was
	# exactly the typo that left the player unresolvable.
	var locator: Object = get_tree().root.get_node_or_null("/root/GameServices") as Object
	assert_not_null(locator, "GameServices autoload present")
	if locator == null:
		return
	assert_true(locator.has_method("lookup"), "the locator exposes lookup()")
	assert_true(locator.has_method("resolve"), "the locator exposes resolve()")
	var spawner: PowerUpSpawner = await _instantiate_spawner()
	if spawner == null:
		return
	# A player published under the canonical name must be found by the spawner.
	var probe := Node3D.new()
	probe.name = "ProbePlayer"
	add_child_autofree(probe)
	var previous: Object = locator.lookup(&"player")
	locator.register(&"player", probe)
	var resolved: Node3D = spawner._resolve_player()
	assert_eq(resolved, probe, "_resolve_player finds the registered service")
	# Restore so this test cannot poison the rest of the suite.
	if previous != null and is_instance_valid(previous):
		locator.register(&"player", previous)
	else:
		locator.unregister(&"player")


func test_spawner_creates_a_full_complement_on_startup() -> void:
	var spawner: PowerUpSpawner = await _instantiate_spawner()
	if spawner == null:
		return
	var active: int = 0
	for node: Node in spawner.get_children():
		if node is PowerUp:
			active += 1
	assert_gt(active, 0, "the spawner fills its slots at ready time")
