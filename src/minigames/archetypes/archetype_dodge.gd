class_name ArchetypeDodge
extends MinigameArchetype
## Arquetipo 3 — DODGE (scaffold.md §8.1 fila 3, §8.3 fila 3).
##
## Slots leídos:
##   SpawnRecipe    → WAVE/FALL, motion FALL, count, lifetime_s
##   ObjectiveRecipe→ kind SURVIVE_T, fail_on TOUCH_HAZARD
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Gancho: sobrevivir al bombardeo de peligros que caen. Éxito = aguantar
## `duration_s`; fracaso inmediato al tocar un peligro (TOUCH_HAZARD).

const KIND_SURVIVE_T := &"SURVIVE_T"
const HAZARD_HIT_RADIUS := 1.2  # radio de contacto peligro-jugador

var _time_bonus_per_s: int = 100
var _wave_index: int = 0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_wave_index = 0
	if _meta != null and _meta.objective_recipe != null:
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_hazards()


## Spawnea los peligros según el patrón. WAVE los reparte en el aire sobre la
## arena; FALL los deja caer (la escena/prop se encarga del movimiento).
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


## Por defecto agotar el tiempo en DODGE es GANAR (se sobrevive).
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
		if hazard.global_position.distance_to(player_pos) <= HAZARD_HIT_RADIUS:
			# Fallo inmediato: el director limpiará las entidades en teardown.
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
