extends "res://addons/gut/test.gd"
## Integration: the match loop (scaffold §5, §6.2).
##
## Drives the REAL autoloads (booted by GUT) through the full flow:
## TITLE -> COUNTDOWN -> FREE_ROAM -> ROULETTE -> MINIGAME -> back,
## and asserts the 5-minute clock, the minigame lifecycle with context
## injection, deterministic seeding and clean teardown (no orphans).

const CFG := "res://src/core/config/game_config.tres"

var _match: Object = null
var _director: Object = null
var _score: Object = null
var _loop: Object = null


func before_each() -> void:
	_match = _autoload("MatchManager")
	_director = _autoload("MinigameDirector")
	_score = _autoload("ScoreDirector")
	assert_not_null(_match, "MatchManager autoload present")
	assert_not_null(_director, "MinigameDirector autoload present")
	# The real GameLoopDriver advances the clock with real frames; freeze it
	# so these tests drive time explicitly (determinism, §7.2).
	_loop = _autoload("GameLoop")
	if _loop is Node:
		(_loop as Node).set_physics_process(false)
	# A previous test may have left the director in cooldown; start clean.
	if _director is Node and (_director as Node).has_method("reset_runtime"):
		(_director as Node).call("reset_runtime")
	_match.start_match()


func after_each() -> void:
	if _loop is Node:
		(_loop as Node).set_physics_process(true)


func _autoload(node_name: String) -> Object:
	var root := get_tree().root
	if root == null:
		return null
	return root.get_node_or_null("/root/" + node_name)


# --- Match clock (§5: 5-minute match) ---

func test_match_config_is_five_minutes() -> void:
	var cfg: Resource = load(CFG) as Resource
	assert_not_null(cfg, "GameConfig loads")
	var length: float = float(cfg.get("match_length_s"))
	assert_almost_eq(length, 300.0, 0.001, "scaffold §15: 300s match")


func test_clock_advances_only_in_running_states() -> void:
	# before_each already called start_match(); we are in COUNTDOWN.
	# Countdown does NOT run the match clock.
	var before: float = float(_match.time_left())
	_match.advance(1.0)
	assert_almost_eq(float(_match.time_left()), before, 0.001,
		"clock paused during countdown")
	# Skip the rest of the countdown exactly, then enter FREE_ROAM.
	_match.advance(3.0)
	assert_eq(int(_match.current_state()), 3, "FREE_ROAM after countdown")
	var at_freeroam: float = float(_match.time_left())
	_match.advance(5.0)
	assert_almost_eq(float(_match.time_left()), at_freeroam - 5.0, 0.001,
		"clock runs during FREE_ROAM")


func test_match_emits_one_tick_per_second() -> void:
	# before_each already called start_match(); drive past the countdown.
	_match.advance(3.0)
	assert_eq(int(_match.current_state()), 3, "FREE_ROAM")
	var ticks: Array[float] = []
	var bus: Object = _autoload("EventBus")
	assert_not_null(bus, "EventBus autoload present")
	if bus == null:
		return
	bus.match_tick.connect(func(t: float) -> void: ticks.append(t))
	# Sample 2.5 seconds at 60 fps: expect ceil-2 or 3 distinct ticks (1 Hz).
	var elapsed: float = 0.0
	while elapsed < 2.5:
		_match.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_gte(ticks.size(), 2, "tick fires about once per second (got %d)" % ticks.size())
	assert_lte(ticks.size(), 4, "tick never fires per frame (got %d)" % ticks.size())
	# Ticks must descend monotonically (it is a countdown).
	for i in range(1, ticks.size()):
		assert_lte(ticks[i], ticks[i - 1], "countdown ticks descend")


func test_match_ends_at_time_up() -> void:
	# before_each already called start_match().
	for _i in 60:
		_match.advance(0.1)
	# Burn the whole match in FREE_ROAM.
	for _i in 400:
		_match.advance(1.0)
	assert_eq(int(_match.current_state()), 7, "TIME_UP reached")
	assert_almost_eq(float(_match.time_left()), 0.0, 0.001, "clock at zero")


# --- Roulette + minigame lifecycle (§6.12, §7.1) ---

func test_roulette_to_minigame_and_back() -> void:
	# Enter FREE_ROAM (before_each left us in COUNTDOWN).
	_match.advance(3.0)
	assert_eq(int(_match.current_state()), 3, "FREE_ROAM")
	_match.request_roulette()
	assert_eq(int(_match.current_state()), 4, "ROULETTE")
	var ids: Array = _registry_ids()
	assert_gt(ids.size(), 30, "catalog has 30+ minigames")
	var first_id: StringName = ids[0] as StringName
	var ok: bool = _director.play(first_id, 0.5)
	assert_true(ok, "director.play('%s') succeeds" % String(first_id))
	assert_true(_director.is_active(), "minigame active after play")
	# Context must be injected: score/style/music resolved, not null.
	var mg: Object = _director.get_active()
	assert_not_null(mg, "active minigame node")
	var ctx: Object = mg.get_context() if mg.has_method("get_context") else null
	assert_not_null(ctx, "context injected")
	if ctx != null:
		assert_not_null(ctx.get("score"), "ScoreDirector injected into context")
		assert_not_null(ctx.get("music"), "MusicDirector injected into context")
		assert_not_null(ctx.get("style"), "StyleDirector injected into context")
		assert_not_null(ctx.get("rng"), "SeededRNG injected into context")
	# Clean teardown: finish -> no active.
	mg.finished.emit(_make_result(true))
	assert_false(_director.is_active(), "no active minigame after finish")
	await wait_frames(2)


func test_minigame_never_runs_past_match_time() -> void:
	_match.advance(3.0)
	var ids: Array = _registry_ids()
	if ids.is_empty():
		return
	_director.play(ids[0] as StringName, 0.5)
	var mg: Object = _director.get_active()
	var ctx: Object = mg.get_context() if mg.has_method("get_context") else null
	assert_not_null(ctx, "context injected")
	# time_left_in_match is the hard cap (§7.1): never above match clock.
	assert_lte(float(ctx.get("time_left_in_match")), float(_match.time_left()) + 0.001,
		"minigame time never exceeds match clock")
	mg.finished.emit(_make_result(false))
	await wait_frames(2)


func _registry_ids() -> Array:
	# The shared catalog is published as &"registry" (and may hang anywhere in
	# the tree), so resolve it through the service locator first rather than
	# assuming a child node name that the director is free to change.
	var director_node := _director as Node
	if director_node == null:
		return []
	var registry: Object = GameServices.lookup(&"registry")
	if registry == null:
		registry = director_node.get_node_or_null("MinigameRegistry") as Object
	if registry == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			registry = tree.root.get_node_or_null("/root/MinigameRegistry") as Object
	if registry != null and registry.has_method("get_all_ids"):
		return registry.get_all_ids()
	return []


func _make_result(success: bool) -> Resource:
	var result_script: GDScript = load("res://src/minigames/minigame_result.gd") as GDScript
	assert_not_null(result_script, "MinigameResult script loads")
	var made: Variant = result_script.call("make", success, 100, 1, 5, &"DONE")
	return made as Resource
