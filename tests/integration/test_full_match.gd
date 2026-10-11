extends "res://addons/gut/test.gd"
## tests/integration/test_full_match.gd — end-to-end proof that a FULL
## 5-minute match runs headless with the real systems (AGENTS.md §6: the
## full match flow gets a headless integration test).
##
## The pattern mirrors tests/unit/test_match_loop.gd: the GameLoopDriver's
## physics processing is frozen and time is advanced by explicit deltas, so
## the entire 300 s match (TITLE -> COUNTDOWN -> FREE_ROAM -> ROULETTE ->
## MINIGAME -> ... -> TIME_UP -> RESULTS) executes in milliseconds. Every
## system is the real autoload, resolved by PATH (/root/X), never by
## class_name. main.tscn itself is instanced headless (dummy renderer).
##
## Real bugs this suite documents while proving the flow (verified engine
## output in the QA report; each one is repeated where it bites below):
##   QA-1  MinigameDirector calls score.add_minigame_result(), which
##         ScoreDirector does not implement -> minigames never add score.
##   QA-2  Nothing wires roulette_started -> RouletteController.spin(),
##         nothing ticks RouletteController.update() and nothing routes
##         roulette_result -> MatchManager.start_minigame().
##   QA-3  MinigameDirector calls style.apply_pack_by_id(); StyleDirector
##         implements apply_pack_id() -> style packs never apply.
##   QA-6  MatchManager.finish_minigame(_result: Resource) rejects the
##         RefCounted MinigameResult -> the call type-errors and ABORTS the
##         director's finish handler mid-way (Godot 4.4 verified): no
##         STYLE_POP, no EventBus minigame_finished, no cooldown, and the
##         minigame node leaks (cleaned up by this test's after_each).
##   QA-7  MinigameDirector._check_match_timeout() evaluates
##         float(mm.time_left) on a METHOD -> script error on every tick,
##         so the MATCH_TIMEOUT abort never fires.
##   QA-5  Latent (masked by QA-6): the director would emit
##         "minigame_finished" with two arguments into a one-parameter
##         signal, which errors in GameHUD's handler (probe-verified).

const MAIN_SCENE := "res://src/bootstrap/main.tscn"
const RESULT_SCRIPT := "res://src/minigames/minigame_result.gd"
const REGISTRY_SCRIPT := "res://src/minigames/minigame_registry.gd"
const DIRECTOR_SCRIPT := "res://src/minigames/minigame_director.gd"

# MatchManager.State enum values. The enum itself only exists on the
# autoload (no class_name by design), so the numbers are the contract.
const STATE_TITLE := 1
const STATE_COUNTDOWN := 2
const STATE_FREE_ROAM := 3
const STATE_ROULETTE := 4
const STATE_MINIGAME := 5
const STATE_STYLE_POP := 6
const STATE_TIME_UP := 7
const STATE_RESULTS := 8

# Canonical EventBus signals recorded, in emission order, during a test.
const RECORDED_EVENTS: Array[String] = [
	"match_started", "powerup_collected", "roulette_started",
	"roulette_result", "minigame_started", "minigame_finished",
	"score_changed", "combo_changed", "style_applied",
	"match_time_up", "match_reset",
]

var _match: Object = null
var _director: Object = null
var _score: Object = null
var _rng: Object = null
var _bus: Object = null
var _roulette: Object = null
var _loop: Object = null
var _impact: Object = null
var _postfx: Object = null
var _registry: MinigameRegistry = null
var _main: Node = null

var _events: Array[String] = []      # event names, in emission order
var _event_args: Dictionary = {}     # event name -> [[a0, a1], ...]
var _recorder_links: Array = []      # [signal_name, Callable] pairs
var _frozen_nodes: Array[Node] = []  # ambient physics frozen for determinism
var _mg_events: Array = []           # [kind, payload] from the active minigame


func before_each() -> void:
	_resolve_autoloads()
	assert_not_null(_match, "MatchManager autoload present")
	assert_not_null(_director, "MinigameDirector autoload present")
	assert_not_null(_score, "ScoreDirector autoload present")
	assert_not_null(_bus, "EventBus autoload present")
	assert_not_null(_roulette, "RouletteController autoload present")
	# Freeze the real frame driver so these tests own time (determinism, §7.2).
	if _loop is Node:
		(_loop as Node).set_physics_process(false)
	# The ambient power-up layer spawns and self-collects through physics;
	# freeze it (process-locally) so pickups happen only through the
	# EventBus path under test.
	_freeze_ambient_powerups()
	# Reset shared runtime state left behind by previous tests in this file.
	_reset_shared_runtime_state()
	_connect_event_recorders()
	_instance_main_scene()


func after_each() -> void:
	_disconnect_event_recorders()
	# Leave no minigame in flight for the next test.
	while _director != null and bool(_director.is_active()):
		var mg: Minigame = _director.get_active()
		mg.finished.emit(_make_result(false))
	if _director != null:
		_director.update(999.0)
	_release_leaked_minigames()


func after_all() -> void:
	# One shared main scene for the whole file: freeing it per test would
	# leave a dangling &"player" registration in GameServices (which has no
	# unregister), so it lives until the run is over.
	if _main != null and is_instance_valid(_main):
		_main.free()
		_main = null
	for node: Node in _frozen_nodes:
		if is_instance_valid(node):
			node.set_physics_process(true)
	_frozen_nodes.clear()
	if _loop is Node:
		(_loop as Node).set_physics_process(true)


# --- Autoloads and scene (everything resolved by path) ---

func _autoload(node_name: String) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/" + node_name) as Object


func _resolve_autoloads() -> void:
	_match = _autoload("MatchManager")
	_director = _autoload("MinigameDirector")
	_score = _autoload("ScoreDirector")
	_rng = _autoload("SeededRNG")
	_bus = _autoload("EventBus")
	_roulette = _autoload("RouletteController")
	_loop = _autoload("GameLoop")
	_impact = _autoload("ImpactDirector")
	_postfx = _autoload("PostFXDirector")
	if _registry == null:
		_registry = load(REGISTRY_SCRIPT).new()
		_registry.scan()


func _instance_main_scene() -> void:
	if _main != null and is_instance_valid(_main):
		return
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	assert_not_null(scene, "main.tscn loads headless")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	add_child(main)
	_main = main


func _reset_shared_runtime_state() -> void:
	# Complete any roulette spin a previous test left mid-air...
	if _roulette != null and bool(_roulette.is_spinning()):
		_roulette.update(999.0)
	# ...abort any minigame still in flight...
	while _director != null and bool(_director.is_active()):
		var mg: Minigame = _director.get_active()
		mg.finished.emit(_make_result(false))
	# ...drain the inter-minigame cooldown, and return to TITLE.
	if _director != null:
		_director.update(999.0)
	if _match != null:
		_match.transition_to(STATE_TITLE)


# --- EventBus recorder ---

func _connect_event_recorders() -> void:
	_events.clear()
	_event_args.clear()
	_recorder_links.clear()
	if _bus == null:
		return
	for signal_name: String in RECORDED_EVENTS:
		if _bus.has_signal(signal_name):
			# A lambda per signal: the handler must receive whatever arity
			# the signal declares, so the event name is captured, not bound.
			var link: Callable = func(a0: Variant = null, a1: Variant = null) -> void:
				_record_event(signal_name, a0, a1)
			_bus.connect(signal_name, link)
			_recorder_links.append([signal_name, link])


func _disconnect_event_recorders() -> void:
	for link: Array in _recorder_links:
		var signal_name: String = link[0]
		var callable: Callable = link[1]
		if _bus != null and _bus.is_connected(signal_name, callable):
			_bus.disconnect(signal_name, callable)
	_recorder_links.clear()


func _record_event(event: String, a0: Variant, a1: Variant) -> void:
	_events.append(event)
	if not _event_args.has(event):
		_event_args[event] = []
	(_event_args[event] as Array).append([a0, a1])


func _event_recorded(event: String) -> bool:
	return event in _events


func _last_result_payload() -> MinigameResult:
	# Two emitters would fire "minigame_finished": MatchManager (one
	# argument, the result) and MinigameDirector (two: id, result). Accept
	# both shapes and return the result object.
	var history: Array = _event_args.get("minigame_finished", [])
	for i in range(history.size() - 1, -1, -1):
		var entry: Array = history[i]
		if entry[0] is MinigameResult:
			return entry[0] as MinigameResult
		if entry[1] is MinigameResult:
			return entry[1] as MinigameResult
	return null


func _connect_mg_events(mg: Minigame) -> void:
	_mg_events.clear()
	mg.event.connect(func(kind: StringName, payload: Dictionary) -> void:
		_mg_events.append([kind, payload])
	)


func _mg_ending_description() -> String:
	# The ending the archetype actually reached, as "success" or
	# "fail:<fail_on reason>". Empty when no ending event was seen.
	for entry: Array in _mg_events:
		var kind: StringName = entry[0]
		if kind == &"success":
			return "success"
		if kind == &"fail":
			return "fail:%s" % String((entry[1] as Dictionary).get("reason", ""))
	return ""


# --- Ambient physics freeze (determinism) ---

func _freeze_ambient_powerups() -> void:
	var director := _autoload("PowerUpDirector") as Node
	if director == null:
		return
	_freeze_recursive(director)


func _freeze_recursive(node: Node) -> void:
	if node.is_physics_processing():
		node.set_physics_process(false)
		_frozen_nodes.append(node)
	for child: Node in node.get_children():
		_freeze_recursive(child)


## QA-6 fallout: the finish handler aborts before queue_free(), so finished
## minigames leak under the director autoload. This test frees them itself.
func _release_leaked_minigames() -> void:
	var director_node := _director as Node
	if director_node == null:
		return
	for child: Node in director_node.get_children():
		if String(child.name).begins_with("MG_"):
			child.free()


# --- Flow helpers ---

func _start_match() -> void:
	assert_eq(int(_match.current_state()), STATE_TITLE, "pre-condition: TITLE")
	_match.start_match()
	assert_eq(int(_match.current_state()), STATE_COUNTDOWN, "COUNTDOWN after start_match()")


## One frame of every deterministic system, in the exact GameLoopDriver
## order (§6): match clock first, then gameplay, then juice.
func _tick(delta: float) -> void:
	_match.advance(delta)
	_director.update(delta)
	_score.advance(delta)
	if _impact != null and bool(_impact.has_method("advance")):
		_impact.advance(delta)
	if _postfx != null and bool(_postfx.has_method("advance")):
		_postfx.advance(delta)


## The REAL pick-up path for one micro-game: EventBus powerup_collected ->
## PowerUpDirector -> MatchManager.request_roulette() -> ROULETTE ->
## RouletteController.spin() -> update() -> roulette_result ->
## MinigameDirector.play(). Returns the chosen catalog id.
func _enter_minigame_through_powerup() -> StringName:
	# Drain any leftover anti-repetition cooldown from the previous minigame:
	# the cooldown exists to stop back-to-back replays in the real match, and
	# this helper must enter a fresh one deterministically.
	_director.update(999.0)
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM, "pre-condition: FREE_ROAM")
	_bus.emit_signal("powerup_collected", &"powerup")
	assert_eq(int(_match.current_state()), STATE_ROULETTE, "power-up pickup opens the roulette")
	assert_true(_event_recorded("roulette_started"), "roulette_started emitted")
	var chosen: StringName = _roulette.spin()
	assert_true(chosen != &"", "roulette returns a catalog id")
	assert_true(_registry.has_id(chosen), "roulette picked a real catalog id")
	_roulette.update(3.0)
	assert_true(_event_recorded("roulette_result"), "roulette_result emitted")
	assert_true(bool(_director.is_active()), "roulette_result starts the minigame through the director")
	assert_eq(_director.get_active_id(), chosen, "director plays the roulette's pick")
	assert_true(_event_recorded("minigame_started"), "minigame_started emitted")
	# BUG QA-2 (reported): nothing routes roulette_result to
	# MatchManager.start_minigame(), so the test drives that public API.
	_match.start_minigame(chosen)
	assert_eq(int(_match.current_state()), STATE_MINIGAME, "MINIGAME state")
	return chosen


## QA-6 workaround: finish_minigame() type-errors and never runs, leaving
## the match stuck in MINIGAME. This performs, through the state machine's
## public API, exactly the transition finish_minigame() was supposed to.
func _advance_past_stuck_minigame_state() -> void:
	_match.transition_to(STATE_STYLE_POP)
	_tick(1.5)
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM,
		"STYLE_POP -> FREE_ROAM through the state machine")
	_director.update(999.0)


func _make_result(success: bool, base: int = 0, bonus: int = 0, combo: int = 0) -> MinigameResult:
	var script: GDScript = load(RESULT_SCRIPT) as GDScript
	assert_not_null(script, "MinigameResult script loads")
	if script == null:
		return null
	var made: Variant = script.call("make", success, base, bonus, combo, &"" if success else &"TIMEOUT")
	return made as MinigameResult


func _pick_sequence_with_seed(seed_value: int, count: int) -> Array:
	_rng.seed(seed_value)
	# Fresh director per run: pick_next() filters by the director's own
	# anti-repetition state, so both runs must start from identical state.
	var director: MinigameDirector = load(DIRECTOR_SCRIPT).new()
	add_child_autofree(director)
	var ids: Array = []
	for _i in count:
		ids.append(director.pick_next(_rng))
	return ids


# --- Tests ---

func test_main_scene_boots_headless_and_registers_the_player() -> void:
	assert_not_null(_main, "main.tscn instanced headless")
	if _main == null:
		return
	assert_not_null(_main.get_node_or_null("World"), "World layer composed")
	assert_not_null(_main.get_node_or_null("HUD"), "HUD layer composed")
	assert_not_null(_main.get_node_or_null("Effects"), "Effects layer composed")
	var player: Node = _main.get_node_or_null("World/Player")
	assert_not_null(player, "player instanced under World")
	# The brief's check #2: the player is published in GameServices.
	var services := _autoload("GameServices")
	assert_not_null(services, "GameServices autoload present")
	if services == null or player == null:
		return
	assert_true(bool(services.has_service(&"player")), "player registered as a service")
	assert_eq(services.resolve(&"player"), player, "the registered service IS the scene player")
	assert_eq(int(_match.current_state()), STATE_TITLE, "the match boots in TITLE")


func test_full_match_flow_from_title_to_results() -> void:
	var history_before := int(_director.get_history().size())
	# --- TITLE -> COUNTDOWN (the scene booted in TITLE) ---
	_start_match()
	assert_true(_event_recorded("match_started"), "match_started emitted")
	var clock_at_countdown := float(_match.time_left())
	_tick(1.0)
	assert_almost_eq(float(_match.time_left()), clock_at_countdown, 0.001,
		"the countdown does not burn the match clock")
	# --- COUNTDOWN -> FREE_ROAM ---
	_tick(2.5)
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM, "FREE_ROAM after the 3-2-1")
	# --- FREE_ROAM -> ROULETTE -> MINIGAME #1 (finished like a player) ---
	var first_id: StringName = _enter_minigame_through_powerup()
	var mg1: Minigame = _director.get_active()
	assert_not_null(mg1, "minigame 1 active")
	var ctx: MinigameContext = mg1.get_context() if mg1 != null else null
	assert_not_null(ctx, "MinigameContext injected")
	if ctx != null:
		assert_not_null(ctx.metadata, "metadata injected")
		assert_eq(ctx.metadata.id, first_id, "metadata matches the played id")
		assert_not_null(ctx.score, "ScoreDirector injected")
		assert_not_null(ctx.style, "StyleDirector injected")
		assert_not_null(ctx.music, "MusicDirector injected")
		assert_not_null(ctx.impact, "ImpactDirector injected")
		assert_not_null(ctx.rng, "SeededRNG injected")
		assert_not_null(ctx.match_manager, "MatchManager injected")
		assert_not_null(ctx.player, "player resolved through GameServices")
		assert_true(ctx.player == null or is_instance_valid(ctx.player), "injected player is alive")
		assert_lte(float(ctx.time_left_in_match), float(_match.time_left()) + 0.001,
			"minigame time never exceeds the match clock (§7.1)")
	for _i in 4:
		_director.update(0.25)
	var result1: MinigameResult = _make_result(true, 1200, 300, 5)
	assert_eq(int(result1.total_score), 1500, "base + time bonus in the payload")
	mg1.finished.emit(result1)
	assert_false(bool(_director.is_active()), "director tore minigame 1 down")
	# --- QA-6 (FIXED): the finish advances the state machine ---
	# finish_minigame() now accepts a MinigameResult, so the director's finish
	# handler completes: state machine moves on, event reaches the bus,
	# cooldown is armed and the minigame node is torn down.
	assert_ne(int(_match.current_state()), STATE_MINIGAME,
		"QA-6 fixed: match leaves MINIGAME after the micro-game")
	assert_not_null(_last_result_payload(),
		"QA-6 fixed: minigame_finished reaches the bus with a result")
	# --- The state machine returns to FREE_ROAM through STYLE_POP ---
	var guard := 0
	while int(_match.current_state()) == STATE_STYLE_POP and guard < 60:
		_tick(0.1)
		guard += 1
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM,
		"STYLE_POP -> FREE_ROAM through the state machine")
	# --- MINIGAME #2: let its REAL duration elapse (auto timeout) ---
	var second_id: StringName = _enter_minigame_through_powerup()
	assert_ne(second_id, first_id, "the roulette avoids an immediate repeat")
	var second_mg: Minigame = _director.get_active()
	assert_not_null(second_mg, "minigame 2 active")
	_connect_mg_events(second_mg)
	var meta2: MinigameMetadata = _registry.get_metadata(second_id)
	assert_not_null(meta2, "metadata resolves for minigame 2")
	var steps := int(float(meta2.duration_s)) + 3
	for _i in steps:
		if not bool(_director.is_active()):
			break
		_tick(1.0)
	assert_false(bool(_director.is_active()), "minigame 2 finished on its own timer")
	# The ending is data-driven per archetype: fail with its ObjectiveRecipe
	# fail_on (TIMEOUT, FALL, TOUCH_HAZARD, WRONG_INPUT...) or survival
	# success when the duration simply elapses. All are legitimate.
	var ending := _mg_ending_description()
	assert_ne(ending, "", "minigame 2 emitted its ending event (fail or success)")
	gut.p("minigame 2 ('%s', archetype %s) ended by: %s (events seen: %d)" % [
		String(second_id), String(meta2.archetype), ending, _mg_events.size(),
	])
	# --- Burn the clock to TIME_UP ---
	var iterations := 0
	while int(_match.current_state()) != STATE_TIME_UP and iterations < 320:
		_tick(1.0)
		iterations += 1
	assert_eq(int(_match.current_state()), STATE_TIME_UP,
		"TIME_UP reached after burning %d accelerated seconds" % iterations)
	assert_almost_eq(float(_match.time_left()), 0.0, 0.001, "the clock stopped at zero")
	assert_true(_event_recorded("match_time_up"), "match_time_up emitted")
	# --- RESULTS ---
	_match.end_match()
	assert_eq(int(_match.current_state()), STATE_RESULTS, "RESULTS state")
	assert_true(_event_recorded("match_reset"), "match_reset emitted")
	# The micro-games really ran through the director, in one match.
	var history: Array = _director.get_history()
	assert_gte(int(history.size()) - history_before, 2, "two micro-games played in one match")
	for played: StringName in history:
		assert_true(_registry.has_id(played), "'%s' is a real catalog id" % String(played))
	# QA-3 evidence: style packs never apply (wrong method name), so no
	# style_applied event reaches the bus during the whole match.
	gut.p("QA-3 evidence: style_applied events during the full match: %d" % _events.count("style_applied"))


func test_match_time_up_ends_the_match_and_shows_results() -> void:
	_start_match()
	_tick(3.0)
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM, "FREE_ROAM")
	assert_almost_eq(float(_match.time_left()), 300.0, 0.001, "the countdown burned no clock")
	# A micro-game that cannot finish before the clock runs out (§7.1:
	# the director must abort it, never deadlock the match).
	var safety := 0
	while float(_match.time_left()) > 5.0 and safety < 320:
		_tick(1.0)
		safety += 1
	_enter_minigame_through_powerup()
	assert_true(bool(_director.is_active()), "micro-game in flight with under 5 s of match left")
	var iterations := 0
	while int(_match.current_state()) != STATE_TIME_UP and iterations < 30:
		_tick(1.0)
		iterations += 1
	assert_eq(int(_match.current_state()), STATE_TIME_UP, "TIME_UP reached")
	assert_almost_eq(float(_match.time_left()), 0.0, 0.001, "clock at zero")
	assert_true(_event_recorded("match_time_up"), "match_time_up emitted")
	# QA-7 (FIXED): _check_match_timeout() now calls time_left() as a method,
	# so when the match clock hits zero while a micro-game is in flight the
	# director aborts it instead of leaving it running past the match. The
	# archetype reports the abort back as a failed ending event.
	assert_false(bool(_director.is_active()),
		"QA-7 fixed: MATCH_TIMEOUT aborts the in-flight micro-game")
	var ending := _mg_ending_description()
	assert_ne(ending, "",
		"QA-7 fixed: the micro-game reported its ending (abort reached it)")
	gut.p("micro-game ended by: %s" % ending)
	_match.end_match()
	assert_eq(int(_match.current_state()), STATE_RESULTS, "RESULTS state")
	assert_true(_event_recorded("match_reset"), "match_reset emitted")


func test_minigame_results_feed_the_score_pipeline() -> void:
	_start_match()
	_tick(3.0)
	var id: StringName = _enter_minigame_through_powerup()
	var mg: Minigame = _director.get_active()
	assert_not_null(mg, "minigame active")
	var ctx: MinigameContext = mg.get_context() if mg != null else null
	assert_not_null(ctx.score, "the context carries a live ScoreDirector")
	var result: MinigameResult = _make_result(true, 1200, 300, 5)
	assert_eq(int(result.total_score), 1500, "the payload carries base + time bonus")
	assert_eq(result.grade, &"C", "grade from the combo peak (5 -> C)")
	# --- QA-1 evidence (reported): the director's finish handler calls
	# score.add_minigame_result(), which ScoreDirector does not implement;
	# the duck-typed has_method() guard skips it silently.
	var before_path := int(_score.total_score)
	mg.finished.emit(result)
	var after_path := int(_score.total_score)
	gut.p("QA-1 evidence: score through the director path %d -> %d for '%s' (ScoreDirector has no add_minigame_result())" % [
		before_path, after_path, String(id)
	])
	assert_eq(after_path, before_path,
		"documents the broken director->score seam (bug QA-1; invert when fixed)")
	# --- ScoreDirector itself accumulates micro-game results correctly
	# through its real API (base + combo multiplier + time bonus, §6.3).
	var gained: int = _score.score_minigame(int(result.base_score), 0.0)
	assert_eq(gained, 1200, "base score added")
	assert_eq(int(_score.total_score), 1200, "total accumulates")
	_score.register_success()
	var gained2: int = _score.score_minigame(int(result.base_score), 0.0)
	assert_gt(gained2, gained, "the combo multiplier compounds")
	assert_eq(String(_score.current_rank()), &"D", "rank D below 5000 points")
	assert_true(_event_recorded("score_changed"), "score_changed emitted")
	assert_true(_event_recorded("combo_changed"), "combo_changed emitted")


func test_same_seed_replays_the_same_minigame_sequence() -> void:
	var run_a: Array = _pick_sequence_with_seed(4242, 8)
	var run_b: Array = _pick_sequence_with_seed(4242, 8)
	assert_eq(run_a.size(), 8, "the selector returned an id for every pick")
	assert_eq(run_a, run_b, "same SeededRNG seed replays the same minigame sequence")
	var run_c: Array = _pick_sequence_with_seed(987654, 8)
	assert_ne(run_c, run_a, "a different seed diverges")
	for id: StringName in run_a:
		assert_true(_registry.has_id(id), "'%s' is a real catalog id" % String(id))
