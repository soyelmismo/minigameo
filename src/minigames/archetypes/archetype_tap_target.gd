class_name ArchetypeTapTarget
extends MinigameArchetype
## Arquetipo 4 — TAP_TARGET (scaffold.md §8.1 fila 4, §8.3 fila 4).
##
## Slots leídos:
##   SpawnRecipe    → SCATTER, lifetime corto
##   ObjectiveRecipe→ kind TAP_N, target = N aciertos, fail_on TIMEOUT
##   HUDRecipe      → COUNTER
##   InputMode      → LOOK | TAP
##
## Gancho: acertar N objetivos. La entrada se resuelve por `on_input` con
## raycast desde la cámara; si el raycast falla, se usa el objetivo más cercano
## al punto pulsado (fallback documentado).

const KIND_TAP_N := &"TAP_N"

var _hits: int = 0
var _target: int = 8
var _time_bonus_per_s: int = 100


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_hits = 0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_targets()


func _spawn_targets() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		push_warning("ArchetypeTapTarget: metadata has no spawn_recipe")
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
			node.add_to_group(&"mg_target")


## Resuelve un toque: primero por raycast desde la cámara; si no acierta a
## ningún objetivo, cae al objetivo más cercano al rayo (fallback LOOK/TAP).
func on_input(input_event: InputEvent) -> void:
	if is_finished():
		return
	if input_event is InputEventMouseButton and (input_event as InputEventMouseButton).pressed:
		_try_hit_at((input_event as InputEventMouseButton).position)
	elif input_event is InputEventKey and (input_event as InputEventKey).pressed:
		# Accesibilidad: teclado/mando pulsan el objetivo más cercano al jugador.
		_try_hit_nearest_to_player()


func _try_hit_at(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_try_hit_nearest_to_player()
		return
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var space := camera.get_world_3d().direct_space_state if camera.get_world_3d() != null else null
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	var result := {}
	if space != null:
		result = space.intersect_ray(query)
	if not result.is_empty():
		var collider: Object = result.get("collider")
		var node: Node = collider as Node
		if node != null and node.is_in_group(&"mg_target"):
			_register_hit(node)
			return
	# Fallback: objetivo más cercano al rayo.
	_register_hit(_nearest_to_ray(from, dir))


func _nearest_to_ray(from: Vector3, dir: Vector3) -> Node:
	var best: Node = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"mg_target"):
		if not is_instance_valid(node) or node is not Node3D:
			continue
		var pos: Vector3 = (node as Node3D).global_position
		var t: float = (pos - from).dot(dir)
		if t <= 0.0:
			continue
		var d: float = (from + dir * t).distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _try_hit_nearest_to_player() -> void:
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	var best: Node = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"mg_target"):
		if not is_instance_valid(node) or node is not Node3D:
			continue
		var d: float = (node as Node3D).global_position.distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = node
	if best != null:
		_register_hit(best)


func _register_hit(node: Node) -> void:
	if is_finished() or node == null or not is_instance_valid(node):
		return
	_hits += 1
	var combo: int = bump_combo()
	set_progress(float(_hits) / float(maxi(1, _target)))
	emit_event(&"hit_target", {"hits": _hits, "target": _target, "combo": combo})
	node.queue_free()
	if _hits >= _target:
		finish_success(_time_bonus_per_s)


func _resolve_center() -> Vector3:
	var ctx := get_context()
	if ctx != null and ctx.player != null and is_instance_valid(ctx.player):
		return (ctx.player as Node3D).global_position
	if ctx != null:
		return ctx.arena_center
	return Vector3.ZERO


func teardown() -> void:
	super.teardown()
	_hits = 0


func get_hits() -> int:
	return _hits


func get_target() -> int:
	return _target
