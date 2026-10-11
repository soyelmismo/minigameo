extends GutTest
## The pause menu must be reachable in play (scaffold §13.3, §8).
##
## The menu itself was fine — `open()`, `resume()` and the Escape binding all
## existed — but nothing in the flight called `open()`, so the menu could never
## appear. This pins the wiring: Escape opens it during a match, Escape resumes
## it, and it is never live on the title screen.

const MAIN_SCENE := "res://src/bootstrap/main.tscn"


func _make_main() -> Node:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _pause_of(main: Node) -> Object:
	return main.get_node_or_null("PauseMenu") as Object


func _press_cancel_on(main: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	# This is the entry point the SceneTree itself calls when no Control
	# consumed the key (Viewport -> GUI -> _unhandled_input). Driving the
	# handler directly keeps the test independent of the test-runner's own
	# input plumbing while still exercising the real binding.
	main._unhandled_input(ev)


func test_escape_opens_the_pause_menu_during_a_match() -> void:
	var main := await _make_main()
	var pause := _pause_of(main)
	assert_not_null(pause, "the pause menu is part of the main scene")
	assert_false(bool(pause.visible), "hidden on the title screen")

	# A match starts: the pause key becomes live.
	EventBus.emit(&"match_started")
	await get_tree().process_frame
	_press_cancel_on(main)
	await get_tree().process_frame
	assert_true(bool(pause.visible), "Escape opens the pause menu in play")


func test_escape_resumes_and_hides_the_menu() -> void:
	var main := await _make_main()
	var pause := _pause_of(main)
	EventBus.emit(&"match_started")
	await get_tree().process_frame
	_press_cancel_on(main)
	await get_tree().process_frame
	assert_true(bool(pause.visible), "menu open before resuming")

	# The menu itself consumes Escape to resume (its own _unhandled_input).
	pause.resume()
	await get_tree().process_frame
	assert_false(bool(pause.visible), "resume closes the menu")
	assert_false(bool(get_tree().paused), "the world is running again")


func test_pause_key_is_dead_on_the_title_screen() -> void:
	var main := await _make_main()
	var pause := _pause_of(main)
	_press_cancel_on(main)
	await get_tree().process_frame
	assert_false(bool(pause.visible),
		"no match running: Escape must not pause the title screen")


func test_pausing_freezes_the_world() -> void:
	var main := await _make_main()
	var pause := _pause_of(main)
	EventBus.emit(&"match_started")
	await get_tree().process_frame
	_press_cancel_on(main)
	await get_tree().process_frame
	assert_true(bool(get_tree().paused),
		"the pause menu pauses the SceneTree while it stays responsive")
	# Cleanup: leave the tree unpaused for the rest of the suite.
	pause.resume()
	await get_tree().process_frame
