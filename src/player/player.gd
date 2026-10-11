class_name Player
extends Node3D
## Player — the arcade avatar (scaffold §6).
##
## Owns the motor + input + avatar mesh, publishes state to EventBus and
## registers in GameServices as &"player" (duck-typed, degrades silently).
## The camera and power-up systems find the player through those channels.

@export var motor_path: NodePath = NodePath("PlayerMotor")

var motor: PlayerMotor = null
var _state: StringName = &"idle"


func _ready() -> void:
	motor = get_node_or_null(motor_path) as PlayerMotor
	if motor == null:
		# Standalone fallback for tests.
		motor = PlayerMotor.new()
		add_child(motor)
	_register()


func _register() -> void:
	# Resolución por path (§1.1): el identificador global del autoload no
	# está disponible en todos los contextos de compilación.
	var locator: Object = _resolve(&"GameServices")
	if locator != null and locator.has_method("lookup"):
		var core: Object = locator.lookup(&"core")
		if core != null and core.has_method("register"):
			core.register(&"player", self)


func _resolve(node_name: StringName) -> Object:
	var tree := get_tree()
	if tree == null:
		return null
	var node: Node = tree.root.get_node_or_null(String(node_name))
	return node as Object


func _physics_process(_delta: float) -> void:
	var new_state: StringName = _state_name()
	if new_state != _state:
		_state = new_state
		var bus: Object = _resolve(&"EventBus")
		if bus != null and bus.has_method("emit"):
			bus.emit(&"player_state_changed", new_state)


func _state_name() -> StringName:
	if motor == null:
		return &"idle"
	match motor.move_state:
		PlayerMotor.State.AIR: return &"air"
		PlayerMotor.State.RUN: return &"run"
		PlayerMotor.State.HURT: return &"hurt"
		_: return &"idle"


## Apply a movement intent (called by PlayerInput or tests).
func set_move(dir: Vector3, sprinting: bool) -> void:
	if motor != null:
		motor.move(dir, sprinting)


func do_jump() -> void:
	if motor != null:
		motor.jump()
