class_name PlayerInput
extends Node
## PlayerInput — keyboard + gamepad -> movement intent (scaffold §13.4).
##
## Registers its InputMap actions IN CODE (project.godot is orchestrator-
## owned) and translates them into a move vector + jump for the Player.
## WASD/arrows/left-stick move, Space/A jump, Shift sprint.

## Keyboard bindings, plus the gamepad buttons that map to the same actions
## (§8: playable with keyboard, mouse AND gamepad). The left stick is read as
## raw axes in _read_move(), because a stick is a value, not a press.
const ACTIONS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
}

const GAMEPAD_BUTTONS := {
	&"move_forward": [JOY_BUTTON_DPAD_UP],
	&"move_back": [JOY_BUTTON_DPAD_DOWN],
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"jump": [JOY_BUTTON_A],
	&"sprint": [JOY_BUTTON_LEFT_SHOULDER],
}

## Dead zone for the analogue stick: below it a worn stick drifts the player.
const STICK_DEADZONE := 0.2

var player: Player = null
var _move: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_actions()
	_find_player()


func _ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(String(action)):
			InputMap.add_action(String(action))
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(String(action), ev)
		for button: int in GAMEPAD_BUTTONS.get(action, []):
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			InputMap.action_add_event(String(action), pad)


func _find_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var services: Object = tree.root.get_node_or_null("/root/GameServices") as Object
	if services == null or not services.has_method("lookup"):
		return
	var p: Object = services.lookup(&"player")
	if p is Player:
		player = p as Player


func _process(_delta: float) -> void:
	if player == null:
		_find_player()
		return
	_move = _read_move()
	var sprinting: bool = Input.is_action_pressed("sprint")
	var dir := Vector3(_move.x, 0.0, _move.y)
	player.set_move(dir, sprinting)
	if Input.is_action_just_pressed("jump"):
		player.do_jump()


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	v.y -= 1.0 if Input.is_action_pressed("move_forward") else 0.0
	v.y += 1.0 if Input.is_action_pressed("move_back") else 0.0
	v.x -= 1.0 if Input.is_action_pressed("move_left") else 0.0
	v.x += 1.0 if Input.is_action_pressed("move_right") else 0.0
	# Gamepad left stick: read as a raw axis (analogue value, not a press),
	# with a dead zone so a drifting stick does not walk the player away.
	for device: int in Input.get_connected_joypads():
		v.x += _axis_with_deadzone(device, JOY_AXIS_LEFT_X)
		v.y += _axis_with_deadzone(device, JOY_AXIS_LEFT_Y)
	return v.limit_length(1.0)


## Applies the dead zone and rescales the remaining range back to 0..1, so a
## stick pushed just past the zone does not crawl.
func _axis_with_deadzone(device: int, axis: JoyAxis) -> float:
	var raw: float = Input.get_joy_axis(device, axis)
	if absf(raw) <= STICK_DEADZONE:
		return 0.0
	return signf(raw) * (absf(raw) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
