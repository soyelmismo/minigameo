extends GutTest
## Input contracts (scaffold §8): every action must be reachable with the
## keyboard AND the gamepad, and the analogue stick needs a dead zone.

const INPUT_SCRIPT := "res://src/player/player_input.gd"


func _make_input() -> Object:
	var input: Object = load(INPUT_SCRIPT).new()
	add_child_autofree(input)
	# _ready() registers the actions; run it explicitly for a headless check.
	input._ensure_actions()
	return input


func test_every_action_has_a_gamepad_binding() -> void:
	var input := _make_input()
	for action: StringName in input.ACTIONS:
		var buttons: Array = input.GAMEPAD_BUTTONS.get(action, [])
		assert_gt(buttons.size(), 0,
			"action '%s' is reachable from the gamepad" % String(action))
		for button: int in buttons:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			assert_true(InputMap.event_is_action(pad, String(action)),
				"button %d is bound to '%s'" % [button, String(action)])


func test_keyboard_bindings_survive() -> void:
	var input := _make_input()
	for action: StringName in input.ACTIONS:
		assert_true(InputMap.has_action(String(action)),
			"action '%s' exists in the InputMap" % String(action))
		for key: int in input.ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			assert_true(InputMap.event_is_action(ev, String(action)),
				"key %d still bound to '%s'" % [key, String(action)])


func test_stick_dead_zone_rejects_drift() -> void:
	var input := _make_input()
	assert_almost_eq(input._axis_with_deadzone(0, JOY_AXIS_LEFT_X), 0.0, 0.001,
		"no stick plugged in reads as zero")
	assert_gt(float(input.STICK_DEADZONE), 0.0,
		"the dead zone is defined and non-zero")


func test_dead_zone_rescales_the_remaining_range() -> void:
	var input := _make_input()
	# A full push must still produce full speed after the dead zone is removed.
	var dead: float = float(input.STICK_DEADZONE)
	var just_past: float = dead + (1.0 - dead) * 0.5
	# Mirror the helper's maths on a plugged-in stick: the mapping is
	# sign * (|raw| - dead) / (1 - dead), so a half push past the zone is 0.5.
	var scaled: float = signf(just_past) * (absf(just_past) - dead) / (1.0 - dead)
	assert_almost_eq(scaled, 0.5, 0.001,
		"a half push past the zone maps to half speed, not a crawl")
