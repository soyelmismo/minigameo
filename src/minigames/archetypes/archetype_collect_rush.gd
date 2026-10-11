class_name ArchetypeCollectRush
extends MinigameArchetype
## Arquetipo 1 — COLLECT_RUSH (scaffold.md §8.1 fila 1, §8.3 fila 1).
##
## Slots leídos:
##   SpawnRecipe    → SCATTER/STATIC/FLEE, count, spawn_radius
##   ObjectiveRecipe→ kind COLLECT_N, target = N objetos, fail_on TIMEOUT
##   HUDRecipe      → COUNTER
##   InputMode      → RUN
##
## Gancho: recoger N objetos antes de que se acabe el tiempo. Éxito con bonus
## de tiempo sobrante; fracaso por TIMEOUT. 100% data-driven: el micro-juego
## concreto es su `.tres`, este motor es genérico y reutilizable.

const KIND_COLLECT_N := &"COLLECT_N"
const PICKUP_RADIUS := 1.8   # radio de recogida (distancia al jugador)

var _collected: int = 0
var _target: int = 12
var _time_bonus_per_s: int = 100


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_collected = 0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_collectibles()


## Spawnea los coleccionables alrededor del jugador (o del centro de arena).
func _spawn_collectibles() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		push_warning("ArchetypeCollectRush: metadata has no spawn_recipe")
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
			node.add_to_group(&"mg_collectible")
			if node.has_signal("collected"):
				node.connect("collected", _on_collectible_taken)


## Centro de spawn: el jugador si está en el contexto, si no el centro de arena.
func _resolve_center() -> Vector3:
	var ctx := get_context()
	if ctx != null and ctx.player != null and is_instance_valid(ctx.player):
		return (ctx.player as Node3D).global_position
	if ctx != null:
		return ctx.arena_center
	return Vector3.ZERO


func _on_collectible_taken() -> void:
	if is_finished():
		return
	_collected += 1
	var combo: int = bump_combo()
	set_progress(float(_collected) / float(maxi(1, _target)))
	emit_event(&"collect", {"count": _collected, "target": _target, "combo": combo})
	if _collected >= _target:
		finish_success(_time_bonus_per_s)


## Frame lógico: además del reloj base, resuelve recogidas por proximidad
## (fallback cuando la entidad no emite `collected`).
func advance(delta: float) -> void:
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	for node: Node in get_tree().get_nodes_in_group(&"mg_collectible"):
		if not is_instance_valid(node):
			continue
		var pos: Vector3 = _node_position(node)
		if pos.distance_to(player_pos) <= PICKUP_RADIUS:
			if node.has_signal("collected"):
				node.emit_signal("collected")
				node.queue_free()
			else:
				_on_collectible_taken()
				node.queue_free()
			return  # una recogida por frame


func _node_position(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	return Vector3.ZERO


func teardown() -> void:
	super.teardown()
	_collected = 0


## Progreso actual (para tests y HUD).
func get_collected() -> int:
	return _collected


func get_target() -> int:
	return _target
