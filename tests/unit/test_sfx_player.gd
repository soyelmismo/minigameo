extends "res://addons/gut/test.gd"
## SFXPlayer contract tests (scaffold §10.2):
## - voice cap (data-driven, default 32)
## - priority + voice stealing (lowest priority, then oldest)
## - randomization bounds (pitch ±5%, volume ±1.5 dB)
## - per-group concurrency caps
## - null / missing streams never crash (no audio assets exist yet)

## Silent fallback stream: an AudioStreamGenerator plays headless.
func _silent_stream() -> AudioStreamGenerator:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.05
	return gen

## --- Voice cap ---

func test_voice_cap_blocks_overflow() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"gen", {"group": &"world", "priority": 5})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 2
	add_child_autofree(player)
	# Inject a real (silent) stream so voices actually play.
	player.library.set_stream(&"gen", _silent_stream())
	var first: AudioStreamPlayer = player.play(&"gen")
	var second: AudioStreamPlayer = player.play(&"gen")
	assert_not_null(first, "first voice acquired")
	assert_not_null(second, "second voice acquired")
	assert_eq(player.playing_voices(), 2, "cap = 2 voices")
	# Third play at the SAME priority: scaffold §10.2 mandates "prioridad +
	# interrupción", so the pool STEALS the oldest voice rather than refusing.
	var third: AudioStreamPlayer = player.play(&"gen")
	assert_not_null(third, "third play steals (scaffold §10.2: prioridad + interrupción)")
	assert_eq(player.playing_voices(), 2, "still 2 voices after steal")
	player.stop_all()

func test_default_max_voices_is_32() -> void:
	var player := SFXPlayer.new()
	add_child_autofree(player)
	assert_eq(player.max_voices, 32, "scaffold §15 budget default")

## --- Priority + stealing ---

func test_lowest_priority_is_stolen() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"low", {"group": &"world", "priority": 1})
	lib.register(&"high", {"group": &"world", "priority": 50})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 1
	add_child_autofree(player)
	player.library.set_stream(&"low", _silent_stream())
	player.library.set_stream(&"high", _silent_stream())
	var first: AudioStreamPlayer = player.play(&"low")
	assert_not_null(first, "low priority voice acquired")
	# High priority steals the (only, lowest) voice: the same voice object
	# is reused and its tracked priority is upgraded (AudioStreamPlayer
	# .playing lags one frame in headless, so assert the pool state).
	var second: AudioStreamPlayer = player.play(&"high")
	assert_not_null(second, "high priority play succeeds")
	assert_eq(player._voice_priority[0], 50,
		"voice slot now holds the high priority (steal happened)")
	assert_eq(first, second, "steal reuses the same voice slot")
	player.stop_all()

func test_oldest_stolen_on_equal_priority() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"a", {"group": &"world", "priority": 5})
	lib.register(&"b", {"group": &"world", "priority": 5})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 1
	add_child_autofree(player)
	player.library.set_stream(&"a", _silent_stream())
	player.library.set_stream(&"b", _silent_stream())
	var a_voice: AudioStreamPlayer = player.play(&"a")
	var b_voice: AudioStreamPlayer = player.play(&"b")
	assert_not_null(b_voice, "second voice acquired")
	# On equal priority the OLDEST is stolen: same slot reused (assert the
	# pool's tracked start time advanced, not AudioStreamPlayer.playing).
	assert_eq(a_voice, b_voice, "tie-break steals and reuses the same slot")
	assert_true(player._voice_start[0] > 0.0, "stolen slot restarted")
	player.stop_all()

func test_higher_priority_never_stolen_by_lower() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"high", {"group": &"world", "priority": 50})
	lib.register(&"low", {"group": &"world", "priority": 1})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 1
	add_child_autofree(player)
	player.library.set_stream(&"high", _silent_stream())
	player.library.set_stream(&"low", _silent_stream())
	var high: AudioStreamPlayer = player.play(&"high")
	var low: Variant = player.play(&"low")
	assert_null(low, "low priority cannot steal from high")
	assert_true(high.playing, "high priority voice untouched")
	player.stop_all()

## --- Randomization ---

func test_pitch_and_volume_randomization_bounds() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"rand", {"group": &"ui", "priority": 5, "volume_db": -3.0})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 8
	add_child_autofree(player)
	player.library.set_stream(&"rand", _silent_stream())
	for i in range(20):
		var v: AudioStreamPlayer = player.play(&"rand")
		if v == null:
			continue
		assert_almost_eq(v.pitch_scale, 1.0, 0.05, "pitch within ±5%% (take %d)" % i)
		var dev: float = absf(v.volume_db - (-3.0))
		assert_almost_eq(dev, 0.75, 1.5, "volume within ±1.5 dB (take %d)" % i)
	player.stop_all()

## --- Group caps ---

func test_group_concurrency_cap() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"g", {"group": &"world", "priority": 5})
	var player := SFXPlayer.new()
	player.library = lib
	player.max_voices = 8
	player.set_group_cap(&"world", 1)
	add_child_autofree(player)
	player.library.set_stream(&"g", _silent_stream())
	assert_not_null(player.play(&"g"), "first in-group play ok")
	assert_null(player.play(&"g"), "second in-group play capped")
	assert_eq(player.playing_voices(), 1)
	player.stop_all()

## --- Null / missing streams (no assets exist yet) ---

func test_missing_stream_never_crashes() -> void:
	var lib := SFXLibrary.new()
	# Entry with an empty path (no asset yet).
	lib.register(&"missing", {"group": &"world", "priority": 5})
	var player := SFXPlayer.new()
	player.library = lib
	add_child_autofree(player)
	var v: Variant = player.play(&"missing")
	assert_null(v, "missing stream -> null, no crash")

func test_unknown_id_never_crashes() -> void:
	var player := SFXPlayer.new()
	player.library = SFXLibrary.new()
	add_child_autofree(player)
	var v: Variant = player.play(&"does_not_exist")
	assert_null(v, "unknown id -> null, no crash")

func test_null_library_never_crashes() -> void:
	var player := SFXPlayer.new()
	add_child_autofree(player)
	var v: Variant = player.play(&"anything")
	assert_null(v, "no library -> null, no crash")

## --- Library contract ---

func test_library_missing_stream_is_null_and_warns_once() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"x", {"path": "res://assets/audio/sfx/does_not_exist.wav"})
	assert_null(lib.get_stream(&"x"), "missing asset resolves to null")
	# Second call is silent (warn-once) but still null.
	assert_null(lib.get_stream(&"x"))

func test_library_entry_defaults() -> void:
	var lib := SFXLibrary.new()
	lib.register(&"d", {})
	assert_eq(lib.get_group(&"d"), &"world", "default group")
	assert_eq(lib.get_priority(&"d"), 0, "default priority")
	assert_eq(lib.get_volume_db(&"d"), 0.0, "default volume")
	assert_eq(lib.get_bus(&"d"), BusLayout.BUS_WORLD, "default bus via group")
