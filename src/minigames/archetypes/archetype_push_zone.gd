class_name ArchetypePushZone
extends MinigameArchetype
## Archetype 11 — PUSH_ZONE (scaffold.md §8.1 row 11, §8.3 row 11).
##
## Slots read:
##   SpawnRecipe    → physics, motion STATIC, count = objects to push
##   ObjectiveRecipe→ kind PUSH_N_TO_ZONE, target = N objects in the zone
##   HUDRecipe      → COUNTER
##   InputMode      → RUN | STICK
##
## Mechanic: the objects count as "pushed" when the player moves them
## closer; an object counts when it enters the delivery zone radius.
## The real physics come from the prop (`RigidBody3D`) in the scene; this
## engine only evaluates the victory condition in a data-driven way.

const KIND_PUSH_N_TO_ZONE := &"PUSH_N_TO_ZONE"
## Archetype default for `reach_m`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.reach_m overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_ZONE_RADIUS := 5.0

var _pushed: int = 0
var _zone_radius: float = DEFAULT_ZONE_RADIUS
var _target: int = 5
var _time_bonus_per_s: int = 100
var _delivered: Array[Node] = []


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_zone_radius = _slot_value(&"reach_m", DEFAULT_ZONE_RADIUS)
	_pushed = 0
	_delivered.clear()
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_pushables()
	_spawn_delivery_zone()


func _spawn_pushables() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var radius: float = recipe.spawn_radius
	for i: int in _target:
		var at: Vector3 = spawn_point(i, _target, center, radius)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_pushable")


## The delivery zone is a marker on the opposite side of the arena.
func _spawn_delivery_zone() -> void:
	var ctx := get_context()
	if ctx == null:
		return
	var radius: float = 10.0
	if _meta != null and _meta.spawn_recipe != null:
		radius = _meta.spawn_recipe.spawn_radius
	var marker := Node3D.new()
	marker.name = "DeliveryZone"
	marker.position = ctx.arena_center + Vector3(radius, 0.0, 0.0)
	marker.add_to_group(&"mg_delivery_zone")
	if ctx.world_root != null:
		ctx.world_root.add_child(marker)
		_spawned.append(marker)


func _zone_position() -> Vector3:
	for node: Node in get_tree().get_nodes_in_group(&"mg_delivery_zone"):
		if is_instance_valid(node) and node is Node3D:
			return (node as Node3D).global_position
	return Vector3.ZERO


func advance(_delta: float) -> void:
	if is_finished():
		return
	var zone: Vector3 = _zone_position()
	for node: Node in get_tree().get_nodes_in_group(&"mg_pushable"):
		if not is_instance_valid(node) or node is not Node3D:
			continue
		if node in _delivered:
			continue
		if (node as Node3D).global_position.distance_to(zone) <= _zone_radius:
			_delivered.append(node)
			_pushed += 1
			var combo: int = bump_combo()
			set_progress(float(_pushed) / float(maxi(1, _target)))
			emit_event(&"pushed", {"pushed": _pushed, "target": _target, "combo": combo})
			if _pushed >= _target:
				finish_success(_time_bonus_per_s)
				return


func teardown() -> void:
	super.teardown()
	_pushed = 0
	_delivered.clear()


func get_pushed() -> int:
	return _pushed
