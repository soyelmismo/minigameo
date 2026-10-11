class_name PlayerInput
extends Node
## PlayerInput — keyboard + gamepad -> movement intent (scaffold §13.4).
##
## Registers its InputMap actions IN CODE (project.godot is orchestrator-
## owned) and translates them into a move vector + jump for the Player.
## WASD/arrows/left-stick move, Space/A jump, Shift sprint.

const ACTIONS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
}

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
	# Gamepad left stick (axes 0/1).
	v.x += Input.get_axis(&"ui_left", &"ui_right")
	v.y += Input.get_axis(&"ui_up", &"ui_down")
	return v.limit_length(1.0)
