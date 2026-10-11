extends GutTest
## Core infrastructure tests: EventBus, GameServices, SeededRNG, ObjectPool.

# --- EventBus ---------------------------------------------------------------

func test_event_bus_has_canonical_signals() -> void:
	var bus: Node = load("res://src/core/event_bus.gd").new()
	add_child_autofree(bus)
	for sig in [
		"powerup_collected", "roulette_started", "roulette_result",
		"minigame_started", "minigame_finished", "style_applied",
		"style_reverted", "score_changed", "combo_changed",
		"impact_requested", "match_time_up", "match_started",
		"match_reset", "player_state_changed", "voice_requested",
	]:
		assert_true(bus.has_signal(sig), "EventBus must expose signal '%s'" % sig)
	bus.free()


func test_event_bus_signal_delivery() -> void:
	var bus: Node = load("res://src/core/event_bus.gd").new()
	add_child_autofree(bus)
	var received: Array = []
	bus.score_changed.connect(func(total: int, delta: int) -> void:
		received.append([total, delta]))
	bus.score_changed.emit(1500, 250)
	assert_eq(received.size(), 1, "signal delivered exactly once")
	assert_eq(received[0][0], 1500)
	assert_eq(received[0][1], 250)


# --- GameServices -----------------------------------------------------------

func test_service_locator_register_and_get() -> void:
	var locator: Node = load("res://src/core/game_services.gd").new()
	add_child_autofree(locator)
	var dummy := Node.new()
	locator.register(&"match", dummy)
	assert_eq(locator.resolve(&"match"), dummy, "registered service resolves")
	assert_null(locator.resolve(&"missing"), "unknown service resolves to null")
	assert_false(locator.has_service(&"missing"))
	assert_true(locator.has_service(&"match"))
	dummy.free()


func test_service_locator_rejects_null() -> void:
	var locator: Node = load("res://src/core/game_services.gd").new()
	add_child_autofree(locator)
	locator.register(&"broken", null)
	assert_false(locator.has_service(&"broken"), "null registrations are refused")


# --- SeededRNG --------------------------------------------------------------

func test_rng_determinism_same_seed() -> void:
	var a: Node = load("res://src/core/rng/seeded_rng.gd").new()
	var b: Node = load("res://src/core/rng/seeded_rng.gd").new()
	a.seed(4242)
	b.seed(4242)
	for _i in 20:
		assert_almost_eq(a.randf(), b.randf(), 0.0001,
			"same seed must produce the same randf sequence")
	a.free()
	b.free()


func test_rng_different_seeds_diverge() -> void:
	var a: Node = load("res://src/core/rng/seeded_rng.gd").new()
	var b: Node = load("res://src/core/rng/seeded_rng.gd").new()
	a.seed(1)
	b.seed(999999)
	var diverged := false
	for _i in 20:
		if not is_equal_approx(a.randf(), b.randf()):
			diverged = true
	assert_true(diverged, "different seeds must diverge")
	a.free()
	b.free()


func test_rng_state_replay() -> void:
	var rng: Node = load("res://src/core/rng/seeded_rng.gd").new()
	rng.seed(77)
	for _i in 10:
		rng.randf()
	var snapshot: int = rng.dump_state()
	var expected: Array = []
	for _i in 5:
		expected.append(rng.randf())
	rng.load_state(snapshot)
	for i in 5:
		assert_almost_eq(rng.randf(), expected[i], 0.0001,
			"load_state must replay the exact sequence")
	rng.free()


func test_rng_randi_range_bounds() -> void:
	var rng: Node = load("res://src/core/rng/seeded_rng.gd").new()
	rng.seed(5)
	for _i in 200:
		var v: int = rng.randi_range(3, 9)
		assert_true(v >= 3 and v <= 9, "randi_range out of bounds: %d" % v)
	rng.free()


func test_rng_weighted_pick_is_deterministic() -> void:
	var rng: Node = load("res://src/core/rng/seeded_rng.gd").new()
	var items := [&"a", &"b", &"c"]
	var weights: Array[float] = [1.0, 2.0, 7.0]
	rng.seed(31337)
	var first: StringName = rng.pick_weighted(items, weights)
	rng.seed(31337)
	var second: StringName = rng.pick_weighted(items, weights)
	assert_eq(first, second, "weighted pick must be seed-reproducible")


func test_rng_weighted_pick_favors_heavy_items() -> void:
	# Statistical sanity: over many picks the heaviest item must dominate
	# and every item must appear. (Rejection sampling, unbiased.)
	var rng: Node = load("res://src/core/rng/seeded_rng.gd").new()
	var items := [&"a", &"b", &"c"]
	var weights: Array[float] = [1.0, 2.0, 7.0]
	rng.seed(24680)
	var counts := {&"a": 0, &"b": 0, &"c": 0}
	var n := 3000
	for _i in n:
		var pick: StringName = rng.pick_weighted(items, weights)
		counts[pick] = int(counts[pick]) + 1
	assert_gt(int(counts[&"c"]), int(counts[&"b"]), "heaviest beats middle")
	assert_gt(int(counts[&"b"]), int(counts[&"a"]), "middle beats lightest")
	assert_gt(int(counts[&"a"]), 0, "lightest still appears (unbiased)")
	rng.free()


# --- ObjectPool -------------------------------------------------------------

func test_pool_acquire_release_reuse() -> void:
	var scene := PackedScene.new()
	var root := Node.new()
	var proto := Node.new()
	proto.name = "Pooled"
	scene.pack(proto)
	proto.free()
	var parent := Node.new()
	add_child_autofree(parent)
	var pool: RefCounted = load("res://src/core/pooling/object_pool.gd").new(scene, parent, 4, false)
	var n1: Node = pool.acquire()
	assert_not_null(n1, "first acquire instantiates")
	assert_eq(pool.live_count(), 1)
	pool.release(n1)
	assert_eq(pool.live_count(), 0)
	assert_eq(pool.idle_count(), 1)
	var n2: Node = pool.acquire()
	assert_eq(n1, n2, "released instance must be reused, not re-instantiated")
	pool.clear()
	parent.free()


func test_pool_max_size_without_growth() -> void:
	var scene := PackedScene.new()
	var proto := Node.new()
	scene.pack(proto)
	proto.free()
	var parent := Node.new()
	add_child_autofree(parent)
	var pool: RefCounted = load("res://src/core/pooling/object_pool.gd").new(scene, parent, 2, false)
	var a: Node = pool.acquire()
	var b: Node = pool.acquire()
	assert_not_null(a)
	assert_not_null(b)
	assert_null(pool.acquire(), "pool at max must refuse to grow")
	pool.clear()
	parent.free()
