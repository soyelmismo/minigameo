class_name ArchetypeChase
extends MinigameArchetype
## Archetype 2 — CHASE (scaffold.md §8.1 row 2, §8.3 row 2).
##
## Slots read:
##   SpawnRecipe    → motion CHASE (or FLEE), speed, moving target
##   ObjectiveRecipe→ kind CHASE_CATCH (catch) or SURVIVE_T (dodge the mover)
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Mechanic: the moving target travels at `SpawnRecipe.speed`. The player
## wins by catching it (distance <= tolerance) within the time; the mover
## chases the player when motion = CHASE (then success is surviving).

const KIND_CHASE_CATCH := &"CHASE_CATCH"
const KIND_SURVIVE_T := &"SURVIVE_T"
## Reach to score a catch, and the distance at which a chaser scores a hit.
## Both are balance (§1.3) and default from the ObjectiveRecipe tolerance when
## the slot provides one, so a `.tres` retunes them.
const DEFAULT_CATCH_DISTANCE := 2.0
const DEFAULT_HIT_DISTANCE := 1.0
## FLEE urgency window (metres from the player): full escape speed inside
## FLEE_NEAR_R, easing to the floor at FLEE_FAR_R.
const FLEE_NEAR_R := 6.0
const FLEE_FAR_R := 26.0
## Hard ceiling on the escape speed as a fraction of the recipe speed.
## Without it, a target whose speed equals the player's is uncatchable once the
## player is inside FLEE_NEAR_R — the micro-game becomes unwinnable in the
## opposite direction to the bug this archetype was just fixed for.
const FLEE_MAX_SPEED_FRACTION := 0.75

var _time_bonus_per_s: int = 100
var _mover: Node3D = null
var _kind: StringName = KIND_CHASE_CATCH
var _orbit_angle: float = 0.0
var _catch_distance: float = DEFAULT_CATCH_DISTANCE
var _hit_distance: float = DEFAULT_HIT_DISTANCE


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_orbit_angle = 0.0
	if _meta != null and _meta.objective_recipe != null:
		_kind = _meta.objective_recipe.kind
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
		# Tolerance is the slot's notion of "how close counts"; the archetype's
		# two thresholds (a catch, a chaser's hit) derive from it so a `.tres`
		# retunes them instead of the engine.
		var tol: float = float(_meta.objective_recipe.tolerance)
		if tol > 0.0:
			_catch_distance = maxf(0.5, tol * 2.0)
			_hit_distance = maxf(0.5, tol)


func start() -> void:
	super.start()
	_spawn_mover()


func _spawn_mover() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		push_warning("ArchetypeChase: metadata has no spawn_recipe")
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var center: Vector3 = _resolve_center()
	# A single mover (the recipe count is respected, but the hook is one).
	var node: Node = spawn_entity(center + Vector3(recipe.spawn_radius, 0.0, 0.0))
	if node is Node3D:
		_mover = node as Node3D
		_mover.add_to_group(&"mg_chaser")


## The target moves every frame:
##   FLEE  — runs away from the player, so a CHASE_CATCH is a genuine chase
##           ("catch the runaway inference") that gets harder the closer you get.
##   CHASE — hunts the player, which belongs with SURVIVE_T ("outrun it").
##   ORBIT — circles the arena, dodging without ever closing the distance.
func advance(delta: float) -> void:
	if _mover == null or not is_instance_valid(_mover):
		return
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var speed: float = 4.0
	if _meta != null and _meta.spawn_recipe != null:
		speed = _meta.spawn_recipe.speed
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	var motion: StringName = MOTION_STATIC
	if _meta != null and _meta.spawn_recipe != null:
		motion = _meta.spawn_recipe.motion
	match String(motion):
		"FLEE":
			_move_fleeing(player_pos, speed * delta)
		"CHASE":
			_move_chasing(player_pos, speed * delta)
		_:
			_move_orbiting(speed * delta)
	_evaluate(player_pos)


## Runs away from the player. It keeps a minimum distance so the chase never
## becomes impossible, and it does not outrun the player outright (the escape
## speed is capped below the recipe speed) — otherwise the micro-game is
## unwinnable in the other direction.
func _move_fleeing(player_pos: Vector3, step: float) -> void:
	var to_target: Vector3 = _mover.global_position - player_pos
	var dist: float = to_target.length()
	if dist < 0.001:
		return
	var away: Vector3 = to_target / dist
	# Full speed once the player is close, easing off at range so the target
	# drifts back into reachable space.
	var urgency: float = clampf(1.0 - (dist - FLEE_NEAR_R) / (FLEE_FAR_R - FLEE_NEAR_R), 0.15, 1.0)
	urgency = minf(urgency, FLEE_MAX_SPEED_FRACTION)
	_mover.global_position += away * step * urgency
	# Stay inside the arena.
	var center: Vector3 = _resolve_center()
	var radius: float = 24.0
	if _meta != null and _meta.spawn_recipe != null:
		radius = _meta.spawn_recipe.spawn_radius
	var offset: Vector3 = _mover.global_position - center
	if offset.length() > radius:
		_mover.global_position = center + offset.normalized() * radius


## Runs toward the player. Only sensible with SURVIVE_T: paired with CHASE_CATCH
## it wins the micro-game in a frame, which is the inversion the winability gate
## catches.
func _move_chasing(player_pos: Vector3, step: float) -> void:
	var dir: Vector3 = player_pos - _mover.global_position
	if dir.length() > 0.001:
		_mover.global_position += dir.normalized() * step


## Circles the arena: a target that keeps moving without ever closing in.
func _move_orbiting(step: float) -> void:
	_orbit_angle += step * 0.3
	var radius: float = 10.0
	if _meta != null and _meta.spawn_recipe != null:
		radius = _meta.spawn_recipe.spawn_radius * 0.5
	_mover.global_position = _resolve_center() + Vector3(
		cos(_orbit_angle) * radius, 0.0, sin(_orbit_angle) * radius
	)


func _evaluate(player_pos: Vector3) -> void:
	if is_finished() or _mover == null or not is_instance_valid(_mover):
		return
	var dist: float = _mover.global_position.distance_to(player_pos)
	if _kind == KIND_CHASE_CATCH:
		if dist <= _catch_distance:
			finish_success(_time_bonus_per_s)
	else:  # SURVIVE_T: the chaser reaching you is a failure.
		if dist <= _hit_distance:
			finish_fail(&"HIT")


## Surviving until the end is winning in SURVIVE_T mode.
func on_timeout() -> void:
	if _kind == KIND_SURVIVE_T:
		finish_success(_time_bonus_per_s)
	else:
		finish_fail(&"TIMEOUT")


func _resolve_center() -> Vector3:
	var ctx := get_context()
	if ctx != null and ctx.player != null and is_instance_valid(ctx.player):
		return (ctx.player as Node3D).global_position
	if ctx != null:
		return ctx.arena_center
	return Vector3.ZERO


func teardown() -> void:
	super.teardown()
	_mover = null
	_orbit_angle = 0.0
