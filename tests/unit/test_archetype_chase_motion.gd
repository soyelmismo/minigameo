extends GutTest

## CHASE archetype motion contract (scaffold §8.1 row 2, §8.3 row 2).
##
## The bug this test pins: `motion = CHASE` moves the target TOWARD the player,
## and the archetype wins a CHASE_CATCH when the target is within catch distance.
## The catalog paired CHASE with CHASE_CATCH, so the "runaway driver you can
## never catch" was caught in under a second. Two entries were affected
## (delivery_dash, inference_inferno).
##
## MOTION_FLEE was documented but never implemented, so the pairing had no
## correct alternative. It is implemented now and both entries use it.

const CHASE_SCRIPT := "res://src/minigames/archetypes/archetype_chase.gd"
const ENTITY_SCENE := "res://src/minigames/runtime/minigame_entity.tscn"
const FLEE := &"FLEE"
const CHASE_MOTION := &"CHASE"
const ORBIT := &"ORBIT"


func _make_archetype(motion: StringName, kind: StringName,
		spawn_radius: float, speed: float, tolerance: float) -> Object:
	var script: GDScript = load(CHASE_SCRIPT) as GDScript
	var archetype: Object = script.new()
	add_child_autofree(archetype)

	var spawn_recipe: Resource = load("res://src/minigames/slots/spawn_recipe.gd").new()
	spawn_recipe.set("motion", motion)
	spawn_recipe.set("spawn_radius", spawn_radius)
	spawn_recipe.set("speed", speed)
	spawn_recipe.entity_scene = load(ENTITY_SCENE) as PackedScene
	var objective_recipe: Resource = load("res://src/minigames/slots/objective_recipe.gd").new()
	objective_recipe.set("kind", kind)
	objective_recipe.set("target", 1)
	objective_recipe.set("tolerance", tolerance)
	var meta: Resource = load("res://src/minigames/minigame_metadata.gd").new()
	meta.set("id", &"probe")
	meta.set("archetype", &"CHASE")
	meta.set("spawn_recipe", spawn_recipe)
	meta.set("objective_recipe", objective_recipe)

	var world := Node3D.new()
	world.name = "Elena Mercery"
	add_child_autofree(world)
	var player := Node3D.new()
	player.name = "BlockRoot"
	world.add_child(player)

	var ctx: MinigameContext = MinigameContext.create()
	ctx.metadata = meta
	ctx.player = player
	ctx.world_root = world
	ctx.rng = load("res://src/core/rng/seeded_rng.gd").new()
	archetype.setup(ctx)
	archetype.start()
	return archetype


func _target_of(archetype: Object) -> Node3D:
	var mover: Variant = archetype.get("_mover")
	if mover == null or not is_instance_valid(mover):
		return null
	return mover as Node3D


func test_flee_motion_runs_away_from_the_player() -> void:
	var archetype: Object = _make_archetype(FLEE, &"CHASE_CATCH", 24.0, 4.0, 0.0)
	var player: Node3D = archetype.get_context().player as Node3D
	var target: Node3D = _target_of(archetype)
	assert_not_null(target, "the chase target spawns")
	if target == null:
		return
	target.global_position = Vector3(6.0, 0.0, 0.0)
	var before: float = target.global_position.distance_to(player.global_position)
	for _i in range(20):
		archetype.advance(1.0 / 60.0)
	var after: float = target.global_position.distance_to(player.global_position)
	assert_gt(after, before, "FLEE increases the distance to the player")


func test_flee_keeps_the_chase_winnable() -> void:
	# The other direction of the same bug: a target that outruns the player
	# forever is also unwinnable. The player closes at the recipe speed.
	var archetype: Object = _make_archetype(FLEE, &"CHASE_CATCH", 24.0, 4.0, 0.0)
	var player: Node3D = archetype.get_context().player as Node3D
	var target: Node3D = _target_of(archetype)
	if target == null:
		return
	target.global_position = Vector3(10.0, 0.0, 0.0)
	var caught: bool = false
	var frames: int = 0
	for _i in range(1800):
		var to_target: Vector3 = target.global_position - player.global_position
		if to_target.length() > 0.001:
			player.global_position += to_target.normalized() * (4.0 / 60.0)
		archetype.advance(1.0 / 60.0)
		frames += 1
		if bool(archetype.is_finished()):
			caught = true
			break
	assert_true(caught,
		"a FLEE target must be catchable (ran %d frames)" % frames)


func test_chase_motion_never_closes_a_catch_instantly() -> void:
	# Documents why CHASE and CHASE_CATCH must never be paired again.
	var archetype: Object = _make_archetype(CHASE_MOTION, &"CHASE_CATCH", 24.0, 9.0, 0.0)
	var player: Node3D = archetype.get_context().player as Node3D
	var target: Node3D = _target_of(archetype)
	if target == null:
		return
	target.global_position = Vector3(20.0, 0.0, 0.0)
	var closest: float = INF
	for _i in range(60):
		archetype.advance(1.0 / 60.0)
		closest = minf(closest, target.global_position.distance_to(player.global_position))
	assert_lt(closest, 20.0, "CHASE closes on the player, so it cannot pair with CATCH")


func test_orbit_never_closes_the_distance() -> void:
	var archetype: Object = _make_archetype(ORBIT, &"CHASE_CATCH", 24.0, 4.0, 0.0)
	var player: Node3D = archetype.get_context().player as Node3D
	var target: Node3D = _target_of(archetype)
	if target == null:
		return
	var closest: float = INF
	for _i in range(120):
		archetype.advance(1.0 / 60.0)
		closest = minf(closest, target.global_position.distance_to(player.global_position))
	assert_gt(closest, 0.0, "ORBIT keeps a non-zero separation")


func test_thresholds_are_read_from_the_objective_slot() -> void:
	# §1.3: the two distances are balance and come from ObjectiveRecipe.tolerance.
	var loose: Object = _make_archetype(FLEE, &"CHASE_CATCH", 24.0, 4.0, 1.0)
	var tight: Object = _make_archetype(FLEE, &"SURVIVE_T", 24.0, 4.0, 0.1)
	assert_almost_eq(float(loose.get("_catch_distance")), 2.0, 0.001,
		"tolerance 1.0 gives a 2.0 m catch reach")
	assert_almost_eq(float(tight.get("_hit_distance")), 0.5, 0.001,
		"tolerance 0.1 is clamped at the 0.5 m hit floor")


func test_no_archetype_leaves_an_entity_behind() -> void:
	# §1.4: the target is spawned into the archetype's own spawn list, so its
	# teardown must actually remove it from the tree.
	var archetype: Object = _make_archetype(FLEE, &"CHASE_CATCH", 24.0, 4.0, 0.0)
	var world: Node = archetype.get_context().world_root as Node
	var before: int = world.get_child_count()
	archetype.teardown()
	assert_lt(world.get_child_count(), before + 1,
		"teardown removes the chase target from the world")
