class_name PowerUp
extends Area3D
## Pickup power-up on the block (scaffold.md §6.11).
##
## Intentional stylised placeholder: emissive mesh + glow orbit.
## Procedural bob/idle and spin belong here; the balance (cooldown, number
## concurrent) lives in the spawner as data.

const DEFAULT_PICKUP_RADIUS := 1.6

## Emitted when it is picked up (by area overlap or by proximity).
signal collected(body: Node)

@export var bob_amplitude: float = 0.25
@export var bob_speed: float = 2.0
@export var spin_speed: float = 1.5
@export var pickup_radius: float = DEFAULT_PICKUP_RADIUS

var _base_y: float = 0.0
var _t: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	# Group so the spawner and the director find it without coupling.
	add_to_group(&"powerup")


func _physics_process(delta: float) -> void:
	if _taken:
		return
	_idle(delta)


## Idle animation: bob + spin. Purely cosmetic, no balance.
func _idle(delta: float) -> void:
	_t += delta * bob_speed
	position.y = _base_y + sin(_t) * bob_amplitude
	rotate_y(delta * spin_speed)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	# Duck-typed: any body with `is_player` or the player's name.
	if _is_player(body):
		take(body)


## Distance fallback when there are no physics (headless tests, player far away).
func check_proximity(player: Node3D) -> bool:
	if _taken or player == null or not is_instance_valid(player):
		return false
	if global_position.distance_to(player.global_position) <= pickup_radius:
		take(player)
		return true
	return false


## Marks the power-up as picked up and removes it from the scene.
func take(by: Node) -> void:
	if _taken:
		return
	_taken = true
	collected.emit(by)
	set_deferred(&"monitoring", false)
	queue_free()


## The player is recognized by duck-typing, never by a concrete class.
func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.has_method("is_player") and bool(body.is_player()):
		return true
	if body.is_in_group(&"player"):
		return true
	if body.name == &"Player":
		return true
	return false
