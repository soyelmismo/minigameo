extends GutTest
## Announcer wiring (scaffold §6.10, §5): match events must actually reach the
## voice-over, the announcer must not spam, and the mapping must live with the
## cooldown/priority policy that throttles it.

const VOICE_SCRIPT := "res://src/audio/voice_director.gd"
const VOICE_LINES_SCRIPT := "res://src/audio/voice_lines.gd"


func _make_voice() -> Object:
	var voice: Object = load(VOICE_SCRIPT).new()
	add_child_autofree(voice)
	voice.setup(load(VOICE_LINES_SCRIPT).new())
	# Deterministic clock: 10 s steps keep cooldowns honest.
	voice.set_clock_msec(0.0)
	# Detach the shared autoload so a queue_length() assertion measures THIS
	# director only. The autoload subscribes to the same EventBus, so every
	# emitted event enqueues a line on it as well and inflates the count.
	var autoload: Object = _autoload(&"VoiceDirector")
	if autoload != null and autoload.has_method("disconnect_match_events"):
		autoload.disconnect_match_events()
	return voice


func test_match_events_request_voice_lines() -> void:
	var voice := _make_voice()
	voice.connect_match_events()

	# match_start has the top priority, so it speaks immediately.
	EventBus.emit(&"match_started")
	assert_eq(String(voice.current_event()), String(VoiceLines.EV_MATCH_START),
		"match_started announces")

	# roulette_spin is lower priority: while the start line is on the air it
	# queues behind it instead of interrupting (the §6.10 policy).
	EventBus.emit(&"roulette_started")
	assert_eq(voice.queue_length(), 1,
		"a lower priority line waits behind the current one")
	# Once the line finishes on its own, the queued one takes the air.
	voice._on_line_finished()
	assert_eq(String(voice.current_event()), String(VoiceLines.EV_ROULETTE_SPIN),
		"the queued roulette line plays next")
	# Restore the shared autoload's subscriptions for the rest of the suite.
	var autoload: Object = _autoload(&"VoiceDirector")
	if autoload != null and autoload.has_method("connect_match_events"):
		autoload.connect_match_events()


func test_combo_line_only_on_the_milestone() -> void:
	var voice := _make_voice()
	voice.connect_match_events()
	for combo: int in [1, 2, 3, 4]:
		EventBus.emit(&"combo_changed", combo)
	assert_eq(String(voice.current_event() if voice.is_speaking() else &""), "",
		"a low combo stays silent")
	EventBus.emit(&"combo_changed", 5)
	assert_eq(String(voice.current_event() if voice.is_speaking() else &""), String(VoiceLines.EV_COMBO_HIGH),
		"the combo milestone announces")


func test_time_warning_only_near_the_end() -> void:
	var voice := _make_voice()
	voice.connect_match_events()
	EventBus.emit(&"match_tick", 120.0)
	assert_eq(String(voice.current_event() if voice.is_speaking() else &""), "",
		"two minutes left stays silent")
	voice.set_clock_msec(10_000.0)
	EventBus.emit(&"match_tick", 15.0)
	assert_eq(String(voice.current_event() if voice.is_speaking() else &""), String(VoiceLines.EV_TIME_WARNING),
		"the last seconds warn")


func test_finished_result_picks_fail_or_flawless() -> void:
	var voice := _make_voice()
	voice.connect_match_events()
	EventBus.emit(&"minigame_finished", MinigameResult.make(false, 0, 0, 0, &"TIMEOUT"))
	assert_eq(String(voice.current_event()), String(VoiceLines.EV_MINIGAME_FAIL),
		"a failed micro-game is announced")


func test_disconnect_drops_every_subscription() -> void:
	var voice := _make_voice()
	voice.connect_match_events()
	var connected: bool = EventBus.match_started.is_connected(voice._on_match_started)
	assert_true(connected, "the subscription is live before disconnecting")
	voice.disconnect_match_events()
	assert_false(EventBus.match_started.is_connected(voice._on_match_started),
		"no subscription leaked behind")
	EventBus.emit(&"match_started")
	assert_false(voice.is_speaking(), "no announcement after disconnecting")
