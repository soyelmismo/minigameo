extends GutTest
## Integration of the three gameplay contracts the full-match QA pass found
## broken end to end (scaffold §6.2, §6.3, §6.4, §7.4).
##
##   QA-1  ScoreDirector never implemented add_minigame_result(), so the
##         MinigameDirector's call silently no-op'd and micro-games never
##         added score to the match.
##   QA-2  Nothing routed roulette_result -> MatchManager.start_minigame(),
##         and GameLoop never ticked the RouletteController, so the roulette
##         never resolved in a real run.
##   QA-3  MinigameDirector called StyleDirector.apply_pack_by_id(), which
##         does not exist (apply_pack_id() does), so style packs never applied.
##
## The autoloads are resolved by path: in a --script context the engine does
## not register them as global identifiers.

const MATCH_SCRIPT := "res://src/match/match_manager.gd"
const SCORE_SCRIPT := "res://src/match/score/score_director.gd"
const RESULT_SCRIPT := "res://src/minigames/minigame_result.gd"
const ROULETTE_SCRIPT := "res://src/powerups/roulette/roulette_controller.gd"
const STYLE_SCRIPT := "res://src/styles/style_director.gd"
const GAME_LOOP_SCRIPT := "res://src/core/game_loop.gd"


func _autoload(node_name: StringName) -> Object:
	var root := get_tree().root
	if root == null:
		return null
	return root.get_node_or_null("/root/" + String(node_name)) as Object


func _make_result(success: bool, base: int, bonus: int, combo_max: int) -> Object:
	var script: GDScript = load(RESULT_SCRIPT) as GDScript
	assert_not_null(script, "MinigameResult script loads")
	var made: Variant = script.call(
		"make", success, base, bonus, combo_max, &"" if success else &"TIMEOUT"
	)
	return made


# --- QA-1: a finished micro-game adds score to the match ---

func test_minigame_result_adds_score_through_the_director() -> void:
	var score: Object = load(SCORE_SCRIPT).new()
	add_child_autofree(score)
	assert_true(score.has_method("add_minigame_result"),
		"ScoreDirector exposes the MinigameResult adapter")

	var before: int = score.total_score
	var gain: int = score.add_minigame_result(_make_result(true, 1200, 300, 5))
	assert_gt(gain, 0, "a successful micro-game pays out")
	assert_eq(score.total_score, before + gain,
		"the match total absorbs the payout exactly once")
	assert_eq(score.combo, 1, "a success bumps the combo")


func test_failed_minigame_breaks_the_combo_and_still_counts_base() -> void:
	var score: Object = load(SCORE_SCRIPT).new()
	add_child_autofree(score)
	score.register_success()
	assert_eq(score.combo, 1, "combo armed before the failure")
	var gain: int = score.add_minigame_result(_make_result(false, 400, 0, 0))
	assert_eq(score.combo, 0, "a failure resets the combo")
	assert_gt(gain, 0, "the base score still counts on a failure")
	assert_gte(score.total_score, 400, "the match total absorbed the base")


func test_time_bonus_joins_unscaled() -> void:
	var score: Object = load(SCORE_SCRIPT).new()
	add_child_autofree(score)
	# base 0 with a bonus: only the bonus can produce points, and it must
	# arrive unscaled (the multiplier applies to the base only).
	var gain: int = score.add_minigame_result(_make_result(true, 0, 250, 3))
	assert_eq(gain, 250, "time bonus is added raw")
	assert_eq(score.total_score, 250, "total equals the raw bonus")


func test_null_result_is_rejected() -> void:
	var score: Object = load(SCORE_SCRIPT).new()
	add_child_autofree(score)
	assert_eq(score.add_minigame_result(null), 0, "null pays nothing and does not crash")


# --- QA-2: roulette_result starts the micro-game ---

func test_roulette_result_starts_the_minigame_through_the_bus() -> void:
	var match_mgr: Object = load(MATCH_SCRIPT).new()
	add_child_autofree(match_mgr)
	match_mgr.start_match()
	match_mgr.advance(match_mgr.config.countdown_s + 0.1)
	assert_eq(match_mgr.current_state(), match_mgr.State.FREE_ROAM,
		"pre-condition: FREE_ROAM")
	match_mgr.request_roulette()
	assert_eq(match_mgr.current_state(), match_mgr.State.ROULETTE,
		"roulette opened")

	# The bus event, exactly as RouletteController emits it on finish. The
	# contract under test is MatchManager's: it must play the pick through the
	# director and commit to MINIGAME only once the play is confirmed. A stub
	# that accepts pins that without depending on the real director's cooldown,
	# which a unit harness cannot control (it is global autoload state).
	var services: Object = _autoload(&"GameServices")
	assert_not_null(services, "GameServices autoload present")
	# Restore the registry to whatever it held before the stub, so the real
	# MinigameDirector (if it was registered) is still there afterwards.
	var previous: Object = services.resolve(&"minigames")
	var accepting: Object = _StubDirector.new(true)
	add_child_autofree(accepting)
	services.register(&"minigames", accepting)

	EventBus.emit(&"roulette_result", &"token_rush")
	var played_state: int = int(match_mgr.current_state())
	if previous != null:
		services.register(&"minigames", previous)
	assert_eq(played_state, int(match_mgr.State.MINIGAME),
		"roulette_result transitions to MINIGAME when the director accepts the play")

	# Hand the match back to FREE_ROAM: request_roulette() only opens the wheel
	# from FREE_ROAM, so the refusal path must start from a settled state.
	match_mgr.finish_minigame(null)
	match_mgr.advance(match_mgr.config.style_pop_s + 0.1)
	assert_eq(int(match_mgr.current_state()), int(match_mgr.State.FREE_ROAM),
		"pre-condition: back in FREE_ROAM after the first micro-game")

	# Refusal path: the match must recover, not deadlock in an empty MINIGAME.
	var refusing: Object = _StubDirector.new(false)
	add_child_autofree(refusing)
	services.register(&"minigames", refusing)
	match_mgr.request_roulette()
	EventBus.emit(&"roulette_result", &"token_rush")
	var refused_state: int = int(match_mgr.current_state())
	if previous != null:
		services.register(&"minigames", previous)
	assert_eq(refused_state, int(match_mgr.State.FREE_ROAM),
		"a refused play recovers to FREE_ROAM instead of deadlocking in MINIGAME")


func test_game_loop_ticks_the_roulette() -> void:
	var loop: Object = load(GAME_LOOP_SCRIPT).new()
	add_child_autofree(loop)
	# The real autoload: the loop resolves /root/<name>, which is exactly where
	# the engine puts autoloads.
	var roulette: Object = _autoload(&"RouletteController")
	assert_not_null(roulette, "RouletteController autoload present")
	# A previous test's spin may still be in flight; drain it so this one starts
	# from a known state (spin() refuses to start while one is running).
	if bool(roulette.is_spinning()):
		roulette.update(999.0)
	var chosen: StringName = roulette.spin()
	assert_ne(chosen, &"", "the roulette picked an id")
	assert_true(bool(roulette.is_spinning()), "the roulette is in flight")

	# A physics tick past the spin duration must resolve it, and the spin
	# routes straight into the minigame director (the QA-2 wiring).
	loop._physics_process(float(roulette.spin_duration_s) + 0.1)
	assert_false(bool(roulette.is_spinning()),
		"the GameLoop tick advanced the roulette to completion")
	var director: Object = _autoload(&"MinigameDirector")
	if director != null and director.has_method("abort"):
		director.abort(&"TEST_CLEANUP")


# --- QA-3: the style pack applies through the real method name ---

func test_style_director_applies_a_pack_by_id() -> void:
	var style: Object = load(STYLE_SCRIPT).new()
	add_child_autofree(style)
	assert_true(style.has_method("apply_pack_id"),
		"StyleDirector exposes apply_pack_id")
	assert_false(style.has_method("apply_pack_by_id"),
		"apply_pack_by_id must not be reintroduced as a shadow name")

	# The MinigameDirector's guard is has_method(...) + call, so the real
	# contract is that a valid id takes effect.
	style.apply_pack_id(&"NEON_DRIFT")
	var active: StylePack = style.current_pack()
	assert_not_null(active, "the style pack is the one the metadata requested")
	assert_eq(active.id, &"NEON_DRIFT", "NEON_DRIFT is now the active pack")
	assert_true(bool(style.is_styled()), "the director reports a styled world")


# --- Minimal director stub for the roulette_result wiring test ---

## Stands in for MinigameDirector: accepts or refuses play() on demand so the
## match's commit-and-recover paths can be driven without a real cooldown.
class _StubDirector extends Node:

	var _accept: bool = true

	func _init(accept: bool = true) -> void:
		_accept = accept

	func play(_id: StringName, _difficulty: float = 0.0) -> bool:
		return _accept
