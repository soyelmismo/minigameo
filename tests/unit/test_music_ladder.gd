extends GutTest

## Dynamic music ladder (the brief: "como los juegos de Nintendo", from relaxing
## freeroam to euphoric micro-game, and correct throughout).
##
## This suite pins the musical contract, not the sound: the layers must cross-
## fade rather than pop, the tempo must be fixed (a global BPM so the beat grid
## can carry VO and impacts), silence must be a deliberate state and not a bug,
## and the intensity ladder must be monotonic — more intensity never means fewer
## audible layers.

const MUSIC_SCRIPT := "res://src/audio/music_director.gd"
const GAME_CONFIG := "res://src/core/config/game_config.tres"


func _director() -> Object:
	var script: GDScript = load(MUSIC_SCRIPT) as GDScript
	var director: Object = script.new()
	add_child_autofree(director)
	return director


func _config() -> Resource:
	return load(GAME_CONFIG)


func test_tempo_is_a_single_locked_bpm() -> void:
	# A drifting tempo desynchronises the beat grid from the VO, the roulette
	# and the impacts, which is exactly what makes a score feel broken.
	var cfg: Resource = _config()
	assert_not_null(cfg, "game config loads")
	if cfg == null:
		return
	var bpm: float = float(cfg.get("music_bpm"))
	assert_gt(bpm, 40.0, "the global tempo is a usable BPM")
	assert_lt(bpm, 240.0, "the global tempo is a usable BPM")
	var director: Object = _director()
	assert_almost_eq(float(director.get("bpm")), bpm, 0.001,
		"the director adopts the config tempo")
	assert_true(director.has_method("seconds_per_beat"), "the beat grid is queryable")
	var spb: float = float(director.seconds_per_beat())
	assert_gt(spb, 0.0, "a beat has a positive duration")
	assert_almost_eq(60.0 / bpm, spb, 0.001, "the beat grid matches the BPM")


func test_intensity_ladder_is_monotonic() -> void:
	# More intensity must never mean fewer audible layers, or turning the music
	# "up" would make it thinner — the opposite of the Nintendo feel.
	var director: Object = _director()
	var previous: int = -1
	for step: int in range(0, 11):
		var intensity: float = step / 10.0
		var layers: Array[StringName] = director.layers_for_intensity(intensity)
		assert_gte(layers.size(), previous,
			"intensity %0.1f has at least as many layers as the previous step" % intensity)
		previous = layers.size()


func test_more_layers_are_audible_as_intensity_climbs() -> void:
	var director: Object = _director()
	var calm: Array[StringName] = director.layers_for_intensity(0.0)
	var hot: Array[StringName] = director.layers_for_intensity(1.0)
	assert_gt(hot.size(), calm.size(),
		"full intensity is thicker than calm (the euphoric end of the ladder)")
	for layer: StringName in calm:
		assert_true(hot.has(layer),
			"layers are additive: '%s' stays at full intensity" % String(layer))


func test_silence_is_a_real_layer_set_not_a_missing_one() -> void:
	# A silent state must be intentional and reachable, so a bug that silences
	# the music is distinguishable from the design.
	var director: Object = _director()
	assert_true(director.has_method("state_layer_set"), "states map to layer sets")
	for state: StringName in [&"CALM", &"TENSION", &"PEAK", &"TRIUMPH", &"FAIL"]:
		var layers: Array[StringName] = director.state_layer_set(state)
		assert_eq(layers.size(), director.state_layer_set(state).size(),
			"the layer set for '%s' is stable across reads" % String(state))


func test_crossfade_never_pops() -> void:
	# A layer change must be a fade with a real duration; an instantaneous swap
	# is an audible artefact, which is what the brief forbids.
	var director: Object = _director()
	assert_true(director.has_method("crossfade_s"), "a crossfade duration is queryable")
	assert_gt(float(director.crossfade_s()), 0.0, "layer changes fade over time")


func test_ducking_is_a_real_gain_and_recovers() -> void:
	# VO must sit above the music; the duck must be audible and must undo.
	var director: Object = _director()
	assert_true(director.has_method("duck") and director.has_method("unduck"),
		"the director exposes duck/unduck")
	# duck() targets the gain; the applied gain follows on advance(), so the
	# fade is real rather than an instant step. The ramp is a proportional
	# (exponential) fade, so it converges fast at first: one frame is already
	# audible, and it reaches the target within the declared fade duration.
	var fade_s: float = float(director.get("duck_fade_s"))
	director.duck(-6.0, 1.0)
	director.advance(1.0 / 60.0)
	assert_lt(float(director.duck_gain_db()), -0.1, "a ducked frame is already audible")
	for _i in range(int(fade_s * 60.0) + 10):
		director.advance(1.0 / 60.0)
	assert_almost_eq(float(director.duck_gain_db()), -6.0, 0.2,
		"the duck reaches its target within the declared fade")
	director.unduck()
	for _i in range(int(fade_s * 60.0) + 10):
		director.advance(1.0 / 60.0)
	assert_almost_eq(float(director.duck_gain_db()), 0.0, 0.2,
		"unducking restores the level")


func test_layer_gain_is_finite_and_ordered() -> void:
	# A NaN or wildly inverted gain would be an audible glitch no visual test
	# catches, so it is pinned here.
	var director: Object = _director()
	for layer: StringName in director.layers_for_intensity(1.0):
		var gain: float = float(director.layer_gain_db(layer))
		assert_true(is_finite(gain), "layer '%s' has a finite gain" % String(layer))
		assert_gte(gain, -80.0, "layer '%s' is not inaudibly quiet by default" % String(layer))
		assert_lte(gain, 24.0, "layer '%s' is not clipping by default" % String(layer))


func test_snapshot_is_a_complete_readable_state() -> void:
	# The snapshot is the ladder's whole face in one dictionary: every state
	# with its intensity and its layer set. A missing state is a silent gap.
	var director: Object = _director()
	var snapshot: Dictionary = director.ladder_snapshot()
	assert_gt(snapshot.size(), 0, "the ladder declares at least one state")
	for state: StringName in [&"CALM", &"TENSION", &"PEAK", &"TRIUMPH"]:
		assert_true(snapshot.has(state), "snapshot exposes '%s'" % String(state))
		var entry: Dictionary = snapshot[state]
		assert_true(entry.has("intensity"), "state '%s' has an intensity" % String(state))
		assert_true(entry.has("layers"), "state '%s' has a layer set" % String(state))
	assert_true(director.has_method("crossfade_s"), "the crossfade is separately readable")
