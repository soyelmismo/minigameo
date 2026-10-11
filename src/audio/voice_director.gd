extends Node
## Locutor arcade VO director (scaffold.md §6.10 / §2).
##
## - One VO line at a time: higher priority preempts, equal priority queues.
## - Anti-spam cooldown per event (data-driven, default ~3s).
## - Random line variation per event (avoid repeat fatigue).
## - Music ducking while speaking (duck amount/duration data-driven).
## - Null/missing audio assets: log + skip, never crash (no VO assets yet).
##
## Headless determinism: cooldown/queue logic is driven by an injectable
## clock. Without VO assets a line's playback completes immediately
## (silent fallback) so the queue advances deterministically in tests.
##
## Cross-system isolation: the MusicDirector reference is injected and
## duck-typed (null-safe). No direct autoload references.

## Default anti-spam cooldown per event (seconds).
const DEFAULT_COOLDOWN_S: float = 3.0
## Where the generated announcer lines live (tools/audio/build_voice.py).
const VO_ASSET_DIR := "res://assets/audio/voice/"
## Combo milestone that earns an announcer line (not every step: spam).
const COMBO_MILESTONE: int = 5
## Remaining match time that triggers the time warning (seconds).
const TIME_WARNING_S: float = 30.0
## Default music duck while speaking (dB + fade, seconds).
const DEFAULT_DUCK_DB: float = -10.0
const DEFAULT_DUCK_FADE_S: float = 0.15

## Priority per event id (higher wins; equal priority queues behind).
const EVENT_PRIORITY: Dictionary = {
	VoiceLines.EV_MATCH_START: 100,
	VoiceLines.EV_POWERUP_COLLECTED: 80,
	VoiceLines.EV_ROULETTE_SPIN: 70,
	VoiceLines.EV_MINIGAME_START: 90,
	VoiceLines.EV_COMBO_HIGH: 60,
	VoiceLines.EV_TIME_WARNING: 75,
	VoiceLines.EV_MINIGAME_FAIL: 85,
	VoiceLines.EV_MINIGAME_FLAWLESS: 85,
	VoiceLines.EV_MATCH_RANK_S: 95,
	VoiceLines.EV_MATCH_RANK_LOW: 95,
}
const DEFAULT_PRIORITY: int = 50

## Injected, duck-typed. Any object with duck(amount_db, duration_s) /
## unduck(fade_s) works; null = no ducking (silent, no crash).
var music_director: Object = null

## Data-driven overrides.
var cooldown_overrides: Dictionary = {}    # event id -> seconds
var duck_db: float = DEFAULT_DUCK_DB
var duck_fade_s: float = DEFAULT_DUCK_FADE_S
var duck_duration_s: float = 1.5

## Tests inject a fake clock exposing `now_msec() -> float`.
var _time_source: Object = null
var _clock_msec: float = 0.0               # manual test clock

var _catalog: VoiceLines = null
var _speaking: bool = false
var _current_event: StringName = &""
var _last_spoken: Dictionary = {}          # event id -> clock msec
var _queue: Array[Dictionary] = []         # pending {event, line, priority}
var _voice_player: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = null
var _match_events_connected: bool = false

## --- Setup ---

func setup(catalog: VoiceLines, rng: RandomNumberGenerator = null) -> void:
	_catalog = catalog
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Subscribes to the match events the announcer owns (scaffold §6.10, §5).
## Audio listens to the bus like every other system (§1.1): no direct
## autoload references, and the mapping event -> VO line lives here, where the
## cooldown and priority policy lives. Idempotent, and safe to call before or
## after the catalog is set up.
func connect_match_events() -> void:
	if _match_events_connected:
		return
	EventBus.match_started.connect(_on_match_started)
	EventBus.powerup_collected.connect(_on_powerup_collected)
	EventBus.roulette_started.connect(_on_roulette_started)
	EventBus.minigame_started.connect(_on_minigame_started)
	EventBus.combo_changed.connect(_on_combo_changed)
	EventBus.match_tick.connect(_on_match_tick)
	EventBus.minigame_finished.connect(_on_minigame_finished)
	_match_events_connected = true


## Drops the subscriptions (teardown hygiene, §1.4).
func disconnect_match_events() -> void:
	if not _match_events_connected:
		return
	# get_connections() returns [{signal, callable, flags}, ...]: disconnect by
	# the stored callable, or the connection stays alive behind us.
	for sig: Signal in [
		EventBus.match_started, EventBus.powerup_collected,
		EventBus.roulette_started, EventBus.minigame_started,
		EventBus.combo_changed, EventBus.match_tick,
		EventBus.minigame_finished,
	]:
		for connection: Dictionary in sig.get_connections():
			sig.disconnect(connection["callable"] as Callable)
	_match_events_connected = false


# --- EventBus handlers (event id -> VO request) ---

func _on_match_started() -> void:
	speak(VoiceLines.EV_MATCH_START)


func _on_powerup_collected(_minigame_id: StringName) -> void:
	speak(VoiceLines.EV_POWERUP_COLLECTED)


func _on_roulette_started() -> void:
	speak(VoiceLines.EV_ROULETTE_SPIN)


func _on_minigame_started(_id: StringName) -> void:
	speak(VoiceLines.EV_MINIGAME_START)


func _on_combo_changed(combo: int) -> void:
	# Only the milestone matters: a VO line per step would be spam.
	if combo >= COMBO_MILESTONE:
		speak(VoiceLines.EV_COMBO_HIGH)


func _on_match_tick(time_left: float) -> void:
	if time_left > 0.0 and time_left <= TIME_WARNING_S:
		speak(VoiceLines.EV_TIME_WARNING)


func _on_minigame_finished(result: MinigameResult) -> void:
	if result == null:
		return
	speak(
		VoiceLines.EV_MINIGAME_FLAWLESS if result.success
		else VoiceLines.EV_MINIGAME_FAIL
	)

func set_time_source(source: Object) -> void:
	_time_source = source

## Manual clock for tests (msec).
func set_clock_msec(t: float) -> void:
	_clock_msec = t

func clock_msec() -> float:
	if _time_source != null and _time_source.has_method("now_msec"):
		return float(_time_source.call("now_msec"))
	return _clock_msec

## --- Public API ---

## Requests a VO line for an event. Higher priority preempts the current
## line; equal/lower priority queues behind it. Returns true when the line
## started immediately. Never throws.
func speak(event_id: StringName) -> bool:
	if _catalog == null:
		push_warning("VoiceDirector.speak('%s'): no catalog set, skipped." % event_id)
		return false
	var lines: Array = VoiceLines.lines_for(event_id)
	if lines.is_empty():
		push_warning("VoiceDirector.speak('%s'): no lines in catalog, skipped." % event_id)
		return false
	if _on_cooldown(event_id):
		return false
	var priority: int = priority_for(event_id)
	var line: String = _pick_line(lines)
	if _speaking and priority <= priority_for(_current_event):
		_queue.append({"event": event_id, "line": line, "priority": priority})
		return false
	# Not speaking, or preempting: cut whatever is playing first.
	if _speaking:
		_cut_current()
	return _start(event_id, line, priority)

## Priority for an event (data-driven table + override hook).
func priority_for(event_id: StringName) -> int:
	var override: Variant = cooldown_overrides.get(event_id, null)
	if override != null:
		return int(override)
	return int(EVENT_PRIORITY.get(event_id, DEFAULT_PRIORITY))

func is_speaking() -> bool:
	return _speaking

func current_event() -> StringName:
	return _current_event

func queue_length() -> int:
	return _queue.size()

## Interrupts the current line and clears the queue (match abort, etc.).
func stop() -> void:
	_cut_current()
	_queue.clear()

## Seconds until `event_id` leaves cooldown (0 = ready). Test helper.
func cooldown_remaining_s(event_id: StringName) -> float:
	if not _last_spoken.has(event_id):
		return 0.0
	var elapsed_s: float = (clock_msec() - float(_last_spoken[event_id])) / 1000.0
	return maxf(0.0, _cooldown_for(event_id) - elapsed_s)

## --- Internals ---

func _start(event_id: StringName, line: String, priority: int) -> bool:
	_speaking = true
	_current_event = event_id
	_last_spoken[event_id] = clock_msec()
	_duck_music()
	# No VO assets exist yet: the line resolves to a null stream and the
	# silent fallback ends it immediately, so the queue still advances.
	_spawn_voice_player(event_id)
	return true

func _spawn_voice_player(event_id: StringName) -> void:
	if _voice_player != null and is_instance_valid(_voice_player):
		_voice_player.queue_free()
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = BusLayout.BUS_VO
	_voice_player.stream = _resolve_vo_stream(event_id)
	add_child(_voice_player)
	if _voice_player.stream != null:
		_voice_player.play()
		_voice_player.finished.connect(_on_line_finished, Object.CONNECT_ONE_SHOT)
	else:
		# Silent fallback: treat as a zero-length line.
		_on_line_finished()

func _resolve_vo_stream(event_id: StringName) -> AudioStream:
	# One rendered line per event: the catalog may hold several variations, but
	# the build renders the first one deterministically (tools/audio). A missing
	# file degrades to the silent fallback instead of failing the match.
	var path := VO_ASSET_DIR + "vo_" + String(event_id).trim_prefix("EV_").to_lower() + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("VoiceDirector: no VO audio asset at %s; silent fallback." % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("VoiceDirector: could not load %s; silent fallback." % path)
	return stream

func _on_line_finished() -> void:
	if _voice_player != null and is_instance_valid(_voice_player):
		_voice_player.queue_free()
		_voice_player = null
	_speaking = false
	_current_event = &""
	_unduck_music()
	_advance_queue()

func _advance_queue() -> void:
	if _queue.is_empty():
		return
	var best: int = 0
	for i in range(1, _queue.size()):
		if int(_queue[i]["priority"]) > int(_queue[best]["priority"]):
			best = i
	var next: Dictionary = _queue[best]
	_queue.remove_at(best)
	_start(StringName(next["event"]), String(next["line"]), int(next["priority"]))

func _cut_current() -> void:
	if not _speaking:
		return
	if _voice_player != null and is_instance_valid(_voice_player):
		if _voice_player.finished.is_connected(_on_line_finished):
			_voice_player.finished.disconnect(_on_line_finished)
		_voice_player.stop()
		_voice_player.queue_free()
		_voice_player = null
	_speaking = false
	_current_event = &""
	_unduck_music()

func _pick_line(lines: Array) -> String:
	if lines.size() == 1:
		return String(lines[0])
	var idx: int = _rng.randi_range(0, lines.size() - 1)
	return String(lines[idx])

func _cooldown_for(event_id: StringName) -> float:
	var override: Variant = cooldown_overrides.get(event_id, DEFAULT_COOLDOWN_S)
	return float(override)

func _on_cooldown(event_id: StringName) -> bool:
	return cooldown_remaining_s(event_id) > 0.0

## --- Ducking (injected, duck-typed; silent no-op when absent) ---

func _duck_music() -> void:
	if music_director == null:
		return
	if music_director.has_method("duck"):
		music_director.call("duck", duck_db, duck_fade_s)

func _unduck_music() -> void:
	if music_director == null:
		return
	if music_director.has_method("unduck"):
		music_director.call("unduck", duck_fade_s)
