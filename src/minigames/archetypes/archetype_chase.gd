class_name ArchetypeChase
extends MinigameArchetype
## Arquetipo 2 — CHASE (scaffold.md §8.1 fila 2, §8.3 fila 2).
##
## Slots leídos:
##   SpawnRecipe    → motion CHASE (o FLEE), speed, target móvil
##   ObjectiveRecipe→ kind CHASE_CATCH (alcanzar) o SURVIVE_T (esquivar móvil)
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Mecánica: el objetivo móvil se desplaza con `SpawnRecipe.speed`. El jugador
## gana al alcanzarlo (distancia <= tolerancia) dentro del tiempo; el móvil
## persigue al jugador cuando motion = CHASE (entonces el éxito es sobrevivir).

const KIND_CHASE_CATCH := &"CHASE_CATCH"
const KIND_SURVIVE_T := &"SURVIVE_T"
const CATCH_DISTANCE := 2.0

var _time_bonus_per_s: int = 100
var _mover: Node3D = null
var _kind: StringName = KIND_CHASE_CATCH
var _orbit_angle: float = 0.0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_orbit_angle = 0.0
	if _meta != null and _meta.objective_recipe != null:
		_kind = _meta.objective_recipe.kind
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


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
	# Un único móvil (count del recipe se respeta pero el gancho es uno).
	var node: Node = spawn_entity(center + Vector3(recipe.spawn_radius, 0.0, 0.0))
	if node is Node3D:
		_mover = node as Node3D
		_mover.add_to_group(&"mg_chaser")


## El móvil gira alrededor de la arena (ORBIT) o persigue al jugador (CHASE).
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
	if motion == MOTION_CHASE:
		var dir: Vector3 = player_pos - _mover.global_position
		if dir.length() > 0.001:
			_mover.global_position += dir.normalized() * speed * delta
	else:
		_orbit_angle += speed * delta * 0.3
		var radius: float = 10.0
		if _meta != null and _meta.spawn_recipe != null:
			radius = _meta.spawn_recipe.spawn_radius * 0.5
		_mover.global_position = _resolve_center() + Vector3(
			cos(_orbit_angle) * radius, 0.0, sin(_orbit_angle) * radius
		)
	_evaluate(player_pos)


func _evaluate(player_pos: Vector3) -> void:
	if is_finished() or _mover == null:
		return
	var dist: float = _mover.global_position.distance_to(player_pos)
	if _kind == KIND_CHASE_CATCH:
		if dist <= CATCH_DISTANCE:
			finish_success(_time_bonus_per_s)
	else:  # SURVIVE_T frente a un perseguidor
		if dist <= 1.0:
			finish_fail(&"HIT")


## Sobrevivir hasta el final es ganar en modo SURVIVE_T.
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
