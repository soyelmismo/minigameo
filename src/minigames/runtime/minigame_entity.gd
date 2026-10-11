class_name MinigameEntity
extends Area3D
## Generic micro-game entity (scaffold §8.0 — data, not code).
##
## ONE scene serves every micro-game that spawns entities. What makes
## "token_rush" look different from "gpu_meltdown" is not a different scene and
## not a different script: it is the slot data the archetype pushes in through
## the exported fields below (tint, shape, size, lifetime). A mechanistically
## covered micro-game stays one `.tres` and zero code (AGENTS.md §1.8).
##
## The archetypes already treat a spawned entity as a node with a `collected`
## signal; this is that node, with the visual read built in.

## Shape of the entity. The archetype picks the archetype-level read (sphere,
## box, diamond...); the tint comes from the `.tres`, so the same three shapes
## plus a colour cover the whole 36-entry catalog.
enum Shape { SPHERE, BOX, DIAMOND, RING }

@export var tint: Color = Color(0.35, 0.85, 1.0):
	set(value):
		tint = value
		_apply_tint()
@export var shape: int = Shape.SPHERE:
	set(value):
		shape = value
		_apply_shape()
@export var size: float = 0.6
@export var lifetime_s: float = -1.0          # -1 = never expires
## Emits when something picks the entity up. Archetypes connect to this.
signal collected(by: Node)

var _taken: bool = false
var _life_left: float = -1.0
var _mesh: MeshInstance3D = null
var _collision: CollisionShape3D = null


func _ready() -> void:
	add_to_group(&"mg_entity")
	_build_visual()
	_build_collision()
	_life_left = lifetime_s


## Radians per second on each axis. Kept as a field (not a const) so a `.tres`
## or an archetype can slow a heavy entity down.
@export var rotation_speed: Vector3 = Vector3(0.0, 1.6, 0.0)



func _process(delta: float) -> void:
	rotate_x(rotation_speed.x * delta)
	rotate_y(rotation_speed.y * delta)
	rotate_z(rotation_speed.z * delta)
	if _life_left > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			_expire()


## The pickup contract. Safe to call more than once; only the first call wins.
func take(by: Node) -> void:
	if _taken:
		return
	_taken = true
	collected.emit(by)
	_despawn()


## True once this entity has been taken or expired. A taken entity must not be
## collected twice (the combo would double-count).
func is_taken() -> bool:
	return _taken


## Lifetime from the slot data. A `lifetime_s <= 0` means "stays until taken".
func set_lifetime(seconds: float) -> void:
	lifetime_s = seconds
	_life_left = seconds


## --- Visuals ----------

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	_apply_shape()
	_apply_tint()
	add_child(_mesh)


func _apply_shape() -> void:
	if _mesh == null:
		return
	match shape:
		Shape.BOX:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * size
			_mesh.mesh = box
		Shape.DIAMOND:
			var octa := PrismMesh.new()
			octa.left_to_right = size
			octa.size = Vector3(size, size, size)
			_mesh.mesh = octa
		Shape.RING:
			var torus := TorusMesh.new()
			torus.inner_radius = size * 0.5
			torus.outer_radius = size
			_mesh.mesh = torus
		_:  # SPHERE
			var sphere := SphereMesh.new()
			sphere.radius = size * 0.5
			sphere.height = size
			_mesh.mesh = sphere


func _apply_tint() -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	# Emission makes a pickup legible at distance and against a dark facade;
	# it is the same read the HUD objective icon uses.
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat


func _build_collision() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "PickupShape"
	var sphere := SphereShape3D.new()
	sphere.radius = size
	_collision.shape = sphere
	add_child(_collision)


## --- Lifetime / teardown ----------

func _expire() -> void:
	if _taken:
		return
	_taken = true
	_despawn()


## Cleanliness (§1.4): the entity removes itself from the group and the world
## instead of being left behind for the director to sweep.
func _despawn() -> void:
	if not is_inside_tree():
		return
	remove_from_group(&"mg_entity")
	queue_free()
