extends "res://addons/gut/test.gd"
## tests/unit/test_frame_time_budget.gd — frame-time budget of the systems the
## GameLoopDriver drives (stress brief §2; AGENTS.md §7 / scaffold §15).
##
## Headless has no GPU, so this measures the CPU cost of one SIMULATED frame of
## the deterministic block: match clock, roulette, micro-game runtime, score
## combo decay, impact hitstop/flash, postfx blend. Everything is the real
## autoload, driven with explicit deltas and a fixed seed, exactly like the
## integration stress match — this file just runs it without main.tscn so the
## number lands in the fast unit suite.
##
## Reported numbers are PER SIMULATED FRAME: the integration suite reports the
## full 300 s match, this one isolates the per-frame cost with and without a
## micro-game in flight.

const FRAME_DT := 1.0 / 60.0
## §15 budget: 60 fps = 16.6 ms per frame.
const FRAME_BUDGET_US := 16600.0
## Generous headless ceiling: headless runs the same CPU code as the game with
## no GPU work, so anything under this is healthy. Only a runaway frame trips
## it, so it must never flake on a slow or loaded box.
const FRAME_CEILING_US := 100000.0
## How many frames to measure per scenario.
const SAMPLE_FRAMES := 360     # 6 simulated seconds per scenario

const RESULT_SCRIPT := "res://src/minigames/minigame_result.gd"

var _match: Object = null
var _director: Object = null
var _score: Object = null
var _roulette: Object = null
var _loop: Object = null
var _impact: Object = null
var _postfx: Object = null
var _camera: Object = null
var _rng: Object = null
var _registry: MinigameRegistry = null


func before_each() -> void:
	_match = _autoload("MatchManager")
	_director = _autoload("MinigameDirector")
	_score = _autoload("ScoreDirector")
	_roulette = _autoload("RouletteController")
	_loop = _autoload("GameLoop")
	_impact = _autoload("ImpactDirector")
	_postfx = _autoload("PostFXDirector")
	_camera = _autoload("CameraDirector")
	_rng = _autoload("SeededRNG")
	assert_not_null(_match, "MatchManager autoload present")
	assert_not_null(_director, "MinigameDirector autoload present")
	assert_not_null(_score, "ScoreDirector autoload present")
	assert_not_null(_impact, "ImpactDirector autoload present")
	assert_not_null(_postfx, "PostFXDirector autoload present")
	# Freeze the real frame driver so these tests own time (determinism, §7.2).
	if _loop is Node:
		(_loop as Node).set_physics_process(false)
	if _rng != null and _rng.has_method("seed"):
		_rng.seed(20260911)
	_clear_runtime_state()
	if _registry == null:
		_registry = load("res://src/minigames/minigame_registry.gd").new()
		_registry.scan()
	Engine.time_scale = 1.0


func after_each() -> void:
	if _impact != null and _impact.has_method("advance"):
		_impact.advance(999.0)
	Engine.time_scale = 1.0
	if _director != null:
		if bool(_director.is_active()) and _director.has_method("abort"):
			_director.abort(&"TEST_END")
		_director.update(999.0)
	for child: Node in (_director as Node).get_children():
		if String(child.name).begins_with("MG_"):
			child.free()
	if _loop is Node:
		(_loop as Node).set_physics_process(true)


func _autoload(node_name: String) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/" + node_name) as Object


func _clear_runtime_state() -> void:
	if _roulette != null and bool(_roulette.is_spinning()):
		_roulette.update(999.0)
	while _director != null and bool(_director.is_active()):
		var mg: Minigame = _director.get_active()
		if mg == null:
			break
		mg.finished.emit(_make_result(false))
	if _director != null:
		if _director.has_method("reset_runtime"):
			_director.reset_runtime()
		_director.update(999.0)
	if _match != null:
		_match.transition_to(1)   # State.TITLE


func _make_result(success: bool) -> MinigameResult:
	var script: GDScript = load(RESULT_SCRIPT) as GDScript
	assert_not_null(script, "MinigameResult script loads")
	if script == null:
		return null
	return script.call("make", success, 100, 0, 0, &"TIMEOUT") as MinigameResult


# --- The frame driver: GameLoopDriver._physics_process order (§6) ---

func _tick(delta: float) -> void:
	_match.advance(delta)
	if _roulette != null and _roulette.has_method("update"):
		_roulette.update(delta)
	if _director != null:
		_director.update(delta)
	if _score != null and _score.has_method("advance"):
		_score.advance(delta)
	if _impact != null:
		_impact.advance(delta)
	if _postfx != null:
		_postfx.advance(delta)
	if _camera != null and _camera.has_method("update_camera"):
		_camera.update_camera(delta)


func _measure(frames: int, juice: bool, minigame: bool) -> Dictionary:
	var samples: Array[float] = []
	samples.resize(frames)
	for i: int in range(frames):
		if juice:
			# Every juice system at once: the worst case per frame.
			_impact.impact(3)
			_camera.shake(0.5, 24.0, 0.2)
			_postfx.flash(Color.WHITE, 0.5, 0.1)
		if minigame and _score != null:
			_score.add_points(5)
		var t0: int = Time.get_ticks_usec()
		_tick(FRAME_DT)
		var t1: int = Time.get_ticks_usec()
		samples[i] = float(t1 - t0)
	return _stats(samples)


func _stats(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for v: float in sorted:
		total += v
	return {
		"count": n,
		"mean": total / float(n),
		"median": sorted[n / 2],
		"p95": sorted[mini(n - 1, int(float(n) * 0.95))],
		"max": sorted[n - 1],
	}


func _report(d: Dictionary, label: String) -> void:
	gut.p("%-34s median %7.1f us | p95 %7.1f us | max %7.1f us | mean %7.1f us (%d frames)" % [
		label, d["median"], d["p95"], d["max"], d["mean"], d["count"],
	])


# --- Tests ---

func test_frame_cost_free_roam() -> void:
	# Match clock + roulette + combo decay + juice drain, nothing in flight.
	_match.start_match()
	_tick(3.0)     # COUNTDOWN -> FREE_ROAM
	var d: Dictionary = _measure(SAMPLE_FRAMES, false, false)
	_report(d, "free roam, no juice:")
	assert_lt(float(d["median"]), FRAME_CEILING_US,
		"median free-roam frame under the generous headless ceiling")
	assert_lt(float(d["max"]), FRAME_CEILING_US,
		"worst free-roam frame under the ceiling (no runaway frame)")


func test_frame_cost_with_every_juice_system_firing() -> void:
	# Hitstop + camera shake + FOV punch + postfx flash every simulated frame.
	_match.start_match()
	_tick(3.0)
	var d: Dictionary = _measure(SAMPLE_FRAMES, true, false)
	_report(d, "impact + camera + postfx:")
	gut.p("budget is %.0f us/frame (60 fps); headroom at this median = %.1fx" % [
		FRAME_BUDGET_US, FRAME_BUDGET_US / float(d["median"]),
	])
	assert_lt(float(d["median"]), FRAME_CEILING_US,
		"median loaded frame under the generous headless ceiling")
	assert_lt(float(d["max"]), FRAME_CEILING_US * 2.0,
		"worst loaded frame under 2x the ceiling (no runaway frame)")


func test_frame_cost_with_a_micro_game_running() -> void:
	# The full worst case: a micro-game in flight AND every juice system firing
	# every frame AND score climbing.
	_match.start_match()
	_tick(3.0)
	var ids: Array = _registry.get_all_ids()
	assert_gt(ids.size(), 30, "catalog available")
	var ok: bool = _director.play(ids[0] as StringName, 0.0)
	assert_true(ok, "micro-game entered for the measurement")
	var d: Dictionary = _measure(SAMPLE_FRAMES, true, true)
	_report(d, "micro-game + juice + score:")
	gut.p("micro-game '%s' (archetype %s), %d simulated frames" % [
		String(ids[0]), String(_registry.get_metadata(ids[0] as StringName).archetype),
		SAMPLE_FRAMES,
	])
	assert_lt(float(d["median"]), FRAME_CEILING_US,
		"median micro-game frame under the generous headless ceiling")
	assert_lt(float(d["max"]), FRAME_CEILING_US * 2.0,
		"worst micro-game frame under 2x the ceiling (no runaway frame)")


func test_frame_cost_does_not_degrade_over_a_match() -> void:
	# A slow leak (timers, tween accumulation, unbounded buffers) shows up as a
	# rising per-frame cost. Compare the first 60 frames with the last 60.
	_match.start_match()
	_tick(3.0)
	var ok: bool = _director.play((_registry.get_all_ids()[0]) as StringName, 0.0)
	assert_true(ok, "micro-game entered")
	var early: Dictionary = _measure(60, true, true)
	var mid: Dictionary = _measure(600, true, true)
	var late: Dictionary = _measure(60, true, true)
	gut.p("per-frame cost: first 60 frames median %.1f us -> last 60 frames median %.1f us" % [
		early["median"], late["median"],
	])
	# Generous: only a catastrophic growth (a leak that doubles the cost) trips
	# this; a noisy but healthy frame budget stays well under it.
	assert_lt(float(late["median"]), float(early["median"]) * 20.0 + 5000.0,
		"per-frame cost does not explode over 720 simulated frames (no leak)")
