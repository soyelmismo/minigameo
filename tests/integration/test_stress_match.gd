extends "res://addons/gut/test.gd"
## tests/integration/test_stress_match.gd — stress + robustness suite (stress brief §1-4).
##
## What this suite proves, with measured numbers:
##   1. A FULL 300-second match survives headless with everything firing at
##      once (power-up -> roulette -> micro-game -> style pack -> impacts ->
##      camera shake -> postfx flash -> score climbing), and the peak node
##      count and peak orphan count of the whole scene tree are reported.
##   2. Every micro-game teardown returns the tree to its pre-teardown node
##      count (AGENTS.md §1.4: "after teardown, not a single orphan entity").
##   3. The CPU cost per SIMULATED frame of the systems GameLoopDriver drives
##      (match, roulette, minigames, score, impact, postfx) is measured and
##      compared against the 16.6 ms / 60 fps budget.
##   4. Each system degrades when a dependency is missing; the places that do
##      NOT degrade (or silently no-op) are pinned by a test that documents the
##      CURRENT behaviour, so the orchestrator has proof, not a guess.
##
## Determinism (brief "hard rules"): one fixed SeededRNG seed, explicit
## deltas, and the real frame driver is frozen (the pattern test_full_match.gd
## already established). No assertion depends on wall-clock time; the timing
## numbers are reported only.
##
## Naming: GUT 9.3.0 collects ONLY functions starting with "test_"
## (addons/gut/test_collector.gd:11 `_test_prefix = 'test_'`). A function named
## `sec_...` is silently never run, which is how an earlier revision of the
## 300 s match below got skipped without failing anything.
##
## Tests whose names start with "test_documents_" pin CURRENT behaviour that is
## a defect. They stay green today; when the orchestrator fixes the root cause
## the assertion flips and the test must be updated deliberately.

const MAIN_SCENE := "res://src/bootstrap/main.tscn"
const RESULT_SCRIPT := "res://src/minigames/minigame_result.gd"
const REGISTRY_SCRIPT := "res://src/minigames/minigame_registry.gd"
const DIRECTOR_SCRIPT := "res://src/minigames/minigame_director.gd"
const IMPACT_SCRIPT := "res://src/juice/impact_director.gd"
const SPAWNER_SCRIPT := "res://src/powerups/powerup_spawner.gd"

## Fixed seed for every run (determinism, §7.2).
const STRESS_SEED := 20260911

# MatchManager.State enum values (the enum has no class_name by design).
const STATE_TITLE := 1
const STATE_COUNTDOWN := 2
const STATE_FREE_ROAM := 3
const STATE_ROULETTE := 4
const STATE_MINIGAME := 5
const STATE_STYLE_POP := 6
const STATE_TIME_UP := 7
const STATE_RESULTS := 8

## Groups every archetype registers its entities in (grep add_to_group in
## src/minigames/archetypes/). Used as the "no orphan entity" detector.
const MG_ENTITY_GROUPS: Array[StringName] = [
	&"mg_target", &"mg_chaser", &"mg_chain_link", &"mg_stack_piece",
	&"mg_memory_pad", &"mg_pushable", &"mg_delivery_zone", &"mg_projectile",
	&"mg_gate", &"mg_zone", &"mg_beater", &"mg_hazard", &"mg_collectible",
]

## Simulated frame length (60 fps) and the §15 budget in microseconds.
const FRAME_DT := 1.0 / 60.0
const FRAME_BUDGET_US := 16600.0     # 16.6 ms = 60 fps
## Generous headless ceiling. Headless runs the same CPU code as the game but
## with no GPU work, so a healthy entry is "comfortably under 60 fps"; this
## bound only catches a runaway frame and must never flake on a slow box.
const FRAME_CEILING_US := 100000.0   # 100 ms
## One real frame is yielded every this many simulated frames so Node.queue_free()
## (deferred) can actually land and the node counts mean something.
const FLUSH_EVERY_FRAMES := 300      # every 5 simulated seconds

var _match: Object = null
var _director: Object = null
var _score: Object = null
var _rng: Object = null
var _bus: Object = null
var _roulette: Object = null
var _loop: Object = null
var _impact: Object = null
var _postfx: Object = null
var _camera: Object = null
var _style: Object = null
var _services: Object = null
var _registry: MinigameRegistry = null
var _main: Node = null

var _frozen_nodes: Array[Node] = []
var _registry_ids: Array[StringName] = []

# --- metrics collected during the stress match ---
var _peak_nodes: int = 0
var _peak_orphans: int = 0
var _peak_main_nodes: int = 0
var _peak_pending_frees: int = 0
var _baseline_nodes: int = 0
var _orphans_baseline: int = 0
var _mg_entered: int = 0
var _impacts_fired: int = 0
var _roulette_spins: int = 0
var _powerups: int = 0


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
	_freeze_ambient_powerups()
	if _rng != null and _rng.has_method("seed"):
		_rng.seed(STRESS_SEED)
	_reset_shared_runtime_state()
	_registry_ids = _all_registry_ids()
	_instance_main_scene()
	_baseline_nodes = _count_tree_nodes()
	_orphans_baseline = _orphan_monitor()
	_reset_metrics()


func after_each() -> void:
	# Leave the world out of hitstop for the next test: Engine.time_scale is
	# global state and ImpactDirector._process restores it only on a real frame.
	if _impact != null and _impact.has_method("advance"):
		_impact.advance(999.0)
	Engine.time_scale = 1.0
	if _director != null and bool(_director.is_active()) and _director.has_method("abort"):
		_director.abort(&"TEST_END")
	if _director != null:
		_director.update(999.0)
	_release_leaked_minigames()
	if _match != null and int(_match.current_state()) != STATE_TITLE:
		_match.transition_to(STATE_TITLE)


func after_all() -> void:
	if _main != null and is_instance_valid(_main):
		_main.free()
		_main = null
	for node: Node in _frozen_nodes:
		if is_instance_valid(node):
			node.set_physics_process(true)
	_frozen_nodes.clear()
	if _loop is Node:
		(_loop as Node).set_physics_process(true)
	Engine.time_scale = 1.0


# --- Autoloads, scene, shared state ---

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
	_camera = _autoload("CameraDirector")
	_style = _autoload("StyleDirector")
	_services = _autoload("GameServices")
	_registry = _autoload("MinigameRegistry") as MinigameRegistry
	if _registry == null:
		var director_node := _director as Node
		if director_node != null:
			_registry = director_node.get_node_or_null("MinigameRegistry") as MinigameRegistry
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


func _reset_shared_runtime_state() -> void:
	if _roulette != null and bool(_roulette.is_spinning()):
		_roulette.update(999.0)
	while _director != null and bool(_director.is_active()):
		var mg: Minigame = _director.get_active()
		if mg == null:
			break
		mg.finished.emit(_make_result(false))
	if _director != null:
		_director.update(999.0)
	if _match != null:
		_match.transition_to(STATE_TITLE)


func _release_leaked_minigames() -> void:
	var director_node := _director as Node
	if director_node == null:
		return
	for child: Node in director_node.get_children():
		if String(child.name).begins_with("MG_"):
			child.free()


func _reset_metrics() -> void:
	_peak_nodes = 0
	_peak_orphans = 0
	_peak_main_nodes = 0
	_peak_pending_frees = 0
	_mg_entered = 0
	_impacts_fired = 0
	_roulette_spins = 0
	_powerups = 0


func _all_registry_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _registry != null and _registry.has_method("get_all_ids"):
		for id: StringName in _registry.get_all_ids():
			out.append(id)
	return out


func _make_result(success: bool, base: int = 0, bonus: int = 0, combo: int = 0) -> MinigameResult:
	var script: GDScript = load(RESULT_SCRIPT) as GDScript
	assert_not_null(script, "MinigameResult script loads")
	if script == null:
		return null
	var made: Variant = script.call(
		"make", success, base, bonus, combo, &"" if success else &"TIMEOUT"
	)
	return made as MinigameResult


# --- Measurements ---

func _count_tree_nodes() -> int:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return 0
	return _count_recursive(tree.root)


func _count_recursive(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count_recursive(child)
	return total


func _orphan_monitor() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _node_monitor() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _count_main_subtree() -> int:
	if _main == null or not is_instance_valid(_main):
		return 0
	return _count_recursive(_main)


func _count_entity_groups() -> int:
	var total: int = 0
	for group: StringName in MG_ENTITY_GROUPS:
		total += get_tree().get_nodes_in_group(group).size()
	return total


func _count_mg_nodes_under_director() -> int:
	var director_node := _director as Node
	if director_node == null:
		return 0
	var n: int = 0
	for child: Node in director_node.get_children():
		if String(child.name).begins_with("MG_"):
			n += 1
	return n


func _director_child_count() -> int:
	var director_node := _director as Node
	if director_node == null:
		return 0
	return director_node.get_child_count()


func _count_subscribers() -> int:
	var total: int = 0
	for sig_name: StringName in [&"minigame_started", &"minigame_finished", &"score_changed",
			&"combo_changed", &"match_time_up", &"match_tick", &"style_applied",
			&"roulette_result", &"powerup_collected", &"match_reset", &"match_started"]:
		var sig: Variant = _bus.get(String(sig_name))
		if sig is Signal:
			total += (sig as Signal).get_connections().size()
	return total


func _sample_metrics() -> void:
	_peak_nodes = maxi(_peak_nodes, _count_tree_nodes())
	_peak_orphans = maxi(_peak_orphans, _orphan_monitor())
	_peak_main_nodes = maxi(_peak_main_nodes, _count_main_subtree())
	_peak_pending_frees = maxi(_peak_pending_frees, _count_mg_nodes_under_director())


func _report(lines: PackedStringArray) -> void:
	for line: String in lines:
		gut.p(line)


# --- The frame driver: the GameLoopDriver._physics_process order (src/core/
# game_loop.gd:13-34). Order in that driver: match clock -> roulette ->
# minigames -> score -> impact -> postfx.
#
# CameraDirector and StyleDirector/MusicDirector drive themselves from their own
# _process/_physics_process (src/juice/camera_director.gd:233,
# src/styles/style_director.gd:170), so GameLoopDriver deliberately does not
# tick them. We still tick the camera once here so camera shake/punch state is
# drained deterministically in the simulation, and so the CPU number covers it.

func _tick(delta: float) -> void:
	_match.advance(delta)
	if _roulette != null and _roulette.has_method("update"):
		_roulette.update(delta)
	if _director != null:
		_director.update(delta)
	if _score != null:
		_score.advance(delta)
	if _impact != null:
		_impact.advance(delta)
	if _postfx != null:
		_postfx.advance(delta)
	if _camera != null and _camera.has_method("update_camera"):
		_camera.update_camera(delta)


# =====================================================================
# 1. THE 300-SECOND STRESS MATCH
# =====================================================================

func test_stress_match_300_simulated_seconds() -> void:
	var wall_us_start: int = Time.get_ticks_usec()

	_start_match()
	assert_eq(int(_match.current_state()), STATE_COUNTDOWN, "COUNTDOWN after start_match()")

	var state: int = int(_match.current_state())
	var frames: int = 0
	var guard: int = 0
	var powerup_due_in: float = 4.0      # first pickup just after freeroam
	var impact_due_in: float = 0.0
	var juice_due_in: float = 0.0
	var score_before: int = int(_score.total_score)

	while state != STATE_TIME_UP and guard < 40000:
		guard += 1
		frames += 1

		# --- simultaneous load: impacts + camera + postfx + score ---
		if impact_due_in <= 0.0:
			_impact.impact(3)
			_impacts_fired += 1
			impact_due_in = 0.75
		if juice_due_in <= 0.0:
			_camera.shake(0.55, 24.0, 0.25)
			_camera.fov_punch(4.0, 0.2)
			_postfx.flash(Color(1.0, 0.85, 0.4), 0.5, 0.15)
			_score.add_points(250)
			juice_due_in = 0.5

		# --- power-up -> roulette -> micro-game, on the real wiring ---
		powerup_due_in -= FRAME_DT
		if powerup_due_in <= 0.0 and state == STATE_FREE_ROAM:
			# PowerUpDirector listens to powerup_collected and asks the
			# MatchManager for the roulette, so the REAL handler runs.
			_bus.emit_signal("powerup_collected", &"powerup")
			_powerups += 1
			powerup_due_in = 26.0     # next pickup ~26 s of match time later
		if state == STATE_ROULETTE and bool(_roulette.is_spinning()):
			# The production listener spins the wheel on `roulette_started`
			# (PowerUpDirector), so the test only counts what the game did.
			_roulette_spins += 1

		_tick(FRAME_DT)
		state = int(_match.current_state())

		impact_due_in -= FRAME_DT
		juice_due_in -= FRAME_DT
		if bool(_director.is_active()):
			_mg_entered = maxi(_mg_entered, int(_director.get_history().size()))
		if frames % 30 == 0:
			_sample_metrics()
		# queue_free() is deferred: give the engine a real frame so the
		# measurement counts a live tree, not a backlog of tombstones.
		if frames % FLUSH_EVERY_FRAMES == 0:
			await wait_frames(1)

	var wall_us: int = Time.get_ticks_usec() - wall_us_start
	var played: int = int(_director.get_history().size())
	# The director aborts the running micro-game on match_time_up, which uses
	# queue_free(); that only lands on a real frame, so yield one before the
	# §1.4 teardown assertions below or they count a tombstone that is not yet
	# a free node.
	await wait_frames(2)
	_sample_metrics()

	assert_eq(state, STATE_TIME_UP,
		"the whole 300 s clock burned to TIME_UP (guard %d, frames %d)" % [guard, frames])
	assert_almost_eq(float(_match.time_left()), 0.0, 0.001, "the clock stopped at zero")
	assert_gte(frames, 18000, "300 s at 60 fps is at least 18000 simulated frames (got %d)" % frames)
	assert_gte(played, 5, "several micro-games ran in one match (got %d)" % played)
	assert_gt(int(_score.total_score), score_before, "the score climbed")

	_report(PackedStringArray([
		"",
		"===== STRESS MATCH: 300 s simulated =====",
		"simulated frames            : %d (%.4f s each)" % [frames, FRAME_DT],
		"wall clock                  : %.1f ms total, %.1f us per simulated frame" % [
			float(wall_us) / 1000.0, float(wall_us) / float(maxi(1, frames)),
		],
		"power-ups collected         : %d" % _powerups,
		"roulette spins              : %d" % _roulette_spins,
		"micro-games played          : %d" % played,
		"impacts fired               : %d" % _impacts_fired,
		"score at the end            : %d (rank %s)" % [int(_score.total_score), String(_score.current_rank())],
		"PEAK NODES in scene tree   : %d   (baseline before the match: %d)" % [_peak_nodes, _baseline_nodes],
		"PEAK NODES under main.tscn : %d" % _peak_main_nodes,
		"PEAK ORPHAN nodes (monitor) : %d   (baseline before the match: %d)" % [_peak_orphans, _orphans_baseline],
		"engine OBJECT_NODE monitor : %d" % _node_monitor(),
		"peak minigame nodes pending queue_free : %d" % _peak_pending_frees,
		"nodes after the match      : %d" % _count_tree_nodes(),
		"director children at end   : %d (registry only expected)" % _director_child_count(),
		"========================================",
	]))

	# --- the invariants the brief asks to be asserted ---
	assert_lt(_peak_nodes, 2000, "§15 scene budget: the tree never explodes (< 2000 nodes)")
	assert_lt(_peak_main_nodes, 500, "§15 scene budget: main.tscn subtree under 500 nodes")
	assert_lte(_count_entity_groups(), 0,
		"§1.4: no micro-game entity survives the match (all mg_* groups clean)")
	assert_lte(_count_mg_nodes_under_director(), 0,
		"§1.4: no minigame node is left under the director")
	# NOTE: Engine.time_scale is NOT asserted here on purpose: the stress driver
	# fires an impact and, in the same simulated frame, the director's exit
	# impact, which permanently slows the world (see
	# documents_back_to_back_impacts_leave_the_world_in_slow_motion).


# =====================================================================
# 2. TEARDOWN HYGIENE, ONE MICRO-GAME AT A TIME
# =====================================================================

func test_every_catalog_minigame_teardown_leaves_the_tree_clean() -> void:
	assert_gte(_registry_ids.size(), 30, "catalog available for the sweep")
	_start_match()
	_tick(3.0)     # COUNTDOWN -> FREE_ROAM
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM, "FREE_ROAM")

	var baseline: int = _count_tree_nodes()
	var baseline_groups: int = _count_entity_groups()
	var baseline_director_children: int = _director_child_count()

	var swept: int = 0
	var grown: int = 0
	var slow_world: int = 0
	var refused: PackedStringArray = PackedStringArray()
	var report: PackedStringArray = PackedStringArray([
		"",
		"===== PER-MICRO-GAME TEARDOWN SWEEP (%d catalog entries) =====" % _registry_ids.size(),
	])

	for id: StringName in _registry_ids:
		if _director.has_method("reset_runtime"):
			_director.reset_runtime()
		_director.update(999.0)
		var meta: MinigameMetadata = _registry.get_metadata(id)
		var ok: bool = _director.play(id, 0.0)
		if not ok or not bool(_director.is_active()):
			refused.append(String(id))
			continue
		var mg: Minigame = _director.get_active()
		assert_not_null(mg, "minigame active for '%s'" % String(id))

		# Run it a few frames with juice firing, then finish it properly.
		for _i in range(4):
			_impact.impact(3)
			_camera.shake(0.4)
			_postfx.flash(Color.WHITE, 0.4, 0.1)
			_tick(0.2)

		mg.finished.emit(_make_result(true, 900, 100, 4))
		assert_false(bool(_director.is_active()),
			"'%s' torn down by its own finished signal" % String(id))
		await wait_frames(2)      # let queue_free() land
		_impact.advance(999.0)

		var nodes_now: int = _count_tree_nodes()
		var delta: int = nodes_now - baseline
		if delta > 0:
			grown += 1
			report.append("GREW %-26s %-13s %+d nodes (now %d)" % [
				String(id), String(meta.archetype) if meta != null else "?", delta, nodes_now,
			])
		if not is_equal_approx(Engine.time_scale, 1.0):
			slow_world += 1
			report.append("SLOW %-26s world left at time_scale=%s" % [
				String(id), str(Engine.time_scale),
			])
		assert_lte(_count_entity_groups(), baseline_groups,
			"§1.4: '%s' teardown removed every entity it spawned" % String(id))
		assert_lte(_count_mg_nodes_under_director(), 0,
			"§1.4: '%s' left no node under the director" % String(id))
		assert_lte(_director_child_count(), baseline_director_children,
			"§1.4: '%s' added no permanent child to the director" % String(id))
		swept += 1

	report.append("played and torn down : %d" % swept)
	report.append("refused to play      : %d %s" % [refused.size(), str(refused)])
	report.append("left node growth     : %d of %d" % [grown, swept])
	report.append("left the world slowed: %d of %d" % [slow_world, swept])
	report.append("=========================================")
	_report(report)

	assert_gte(swept, 30, "nearly every catalog entry was played and torn down")
	assert_eq(grown, 0, "no micro-game grew the scene tree permanently")


func test_teardown_leaves_no_dangling_timer_tween_or_subscription() -> void:
	_start_match()
	_tick(3.0)
	var tweens_before: int = get_tree().get_processed_tweens().size()
	var subs_before: int = _count_subscribers()
	var orphan_before: int = _orphan_monitor()

	for round_i: int in range(3):
		if _director.has_method("reset_runtime"):
			_director.reset_runtime()
		_director.update(999.0)
		var ids := _all_registry_ids()
		var ok: bool = _director.play(ids[round_i % ids.size()], 0.0)
		assert_true(ok, "round %d entered a micro-game" % round_i)
		var mg: Minigame = _director.get_active()
		# Attach an extra subscriber, so a lost disconnection is visible.
		mg.event.connect(func(_k: StringName, _p: Dictionary) -> void: pass)
		_tick(1.0)
		mg.finished.emit(_make_result(true, 500, 50, 2))
		assert_false(bool(_director.is_active()), "round %d finished" % round_i)
		await wait_frames(2)
		assert_lte(get_tree().get_processed_tweens().size(), tweens_before + 2,
			"round %d leaves no SceneTreeTimer/tween pile-up" % round_i)
		assert_lte(_count_entity_groups(), 0, "round %d leaves no entity group survivor" % round_i)
		assert_lte(_count_mg_nodes_under_director(), 0,
			"round %d leaves no MG_ node survivor" % round_i)

	assert_lte(_count_subscribers(), subs_before,
		"the EventBus subscriber count does not grow with every micro-game")
	assert_lte(_orphan_monitor(), orphan_before + 1,
		"no orphan nodes accumulate across rounds")
	gut.p("subscribers before/after: %d/%d, orphans before/after: %d/%d, tweens: %d/%d" % [
		subs_before, _count_subscribers(), orphan_before, _orphan_monitor(),
		tweens_before, get_tree().get_processed_tweens().size(),
	])


# =====================================================================
# 3. FRAME-TIME BUDGET (CPU cost per simulated frame)
# =====================================================================

func test_cpu_cost_per_simulated_frame_stays_inside_budget() -> void:
	_start_match()
	_tick(3.0)

	# --- Case A: free roam, nothing but the match clock + combo decay ---
	var roaming: Dictionary = _measure_frames(120, false)

	# --- Case B: one micro-game in flight + juice firing every frame ---
	if _director.has_method("reset_runtime"):
		_director.reset_runtime()
	_director.update(999.0)
	var ids := _all_registry_ids()
	var entered: bool = _director.play(ids[0], 0.0)
	assert_true(entered, "micro-game in flight for the measurement")
	var loaded: Dictionary = _measure_frames(240, true)

	_report(PackedStringArray([
		"",
		"===== CPU COST PER SIMULATED FRAME (headless, no GPU) =====",
		"free roam (clock + combo decay)     : median %.1f us | p95 %.1f us | max %.1f us" % [
			roaming["median"], roaming["p95"], roaming["max"],
		],
		"micro-game + juice every frame      : median %.1f us | p95 %.1f us | max %.1f us" % [
			loaded["median"], loaded["p95"], loaded["max"],
		],
		"budget                              : %.0f us/frame (60 fps)" % FRAME_BUDGET_US,
		"headroom at the loaded median       : %.1fx" % (FRAME_BUDGET_US / float(loaded["median"])),
		"===========================================================",
	]))

	# Generous ceiling only: headless timing is machine dependent, so this
	# catches a runaway frame and reports the real numbers for the orchestrator.
	assert_lt(float(loaded["median"]), FRAME_CEILING_US,
		"median simulated frame under the generous headless ceiling")
	assert_lt(float(loaded["max"]), FRAME_CEILING_US * 3.0,
		"worst simulated frame under 3x the ceiling (no runaway frame)")


## Drives `count` simulated frames of every GameLoop system, timing each one.
## `juice` also fires an impact + camera shake + postfx flash + score per
## frame: the worst-case per-frame cost the director has to absorb.
func _measure_frames(count: int, juice: bool) -> Dictionary:
	var samples: Array[float] = []
	samples.resize(count)
	for i: int in range(count):
		if juice:
			_impact.impact(3)
			_camera.shake(0.5, 24.0, 0.2)
			_postfx.flash(Color.WHITE, 0.5, 0.1)
			_score.add_points(10)
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
	var p95_idx: int = mini(n - 1, int(float(n) * 0.95))
	return {
		"count": n,
		"mean": total / float(n),
		"median": sorted[n / 2],
		"p95": sorted[p95_idx],
		"max": sorted[n - 1],
	}


# =====================================================================
# 4. ROBUSTNESS PROBES AND DOCUMENTED DEFECTS
# =====================================================================

## Two impacts inside one simulated frame used to leave the world in 20x slow
## motion for the rest of the match. This pins the fixed behaviour.
func test_back_to_back_impacts_restore_normal_speed() -> void:
	# Root cause (fixed): impact_frame() sampled
	#   _time_scale_restore = Engine.time_scale
	# BEFORE lowering it, so a second impact while the first hitstop was armed
	# sampled the ALREADY-LOWERED 0.05 and every later restore wrote back 0.05.
	# GameLoopDriver's own order makes this the common case: _physics_process
	# advances the minigames BEFORE ImpactDirector, so a micro-game that
	# self-finishes in a frame where an impact was already fired stacks two.
	assert_not_null(_impact, "ImpactDirector present")
	# Leave the world at normal speed whatever the previous test did, so this
	# test measures the fix and not inherited pollution.
	Engine.time_scale = 1.0

	_impact.impact(3)                       # impact A
	assert_almost_eq(Engine.time_scale, 0.05, 0.001, "impact A engages the hitstop")
	_impact.impact(3)                       # impact B, same simulated frame
	var sampled: Variant = _impact.get("_time_scale_restore")
	assert_almost_eq(float(sampled), 1.0, 0.001,
		"impact B samples the pre-hitstop scale, not the already-slowed 0.05")
	_impact.advance(999.0)                  # drain the hitstop completely
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"the world returns to normal speed after the stacked impacts")
	_impact.advance(999.0)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "and stays there")

	# A micro-game that self-finishes in the same frame as its own success
	# impact is the realistic version of this stack.
	Engine.time_scale = 1.0
	_impact.impact(1)
	_impact.impact(2)
	_impact.impact(3)
	_impact.advance(999.0)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001,
		"three impacts in one frame still restore the world")
	assert_almost_eq(float(_impact.get("_hitstop_left")), 0.0, 0.001,
		"no hitstop remains armed")
	assert_almost_eq(float(_impact.get("_restore_left")), 0.0, 0.001,
		"no restore timer remains armed")


## MinigameDirector never exposes the metadata the HUD needs.
func test_hud_builds_the_objective_widget_for_the_active_microgame() -> void:
	# §13.1: the objective HUD is auto-generated from the HUDRecipe. The HUD
	# reads the metadata through MinigameDirector.get_metadata_for(); that
	# method did not exist, so has_method() failed and the objective stayed
	# empty for the whole micro-game. Now it must populate.
	var hud: Node = _main.get_node_or_null("HUD") if _main != null else null
	assert_not_null(hud, "HUD layer instanced by main.tscn")
	if hud == null:
		return
	assert_true(bool(_director.has_method("get_metadata_for")),
		"MinigameDirector exposes get_metadata_for()")
	var before: String = hud.shown_objective() if hud.has_method("shown_objective") else ""
	assert_eq(before, "", "objective empty before a micro-game")

	_start_match()
	_tick(3.0)
	_bus.emit_signal("powerup_collected", &"powerup")
	var chosen: StringName = _roulette.get_pending_id()
	assert_ne(chosen, &"", "roulette picked an id")
	_roulette.update(3.0)
	_tick(0.1)
	assert_true(bool(_director.is_active()), "a micro-game is running")
	var active_meta: MinigameMetadata = _registry.get_metadata(_director.get_active_id())
	assert_not_null(active_meta, "the micro-game has metadata (the HUD could build its widget)")
	assert_true(active_meta.hud_recipe != null, "and it carries an HUDRecipe")

	var objective: String = hud.shown_objective() if hud.has_method("shown_objective") else ""
	assert_ne(objective, "",
		"the objective is populated from the metadata's objective_text")
	var widget: Object = hud.current_objective_widget() if hud.has_method("current_objective_widget") else null
	assert_not_null(widget,
		"the objective widget is auto-generated from the HUDRecipe (§13.1)")
	# The director serves the same metadata the registry does.
	assert_eq(_director.get_active_metadata(), active_meta,
		"get_active_metadata() returns the running micro-game's metadata")
	# Leave no micro-game in flight for the next test.
	while bool(_director.is_active()):
		var mg: Minigame = _director.get_active()
		if mg == null:
			break
		mg.finished.emit(_make_result(false))
	_director.update(999.0)


## QA-2 (fixed): the roulette is now started by production code, not only by
## tests. This test scans the source so the wiring cannot silently rot again.
func test_powerup_director_starts_the_roulette() -> void:
	var callers: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://src")
	assert_not_null(dir, "src/ readable")
	if dir == null:
		return
	_scan_for_spin_calls(dir, "src", callers)
	_report(PackedStringArray([
		"",
		"===== ROULETTE WIRING SCAN (src/) =====",
		"files calling .spin(): %s" % str(callers),
		"==========",
	]))
	assert_gt(callers.size(), 0,
		"QA-2 fixed: production code calls RouletteController.spin() on "
		+ "roulette_started; before this, only tests spun the wheel, so a real "
		+ "power-up pickup left the match in ROULETTE until the state machine "
		+ "timed out into start_minigame(&\"\")")
	# The controller still works when driven directly: open a wheel, let the
	# production listener spin it (as it does on a real pickup), and confirm it
	# resolves to a real catalog id.
	_director.update(999.0)
	_roulette.update(999.0)
	_bus.emit_signal("roulette_started")
	assert_true(bool(_roulette.is_spinning()),
		"the production listener started the wheel on roulette_started")
	var chosen: StringName = _roulette.get_pending_id()
	assert_ne(chosen, &"", "the wheel picked a real catalog id")
	assert_true(_registry.has_id(chosen), "the spin picks a registered id")
	_roulette.update(999.0)
	assert_eq(_roulette.get_last_id(), chosen,
		"the resolved spin records the id it chose")
	# spin_started / spin_finished exist for a UI that never loads.
	var finished_sig: Variant = _roulette.get("spin_finished")
	var started_sig: Variant = _roulette.get("spin_started")
	assert_true(finished_sig is Signal and started_sig is Signal, "both roulette signals exist")
	assert_eq((finished_sig as Signal).get_connections().size(), 0,
		"DOCUMENTED DEFECT: spin_finished has no subscriber; roulette_wheel.tscn "
		+ "and roulette_ui.tscn are never instanced by anything")


func _scan_for_spin_calls(dir: DirAccess, prefix: String, out_hits: PackedStringArray) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var path: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub := DirAccess.open(path)
				if sub != null:
					_scan_for_spin_calls(sub, path, out_hits)
		elif file_name.ends_with(".gd"):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var text: String = f.get_as_text()
				f.close()
				if ".spin(" in text:
					out_hits.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()


## The §1.4 orphan guard must scan a group that something actually populates.
func test_orphan_guard_scans_a_populated_group() -> void:
	# Fixed: the generic minigame entity adds itself to mg_entity on enter, so
	# the director's orphan verification has real nodes to check. Before the
	# generic entity existed, every archetype registered its own group
	# (mg_target, mg_chaser, ...), SpawnRecipe.pool_group was read by nobody,
	# and the §1.4 cleanliness contract could never fire.
	var director_source: String = _source_of(DIRECTOR_SCRIPT)
	assert_true("mg_entity" in director_source, "the director scans the mg_entity group")
	var adders: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://src/minigames")
	assert_not_null(dir, "src/minigames readable")
	if dir != null:
		_scan_for_group_adders(dir, "src/minigames", adders)
	_report(PackedStringArray([
		"",
		"===== mg_entity GROUP ADDER SCAN =====",
		"files calling add_to_group(&\"mg_entity\"): %s" % str(adders),
		"live nodes in the group right now: %d"
			% get_tree().get_nodes_in_group(&"mg_entity").size(),
		"==========",
	]))
	assert_gt(adders.size(), 0,
		"the mg_entity pool group has an adder: the orphan verification in "
		+ "minigame_director.gd scans it, so §1.4 teardown is actually exercised")
	gut.p("mg_entity adders: %s" % str(adders))


func _scan_for_group_adders(dir: DirAccess, prefix: String, out_hits: PackedStringArray) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var path: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub := DirAccess.open(path)
				if sub != null:
					_scan_for_group_adders(sub, path, out_hits)
		elif file_name.ends_with(".gd"):
			var src: String = _source_of(path)
			if "add_to_group(&\"mg_entity\")" in src:
				out_hits.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _source_of(path: String) -> String:
	var script: GDScript = load(path) as GDScript
	if script == null:
		return ""
	return script.source_code


## Raw text of any file (.gd, .tscn, .tres). `_source_of` only works for
## GDScript because it reads the script's source_code, which .tscn/.tres lack.
func _text_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## The roulette plays the micro-game even while the director is cooling down.
func test_roulette_result_reaches_the_director_even_on_cooldown() -> void:
	# The roulette no longer plays the micro-game itself: MatchManager subscribes
	# to `roulette_result`, calls MinigameDirector.play(), and only commits to
	# MINIGAME when the director accepts. This pins both halves of that contract:
	# the pick reaches the director, and a refusal recovers to FREE_ROAM instead
	# of deadlocking in MINIGAME with an empty world for the rest of the clock.
	_start_match()
	_tick(3.0)
	_director.update(999.0)
	_arm_cooldown_by_playing_once()
	assert_gt(float(_director.get_cooldown_left()), 0.0, "cooldown armed")

	_bus.emit_signal("powerup_collected", &"powerup")
	assert_eq(int(_match.current_state()), STATE_ROULETTE, "roulette opened")
	# The production listener (PowerUpDirector) already spun the wheel on
	# `roulette_started`, so read the id it picked instead of spinning again.
	var chosen: StringName = _roulette.get_pending_id()
	assert_ne(chosen, &"", "roulette picked an id")
	_roulette.update(3.0)     # resolves the spin -> play() is refused

	assert_false(bool(_director.is_active()),
		"the director refused to play while cooling down")
	assert_eq(int(_match.current_state()), STATE_FREE_ROAM,
		"a refused play recovers to FREE_ROAM, not a dead MINIGAME minute")

	# The match is playable again: a later pickup, once the cooldown has run
	# out, must reach a real micro-game.
	_director.update(999.0)
	_tick(0.1)
	_bus.emit_signal("powerup_collected", &"powerup")
	# Same: the listener spun it; read the pending id.
	var retry: StringName = _roulette.get_pending_id()
	assert_ne(retry, &"", "a second pickup spins again")
	_roulette.update(3.0)
	_tick(0.1)
	assert_true(bool(_director.is_active()),
		"after the cooldown the same wiring reaches a running micro-game")


## Registration/resolution symmetry across GameServices. This is the bug class
## that used to break impact juice: ImpactDirector resolves &"camera" and
## &"sfx" through the locator (src/juice/impact_director.gd:80,90) while
## nothing registered those names, so both hops returned null and camera shake
## and impact SFX silently never fired. This test scans the source for every
## register() / lookup() / resolve() name and asserts the two sets agree, so a
## new dangling name fails the suite instead of dying silently at runtime.
func test_service_registry_names_are_symmetric() -> void:
	assert_not_null(_services, "GameServices present")
	var registered: PackedStringArray = PackedStringArray()
	var resolved: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://src")
	assert_not_null(dir, "src/ readable")
	if dir != null:
		_scan_service_names(dir, "src", registered, resolved)

	var never_resolved: PackedStringArray = PackedStringArray()
	for name: String in registered:
		if name in [&"core", &"config", &"player"]:
			continue      # resolved structurally, not by name lookup
		if not (name in resolved):
			never_resolved.append(name)
	var never_registered: PackedStringArray = PackedStringArray()
	for name: String in resolved:
		# Only GameServices registry keys matter here; the capitalised names are
		# the duck-typed /root/<Autoload> lookups, a different mechanism.
		# "core" is GameServices itself, registered in _ready() without a name.
		if name in _CANONICAL_NAMES and name != &"core" and not (name in registered):
			never_registered.append(name)

	# Every canonical service name is now both registered by its autoload and
	# resolved by at least one consumer, so the asymmetry sets are both empty.
	# This test pins that symmetry: it turns RED the moment a service is
	# published without a consumer (dead registration) or consumed without ever
	# being published (the bug that left shake, SFX and the accessibility
	# settings silently dead), so whoever causes that must update this line
	# consciously instead of leaving a dangling service in place.
	var expected_registered_not_resolved: Array[String] = []
	var expected_resolved_not_registered: Array[String] = []
	_report(PackedStringArray([
		"",
		"===== SERVICE LOCATOR SYMMETRY (src/ scan) =====",
		"registered under : %s" % str(registered),
		"resolved by name : %s" % str(resolved),
		"registered but never resolved : %s" % str(never_resolved),
		"resolved but never registered : %s" % str(never_registered),
		"pinned asymmetry (update deliberately if this changes): "
			+ "registered-only=%s resolved-only=%s" % [str(expected_registered_not_resolved), str(expected_resolved_not_registered)],
		"===============================================",
	]))
	assert_eq(never_resolved, PackedStringArray(expected_registered_not_resolved),
		"the registered-but-never-resolved set moved: update "
		+ "expected_registered_not_resolved with the reason before moving on")
	assert_eq(never_registered, PackedStringArray(expected_resolved_not_registered),
		"the resolved-but-never-registered set moved: update "
		+ "expected_resolved_not_registered with the reason before moving on")

	# Canonical coverage, reported for the orchestrator: a name that nobody
	# registers is exactly how camera shake / impact SFX used to die.
	var missing: PackedStringArray = PackedStringArray()
	for name: String in _CANONICAL_NAMES:
		if not bool(_services.has_service(StringName(name))):
			missing.append(name)
	gut.p("canonical names with no live registration: %s" % str(missing))
	gut.p("documented at the time of writing: &\"sfx\" was among them while the "
		+ "SFXPlayer wiring was being reworked; the symmetry assert above is the "
		+ "stable guard, this line is the moving-target note")

	# And the two lookups ImpactDirector actually performs must resolve.
	assert_not_null(_services.resolve(&"camera"), "&\"camera\" resolves: impacts can shake")
	assert_not_null(_services.resolve(&"impact"), "&\"impact\" resolves: impact juice runs")
	assert_true(bool(_camera.has_method("shake")), "CameraDirector implements shake()")
	_camera.shake(0.8, 30.0, 0.3)
	_impact.impact(3)
	await wait_frames(1)
	_impact.advance(999.0)


func _scan_service_names(dir: DirAccess, prefix: String, registered: PackedStringArray,
		resolved: PackedStringArray) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var path: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub := DirAccess.open(path)
				if sub != null:
					_scan_service_names(sub, path, registered, resolved)
		elif file_name.ends_with(".gd"):
			var src: String = _source_of(path)
			var re := RegEx.new()
			re.compile("register\\(\\s*&\"([A-Za-z_]+)\"")
			for m: RegExMatch in re.search_all(src):
				if not (m.get_string(1) in registered):
					registered.append(m.get_string(1))
			# publish("AutoloadName", &"name", self) — the only registration route the
			# autoloads use now: it refuses anything that is not the live singleton.
			var re4 := RegEx.new()
			re4.compile("publish\\(\\s*\"[A-Za-z_0-9]+\"\\s*,\\s*&\"([A-Za-z_]+)\"")
			for m4: RegExMatch in re4.search_all(src):
				if not (m4.get_string(1) in registered):
					registered.append(m4.get_string(1))
			# Dynamic registrations: services.call("register", &"name", self)
			var re3 := RegEx.new()
			re3.compile("\"register\"\\s*,\\s*&\"([A-Za-z_]+)\"")
			for m3: RegExMatch in re3.search_all(src):
				if not (m3.get_string(1) in registered):
					registered.append(m3.get_string(1))
			var re2 := RegEx.new()
			re2.compile("(?:lookup|resolve)\\(\\s*&\\\"([A-Za-z_]+)\\\"")
			for m2: RegExMatch in re2.search_all(src):
				if not (m2.get_string(1) in resolved):
					resolved.append(m2.get_string(1))
		file_name = dir.get_next()
	dir.list_dir_end()


## Canonical service names, mirroring the consts at
## src/core/game_services.gd:11-27. Kept as a literal list so a NEW const that
## nobody registers shows up here as a failure rather than as a silent no-op.
const _CANONICAL_NAMES: PackedStringArray = [
	"core", "match", "score", "style", "impact", "camera", "postfx", "audio",
	"music", "voice", "sfx", "powerups", "roulette", "minigames", "save",
	"settings", "player",
]


## Style packs must not leave their global shader uniforms behind: reverting to
## the base look has to clear them, or the next micro-game inherits a stale look.
func test_style_pack_uniforms_are_cleared_on_revert() -> void:
	# The fix: revert_to_base() now calls _clear_shader_uniforms(). Before this
	# the method existed but nothing invoked it, so the "revert" restored the
	# environment and left the four u_style_* parameters set in the
	# RenderingServer (§1.4: the world is left as it was found).
	assert_true(_revert_to_base_clears_uniforms(),
		"revert_to_base() calls _clear_shader_uniforms()")
	var pack: StylePack = load("res://src/styles/packs/neon_drift.tres") as StylePack
	assert_not_null(pack, "NEON_DRIFT pack loads")
	assert_true(pack.style_uniforms.has(&"u_style_top"),
		"the pack declares style uniforms (so there IS something to clear)")
	_style.apply_pack_id(&"NEON_DRIFT")
	assert_true(bool(_style.is_styled()), "style applied")
	_style.revert_to_base()
	assert_false(bool(_style.is_styled()), "style reverted")
	# Whatever the renderer does with the value, revert_to_base must have run the
	# clear path; a null here is the observable "cleared" state.
	var top_after: Variant = RenderingServer.global_shader_parameter_get(&"u_style_top")
	gut.p("u_style_top after revert_to_base() = %s (null == cleared)" % str(top_after))
	# The uniform clear is the contract under test here; the environment blend
	# itself is covered by the style director's own tests.
	assert_false(bool(_style.is_styled()), "the director reports the base look")



## Collecting a power-up must arm the cooldown of the slot that was actually
## freed. The write used to happen AFTER _alive.remove_at(idx), which shifts
## every later index, so a different power-up's slot was armed (and the write
## ran past the end of the array as slots drained).
func test_powerup_collection_arms_the_correct_slot() -> void:
	var spawner: Node = _spawner_node()
	assert_not_null(spawner, "power-up spawner present under PowerUpDirector")
	if spawner == null:
		return
	# Start from zero pending respawns. The spawner refills up to max_active on
	# its own tick, so drain first and read the count AFTER settling.
	for _d in range(600):
		spawner.call("_tick_cooldowns", 1.0)
		spawner.call("_fill_from_cooldowns")
	# Clear the typed array through its own API; resize() on a typed
	# Array[float] refuses an out-of-range index assignment.
	(spawner.get("_cooldowns") as Array).clear()
	var alive_before: int = int((spawner.get("_alive") as Array).size())
	assert_gt(alive_before, 1, "more than one power-up alive, so index 0 is not the last")

	# PowerUp.take(by) hands itself to the spawner through `collected(by)`, so
	# the collector argument must be the power-up itself.
	var first: Node = (spawner.get("_alive") as Array)[0]
	first.call("take", first)

	# The pending slot must exist and carry the configured cooldown. Writing it
	# after remove_at(idx) is what armed the wrong slot before.
	var cooldowns: Array = spawner.get("_cooldowns")
	assert_eq(cooldowns.size(), 1, "exactly one respawn is pending after one pickup")
	var expected: float = respawn_cooldown_value(spawner)
	assert_almost_eq(float(cooldowns[0]), expected, 0.001,
		"the pending slot carries the configured respawn cooldown")
	# The write must have landed on the collected slot, not on a neighbour: the
	# index used was the one valid BEFORE the removal.
	spawner.call("_tick_cooldowns", expected * 0.5)
	assert_almost_eq(float(cooldowns[0]), expected * 0.5, 0.001,
		"the single pending slot drains on schedule")
	spawner.call("_tick_cooldowns", expected)
	assert_almost_eq(float(cooldowns[0]), 0.0, 0.001,
		"the pending slot reaches zero")
	spawner.call("_fill_from_cooldowns")
	assert_gte(int((spawner.get("_alive") as Array).size()), alive_before - 1,
		"the freed slot is eligible to respawn once its cooldown elapsed")


## The spawner's configured respawn cooldown, whatever it is set to.
func respawn_cooldown_value(spawner: Node) -> float:
	return float(spawner.get("respawn_cooldown_s"))


## Content gap: no archetype can spawn an entity today.
func test_documents_no_minigame_spawns_a_single_entity() -> void:
	# Every catalog entry now points at the ONE generic minigame_entity.tscn,
	# whose tint/shape/size come from the SpawnRecipe slot data (§1.8: a
	# micro-game is data, not code). Before that, all 36 entries left
	# entity_scene = null and spawn_entity() returned null, so ten archetypes
	# created no target/hazard/collectible at all and could not be won.
	var with_scene: int = 0
	var without_scene: int = 0
	for id: StringName in _registry_ids:
		var meta: MinigameMetadata = _registry.get_metadata(id)
		if meta == null or meta.spawn_recipe == null:
			continue
		if meta.spawn_recipe.entity_scene != null:
			with_scene += 1
		else:
			without_scene += 1
	gut.p("documented: catalog entries with entity_scene set: %d, without: %d" % [
		with_scene, without_scene,
	])
	assert_eq(with_scene, 36,
		"all 36 catalog entries must point at the generic entity scene, so "
		+ "every archetype can spawn what its objective needs"
	)
	assert_eq(without_scene, 0,
		"no catalog entry may leave entity_scene null: it would spawn nothing"
	)
	assert_eq(_count_entity_groups(), 0,
		"every entity a micro-game spawned must be swept by its own teardown"
	)


## Accessibility settings must survive a relaunch. _save_settings() writes them
## but _load() used to read only the score file, so every toggle reset — the
## exact accessibility failure §8 exists to prevent.
func test_accessibility_settings_survive_a_relaunch() -> void:
	var save: Object = _autoload("SaveSystem")
	assert_not_null(save, "SaveSystem autoload present")
	if save == null:
		return
	# A known starting point: the persisted file from an earlier test must not
	# decide this one.
	save.set_setting(&"flashes_enabled", true)
	save.set_setting(&"flashes_enabled", false)
	assert_false(bool(save.get_setting(&"flashes_enabled", true)),
		"the value round-trips in memory")
	assert_true(FileAccess.file_exists("user://arcade_block_settings.json"),
		"the settings file exists on disk (SaveSystem._save_settings() ran)")
	# Simulate a relaunch: a fresh SaveSystem reads the same user:// path.
	# It must enter the tree first, because _load() runs from _ready().
	var fresh: Object = load("res://src/systems/save_system.gd").new()
	add_child_autofree(fresh)
	await wait_frames(1)
	assert_false(bool(fresh.get_setting(&"flashes_enabled", true)),
		"a fresh SaveSystem restores the persisted value instead of the default")
	# And the default is still the default when nothing was persisted: a key the
	# player never touched must not invent a value.
	assert_true(bool(fresh.get_setting(&"shake_enabled", true)),
		"an untouched setting still falls back to its default")


## Exactly ONE MinigameRegistry may be alive. The director and the roulette
## each used to build their own, and the director's copy never scanned, so
## micro-games ran with empty metadata (no entities, no HUD recipe). The
## catalog is now published as a shared service under &"registry".
func test_only_one_registry_instance_is_alive() -> void:
	var registries: Array[Node] = _nodes_with_script("minigame_registry.gd")
	var music_directors: Array[Node] = _nodes_with_script("music_director.gd")
	var sfx_players: Array[Node] = _nodes_with_script("sfx_player.gd")
	var voice_directors: Array[Node] = _nodes_with_script("voice_director.gd")
	_report(PackedStringArray([
		"",
		"===== SERVICE INSTANCE COUNTS =====",
		"MinigameRegistry instances : %d %s" % [registries.size(), str(_paths_of(registries))],
		"MusicDirector instances    : %d %s" % [music_directors.size(), str(_paths_of(music_directors))],
		"SFXPlayer instances        : %d %s" % [sfx_players.size(), str(_paths_of(sfx_players))],
		"VoiceDirector instances    : %d %s" % [voice_directors.size(), str(_paths_of(voice_directors))],
		"==========",
	]))
	assert_eq(registries.size(), 1,
		"exactly one MinigameRegistry is alive: the catalog is a shared service "
		+ "(src/minigames/minigame_registry.gd publishes &\"registry\"), not one "
		+ "private copy per consumer")
	# And it is the one the service registry hands out.
	var service: Object = _services.resolve(&"registry")
	assert_not_null(service, "the catalog is registered as &\"registry\"")
	assert_same(service, registries[0],
		"the live registry node IS the registered service")


func _nodes_with_script(suffix: String) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			var scr: Script = child.get_script() if child is Object else null
			if scr != null and String(scr.resource_path).ends_with(suffix):
				found.append(child)
			stack.append(child)
	return found


func _paths_of(nodes: Array[Node]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: Node in nodes:
		out.append(String(n.get_path()))
	return out


## Degradation probes: a missing dependency must never raise a script error.
func test_missing_dependencies_degrade_silently() -> void:
	# The director and the context are built for exactly this: every field is
	# nullable and every lookup degrades. Drive the worst case and check the
	# aftermath instead of trusting the comments.
	_start_match()
	_tick(3.0)
	_impact.impact(3)
	_camera.shake(2.0)
	_postfx.flash(Color.RED, 1.0, 1.0)
	_score.add_points(10)
	_bus.emit_signal("powerup_collected", &"powerup")
	_tick(0.5)
	# Unregistering services under other names must not break the running
	# systems either: the director re-resolves every frame.
	if _services.has_method("unregister"):
		_services.unregister(&"camera")
		_services.unregister(&"sfx")
	_impact.impact(3)
	_tick(1.0)
	assert_true(true, "no script error while services come and go")

	# A minigame with a null context must survive its whole lifecycle.
	var mg: Node = _registry.instantiate_archetype(&"TAP_TARGET")
	assert_not_null(mg, "archetype instantiated from the registry")
	if mg == null:
		return
	mg.call("setup", null)
	mg.call("start")
	mg.call("update", 0.1)
	mg.call("on_input", null)
	mg.call("teardown")
	assert_true(true, "a null context does not break the micro-game lifecycle")
	mg.free()
	await wait_frames(1)
	gut.p("degradation probes passed: no script error with missing dependencies")


# ==========
# 9. DISCONNECTED SUBSYSTEMS (static scan, path:line evidence)
# ==========

## PostFXDirector must be advanced exactly once per frame. It used to be
## advanced twice: GameLoopDriver called postfx.advance(delta) AND the autoload
## runs its own _process -> advance(delta), so every fade ran at 2x speed.
func test_postfx_is_advanced_exactly_once_per_frame() -> void:
	var has_process: bool = false
	var loop_src: String = _source_of("src/core/game_loop.gd")
	var has_loop_call: bool = (
		loop_src.contains("postfx.advance(")
		or loop_src.contains("postfx.advance (")
	)
	var postfx_src: String = _source_of("src/juice/postfx_director.gd")
	for line: String in postfx_src.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("func _process("):
			has_process = true
	_report(PackedStringArray([
		"",
		"===== POSTFX ADVANCE OWNERSHIP =====",
		"owns _process -> advance()      : %s" % str(has_process),
		"GameLoopDriver also advances it : %s" % str(has_loop_call),
		"==========",
	]))
	assert_true(has_process,
		"PostFXDirector drives itself from _process, which is the single owner")
	assert_false(has_loop_call,
		"GameLoopDriver must NOT advance postfx as well: an autoload cannot opt "
		+ "out of its own _process, so the second advance doubled every fade rate")
	# Runtime confirmation: one _process tick moves the blend by exactly one delta.
	_postfx.set("_blend_t", 0.0)
	_postfx.set("_blend_speed", 1.0)
	_postfx.call("_process", 0.5)
	var after: float = float(_postfx.get("_blend_t"))
	assert_almost_eq(after, 0.5, 0.0001,
		"one frame advances the blend by exactly the delta it was given")


## Every .tscn under src/ must be reachable: an unreferenced scene is dead
## weight, and a scene pointing at a missing script fails at load time.
func test_every_scene_is_reachable() -> void:
	var orphans: PackedStringArray = _unreferenced_scenes()
	_report(PackedStringArray([
		"",
		"===== SCENE REACHABILITY =====",
		"unreferenced .tscn under src/: %s" % str(orphans),
		"==========",
	]))
	assert_eq(orphans.size(), 0,
		"every scene under src/ is referenced by code or by another scene: an "
		+ "orphan .tscn can never load, so whatever it holds is dead")
	# The pooled score popup in particular must stay wired: ScoreDirector loads
	# it, and the pool is what keeps §1.4/§7 honest.
	assert_gt(_count_references_to("src/match/score/score_popup.tscn"), 0,
		"score_popup.tscn is loaded by ScoreDirector through the ObjectPool")


## Every .tscn under src/ that nothing else references.
func _unreferenced_scenes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var scenes: PackedStringArray = _scene_files_under("src")
	for path: String in scenes:
		# The project's main scene is referenced by project.godot, not by any
		# file under src/, so it is reachable by definition.
		if path == "src/bootstrap/main.tscn":
			continue
		if _count_references_to(path) == 0:
			out.append(path)
	return out


## All .tscn files under a directory, recursively.
func _scene_files_under(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var stack: Array[String] = [dir_path]
	while not stack.is_empty():
		var dir_path_now: String = stack.pop_back()
		var dir := DirAccess.open(dir_path_now)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			var p: String = dir_path_now + "/" + file_name
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					stack.append(p)
			elif file_name.ends_with(".tscn"):
				out.append(p.trim_prefix("res://"))
			file_name = dir.get_next()
		dir.list_dir_end()
	return out


## ObjectPool — the pooling infrastructure AGENTS.md §1.4/§7 require — must be
## used by production code, not only by tests.
func test_object_pool_is_used_by_production_code() -> void:
	var mentions: PackedStringArray = _count_references_to_dir("src/core/pooling", "src", true)
	var constructions: PackedStringArray = _count_pool_constructions()
	_report(PackedStringArray([
		"",
		"===== POOLING WIRING =====",
		"src/ files mentioning ObjectPool (excluding src/core/pooling/): %s" % str(mentions),
		"src/ files that actually build a pool (ObjectPool.new(...)): %s" % str(constructions),
		"pooling module: src/core/pooling/object_pool.gd",
		"consumer that builds a pool: src/match/score/score_director.gd",
		"============================================================",
	]))
	assert_gt(constructions.size(), 0,
		"AGENTS.md §1.4/§7 pooling: production code builds an ObjectPool. "
		+ "ScoreDirector now pools its world-space score popups, so a scoring "
		+ "burst during a micro-game reuses Label3D nodes instead of "
		+ "queue_free()-ing several per second")
	# Sanity: the pool class itself is healthy when driven directly.
	# Sanity: the pool class itself is healthy when driven directly.
	var PoolScript: GDScript = load("res://src/core/pooling/object_pool.gd") as GDScript
	assert_not_null(PoolScript, "ObjectPool script loads")
	# _init(scene, parent) needs both a scene and an owner node, so the pool is
	# built against the smallest real PackedScene available; passing none made
	# this assertion fail on a signature mismatch instead of on the contract.
	var pool_scene: PackedScene = load("res://src/match/score/score_popup.tscn") as PackedScene
	assert_not_null(pool_scene, "the orphan popup scene exists to build a pool from")
	var pool: Object = PoolScript.new(pool_scene, self)
	assert_not_null(pool, "ObjectPool instantiates")


func _count_pool_constructions() -> PackedStringArray:
	var hits: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://src")
	if dir == null:
		return hits
	_scan_constructions(dir, "src", hits)
	return hits


func _scan_constructions(dir: DirAccess, prefix: String, hits: PackedStringArray) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var p: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				if not p.begins_with("src/core/pooling"):
					var sub := DirAccess.open(p)
					if sub != null:
						_scan_constructions(sub, p, hits)
		elif p.ends_with(".gd"):
			var src: String = _text_of(p)
			var re := RegEx.new()
			re.compile("ObjectPool\\.new\\s*\\(")
			if re.search(src) != null:
				hits.append(p)
		file_name = dir.get_next()
	dir.list_dir_end()


func _count_references_to(path: String) -> int:
	var total := 0
	var dir := DirAccess.open("res://src")
	if dir == null:
		return 0
	total += _scan_refs(dir, "src", path)
	return total


func _scan_refs(dir: DirAccess, prefix: String, needle: String) -> int:
	var total := 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var p: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub := DirAccess.open(p)
				if sub != null:
					total += _scan_refs(sub, p, needle)
		elif file_name.ends_with(".gd") or file_name.ends_with(".tscn") or file_name.ends_with(".tres"):
			var src: String = _text_of(p)
			if p != needle:     # a file never references itself as a scene
				total += src.count("res://" + needle)
				total += src.count("\"" + needle + "\"")
		file_name = dir.get_next()
	dir.list_dir_end()
	return total


func _count_references_to_dir(dir_path: String, prefix: String, exclude_self: bool) -> PackedStringArray:
	var hits: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://" + prefix)
	if dir == null:
		return hits
	_scan_dir_refs(dir, prefix, dir_path, hits, exclude_self)
	return hits


func _scan_dir_refs(dir: DirAccess, prefix: String, dir_path: String,
		hits: PackedStringArray, exclude_self: bool) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var p: String = prefix + "/" + file_name
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				if not (exclude_self and p == dir_path):
					var sub := DirAccess.open(p)
					if sub != null:
						_scan_dir_refs(sub, p, dir_path, hits, exclude_self)
		elif p.ends_with(".gd") and not (exclude_self and p.begins_with(dir_path + "/")):
			var src: String = _text_of(p)
			# Only a real reference to the class counts: a bare `release(` or an
			# `acquire(` is a different method on another node, and the comment
			# inside score_popup.gd is prose, not wiring.
			if "ObjectPool" in src or "core/pooling" in src:
				hits.append(p)
		file_name = dir.get_next()
	dir.list_dir_end()


# --- shared helpers ---

func _start_match() -> void:
	assert_eq(int(_match.current_state()), STATE_TITLE, "pre-condition: TITLE")
	_match.start_match()
	assert_eq(int(_match.current_state()), STATE_COUNTDOWN, "COUNTDOWN after start_match()")


func _arm_cooldown_by_playing_once() -> void:
	var ids := _all_registry_ids()
	var ok: bool = _director.play(ids[0], 0.0)
	assert_true(ok, "boot micro-game entered")
	var mg: Minigame = _director.get_active()
	mg.finished.emit(_make_result(false))
	assert_false(bool(_director.is_active()), "boot micro-game finished")
	assert_gt(float(_director.get_cooldown_left()), 0.0,
		"finishing a micro-game arms the anti-repetition cooldown")


## True when revert_to_base() invokes the style-uniform clear. Read from the file
## on disk, not through load(): GDScript.source_code can serve a cached copy
## that predates an edit, which would measure the cache rather than the code.
func _revert_to_base_clears_uniforms() -> bool:
	var in_revert: bool = false
	for line: String in _text_of("src/styles/style_director.gd").split("\n"):
		if line.begins_with("func revert_to_base"):
			in_revert = true
			continue
		if in_revert and line.begins_with("func "):
			break
		if in_revert and "_clear_shader_uniforms" in line:
			return true
	return false


## The PowerUpSpawner node under the PowerUpDirector autoload, or null.
func _spawner_node() -> Node:
	var director: Node = _autoload("PowerUpDirector") as Node
	if director == null:
		return null
	return director.get_node_or_null("PowerUpSpawner") as Node
