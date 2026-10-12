class_name ArchetypeDodge
extends MinigameArchetype
## Archetype 3 — DODGE (scaffold.md §8.1 row 3, §8.3 row 3).
##
## Slots read:
##   SpawnRecipe    → WAVE/FALL, motion FALL, count, lifetime_s
##   ObjectiveRecipe→ kind SURVIVE_T, fail_on TOUCH_HAZARD
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Hook: survive the bombardment of hazards raining down. Success = lasting
## `duration_s`; immediate failure on touching a hazard (TOUCH_HAZARD).

const KIND_SURVIVE_T := &"SURVIVE_T"
## Archetype default for `reach_m`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.reach_m overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_HAZARD_HIT_RADIUS := 1.2  # hazard-player contact radius

var _hazard_radius: float = DEFAULT_HAZARD_HIT_RADIUS
var _time_bonus_per_s: int = 100
var _wave_index: int = 0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_hazard_radius = _slot_value(&"reach_m", DEFAULT_HAZARD_HIT_RADIUS)
	_wave_index = 0
	if _meta != null and _meta.objective_recipe != null:
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_hazards()


## Spawns the hazards according to the pattern. WAVE spreads them in the air
## over the arena; FALL drops them (the scene/prop handles the movement).
func _spawn_hazards() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		push_warning("ArchetypeDodge: metadata has no spawn_recipe")
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var difficulty: float = ctx.difficulty if ctx != null else 0.0
	var total: int = recipe.resolve_count(difficulty)
	var center := _resolve_center()
	var radius: float = recipe.spawn_radius
	for i: int in total:
		var at: Vector3 = spawn_point(i, total, center, radius)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_hazard")


## By default, running out of time in DODGE is WINNING (you survived).
func on_timeout() -> void:
	finish_success(_time_bonus_per_s)


func advance(_delta: float) -> void:
	if is_finished():
		return
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	for node: Node in get_tree().get_nodes_in_group(&"mg_hazard"):
		if not is_instance_valid(node):
			continue
		if node is not Node3D:
			continue
		var hazard: Node3D = node as Node3D
		if hazard.global_position.distance_to(player_pos) <= _hazard_radius:
			# Immediate failure: the director will clean up the entities in teardown.
			finish_fail(&"TOUCH_HAZARD")
			return


func _resolve_center() -> Vector3:
	var ctx := get_context()
	if ctx != null and ctx.player != null and is_instance_valid(ctx.player):
		return (ctx.player as Node3D).global_position
	if ctx != null:
		return ctx.arena_center
	return Vector3.ZERO


func teardown() -> void:
	super.teardown()
	_wave_index = 0
