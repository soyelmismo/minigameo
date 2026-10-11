extends Node
## Dynamic music director (scaffold.md §6.9 / §10.2).
##
## The Nintendo-style ladder: calm in freeroam, rising with the combo,
## euphoric inside a micro-game, and resolving cleanly afterwards.
##
## Model
## -----
## - Five vertical stems (drums / bass / lead / harmony / fx) are registered
##   per musical state via set_stem(); the six assets built by
##   tools/audio/build_audio.py are registered by default. Every stem is the
##   SAME length in bars at the SAME tempo, so any subset stays phase-locked.
## - `intensity` (0..1) gates the layers (scaffold §10.2, verbatim):
##       drums always | bass >= 0.3 | lead >= 0.6 | harmony+fx >= 0.85
##   STATE_INTENSITY is THE LADDER DATA: state -> default intensity, applied
##   whenever a caller requests a state without an explicit intensity.
## - Layer switches are QUANTIZED to the next 2-bar boundary and applied as
##   a volume CROSSFADE (CROSSFADE_S): never a hard cut, and a layer that is
##   already playing is never restarted (that would break the phase lock).
## - SILENCE DISCIPLINE: a layer that is not wanted fades to SILENCE_DB and
##   is then STOPPED. Re-entry restarts it phase-aligned to the music clock
##   (play(from_position)), so a returning layer never seams or doubles.
## - DUCKING (VO / impacts) dips the whole music bed with a short fade.
##   duration_s >= DUCK_TIMED_MIN_S arms an auto-release; a smaller value is
##   a fade-only request that holds until unduck() (VoiceDirector passes its
##   fade here and releases explicitly when the line ends).
## - Time: tick(delta) advances the beat clock, advance(delta) = tick +
##   fades, and _process drives advance() with the frame delta, so gameplay
##   needs no extra wiring. Tests inject a fake clock via set_time_source().
##
## Missing stems degrade to a logged no-op: the game never throws.

## --- Musical states (scaffold §10.2) ---
const STATE_CALM: StringName = &"CALM"
const STATE_TENSION: StringName = &"TENSION"
const STATE_PEAK: StringName = &"PEAK"
const STATE_TRIUMPH: StringName = &"TRIUMPH"
const STATE_FAIL: StringName = &"FAIL"

## Every state the ladder knows (iteration order = ladder order).
const ALL_STATES: Array[StringName] = [
	STATE_CALM,
	STATE_TENSION,
	STATE_PEAK,
	STATE_TRIUMPH,
	STATE_FAIL,
]

## --- Vertical layers (scaffold §10.2) ---
const LAYER_DRUMS: StringName = &"drums"
const LAYER_BASS: StringName = &"bass"
const LAYER_LEAD: StringName = &"lead"
const LAYER_HARMONY: StringName = &"harmony"
const LAYER_FX: StringName = &"fx"

## Registration + iteration order of the layer stack.
const LAYER_ORDER: Array[StringName] = [
	LAYER_DRUMS,
	LAYER_BASS,
	LAYER_LEAD,
	LAYER_HARMONY,
	LAYER_FX,
]

## Layer intensity gates (scaffold §10.2, verbatim thresholds).
const GATE_BASS: float = 0.3
const GATE_LEAD: float = 0.6
const GATE_HARMONY_FX: float = 0.85

## --- THE LADDER DATA: state -> default intensity (0..1) ---
## CALM    freeroam bed: drums only, the calm floor of the game.
## TENSION roulette / last seconds: drums + bass + lead, the riser.
## PEAK    active micro-game: every layer, the euphoric ceiling.
## TRIUMPH match results: the full stack, the celebration.
## FAIL    failed micro-game: austere drums + bass under the announcer.
const STATE_INTENSITY: Dictionary = {
	STATE_CALM: 0.15,
	STATE_TENSION: 0.65,
	STATE_PEAK: 0.9,
	STATE_TRIUMPH: 1.0,
	STATE_FAIL: 0.3,
}

## --- Beat clock (GameConfig.music_bpm overrides the default) ---
const DEFAULT_BPM: float = 128.0
const BEATS_PER_BAR: int = 4
const BARS_PER_SWITCH: int = 2
const CONFIG_PATH := "res://src/core/config/game_config.tres"

## --- Crossfade / mix (tuning data, AGENTS.md §1.3) ---
const CROSSFADE_S: float = 0.5
const SILENCE_DB: float = -80.0
## Upper bound for a playing layer, and the span the crossfades sweep.
const AUDIBLE_MAX_DB: float = 6.0
## Per-layer mix trim (dB) so the summed stack keeps headroom while every
## layer keeps its musical function. Measured stem RMS (tools/audio gate):
## drums .222 / bass .176 / lead .064 / harmony .134 / fx .080 — the quiet
## stems enter at a trim that keeps them audible over the busy bed.
const LAYER_GAIN_DB: Dictionary = {
	LAYER_DRUMS: 0.0,
	LAYER_BASS: -1.0,
	LAYER_LEAD: 4.0,
	LAYER_HARMONY: -1.0,
	LAYER_FX: 3.0,
}
## Pre-mixed fallback gain (music_full.wav) when the individual stems are
## not available: the authored mix, trimmed to sit under the same ceiling.
const FULL_MIX_GAIN_DB: float = -3.0

## --- Ducking ---
const DEFAULT_DUCK_DB: float = -12.0
const DEFAULT_DUCK_FADE_S: float = 0.2
## Below this, duration_s is a fade-only request (hold until unduck());
## at or above it, the duck auto-releases after the hold. VoiceDirector
## passes its fade (0.15 s) and releases explicitly when the line ends.
const DUCK_TIMED_MIN_S: float = 0.25

## --- Default stems (deterministic build: tools/audio/build_audio.py) ---
const MUSIC_DIR := "res://assets/audio/music/"
const STEM_FILES: Dictionary = {
	LAYER_DRUMS: MUSIC_DIR + "music_drums.wav",
	LAYER_BASS: MUSIC_DIR + "music_bass.wav",
	LAYER_LEAD: MUSIC_DIR + "music_lead.wav",
	LAYER_HARMONY: MUSIC_DIR + "music_harmony.wav",
	LAYER_FX: MUSIC_DIR + "music_fx.wav",
}
const FULL_MIX_PATH := MUSIC_DIR + "music_full.wav"

var current_state: StringName = STATE_CALM:
	set(value):
		if value == current_state:
			return
		current_state = value
		_request_layer_switch()

var intensity: float = 0.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, intensity):
			return
		intensity = clamped
		_request_layer_switch()

var bpm: float = DEFAULT_BPM:
	set(value):
		bpm = maxf(value, 1.0)

## Stems per state: state -> {layer -> AudioStream or null}. Data-driven;
## registered here from the default assets, or by an external data source
## with set_stem(). Empty = silent (logged once), never a crash.
var stems: Dictionary = {}

## Optional: global duck target (VO calls duck(); AudioDirector unducks).
var duck_db: float = DEFAULT_DUCK_DB
var duck_fade_s: float = DEFAULT_DUCK_FADE_S
var duck_hold_s: float = 1.5

var _time: float = 0.0             # seconds of music clock (injected in tests)
var _beat_index: int = 0           # beats since clock start
var _last_switch_bar: int = -1
var _pending_switch: bool = false
var _active_layers: Dictionary = {}     # layer -> bool (the audible set)
var _layer_players: Dictionary = {}     # layer -> AudioStreamPlayer
var _layer_gain: Dictionary = {}        # layer -> current base gain (dB, ramped)
var _layer_target: Dictionary = {}      # layer -> wanted base gain (dB)
var _layer_stream: Dictionary = {}      # layer -> AudioStream bound to the state
var _layer_running: Dictionary = {}     # layer -> bool (player is playing)
var _pending_stream: Dictionary = {}    # layer -> AudioStream waiting for silence
var _duck_active: bool = false
var _duck_gain: float = 0.0             # current duck offset (dB, ramped)
var _duck_from: float = 0.0              # where the current ramp started (dB)
var _duck_target: float = 0.0           # wanted duck offset (dB)
var _duck_hold_left: float = 0.0        # seconds until a timed duck releases
var _full_mix_player: AudioStreamPlayer = null  # pre-mixed fallback player
var _full_mix_gain: float = SILENCE_DB
var _full_mix_target: float = SILENCE_DB
var _time_source: Object = null         # tests inject a fake clock (now_sec())

## --- Public API (scaffold §6.9 contract) ---

## Requests a music state at an intensity (0..1). Without an explicit
## intensity the state's ladder value applies. The state change itself is
## immediate; the layer mix lands on the next 2-bar boundary.
func play_music_state(state: StringName, state_intensity: float = -1.0) -> void:
	if state_intensity < 0.0:
		var from_ladder: Variant = STATE_INTENSITY.get(state, null)
		state_intensity = float(from_ladder) if from_ladder != null else intensity
	var state_changed: bool = state != current_state
	current_state = state
	if state_intensity >= 0.0:
		intensity = state_intensity
	if state_changed:
		# A state change may bind a different stem per layer: force the
		# bar-quantized re-bind even when the layer set itself is unchanged.
		_pending_switch = true

## Sidechain duck (called by VoiceDirector / ImpactDirector).
## amount_db in dB (negative); duration_s >= DUCK_TIMED_MIN_S arms an
## auto-release after the hold, a smaller value holds until unduck().
func duck(amount_db: float, duration_s: float) -> void:
	_begin_duck_ramp(amount_db)
	duck_db = amount_db
	_duck_active = true
	if duration_s >= DUCK_TIMED_MIN_S:
		duck_hold_s = duration_s
		_duck_hold_left = duration_s
	else:
		duck_hold_s = duration_s
		_duck_hold_left = 0.0

func unduck(fade_s: float = -1.0) -> void:
	# Releasing is a ramp too: it starts from wherever the duck actually is, so
	# a half-finished duck comes back over the full fade time rather than
	# crawling the last fraction at a trickle.
	_begin_duck_ramp(0.0)
	_duck_active = false
	_duck_hold_left = 0.0
	if fade_s >= 0.0:
		duck_fade_s = fade_s


## (Re)anchors the duck ramp so its rate is a constant dB/second over the whole
## distance it is about to travel.
##
## Deriving the rate from the target's magnitude is wrong in both directions:
## a duck to -6 dB gives a sane rate, but the release back to 0 dB gives a rate
## of zero, so the music un-ducks at 0.0001 dB per frame — the player hears the
## music stay quiet for seconds after the VO ends.
func _begin_duck_ramp(new_target: float) -> void:
	_duck_target = new_target
	_duck_from = _duck_gain

## Advances the beat clock by `delta` seconds and applies a pending layer
## switch on the next 2-bar boundary. Gameplay normally calls advance();
## tests call this (or inject a clock) with exact deltas.
func tick(delta: float) -> void:
	if _time_source != null and _time_source.has_method("now_sec"):
		# Injected absolute clock (tests): the beat clock follows it exactly.
		_time = float(_time_source.call("now_sec"))
	else:
		_time += delta
	var spb: float = 60.0 / bpm
	var total_beats: int = int(_time / spb)
	_beat_index = total_beats
	if has_pending_switch() and bar_index() > _last_switch_bar \
			and bar_index() % BARS_PER_SWITCH == 0:
		_last_switch_bar = bar_index()
		_pending_switch = false
		_apply_layers()

## One simulation step: beat clock, then the crossfades and the duck.
func advance(delta: float) -> void:
	tick(delta)
	_advance_duck(delta)
	_advance_layer_fades(delta)

## --- Layer logic (pure, testable) ---

## Which layers are audible at a given intensity. Pure function of the
## scaffold §10.2 gates.
func layers_for_intensity(value: float) -> Array[StringName]:
	var v: float = clampf(value, 0.0, 1.0)
	var out: Array[StringName] = [LAYER_DRUMS]
	if v >= GATE_BASS:
		out.append(LAYER_BASS)
	if v >= GATE_LEAD:
		out.append(LAYER_LEAD)
	if v >= GATE_HARMONY_FX:
		out.append(LAYER_HARMONY)
		out.append(LAYER_FX)
	return out

## The layers the ladder currently wants audible (audible or fading).
func active_layers() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in _active_layers:
		if bool(_active_layers[key]):
			out.append(key)
	return out

## Seconds a layer takes to enter or leave, capped by the switch cadence:
## a fade that outlived the next 2-bar window would stack on the next one.
func crossfade_s() -> float:
	return minf(CROSSFADE_S, seconds_per_bar() * float(BARS_PER_SWITCH))

func beat_index() -> int:
	return _beat_index

## Current bar (0-based). The switch lands on even bars.
func bar_index() -> int:
	return int(floor(float(_beat_index) / float(BEATS_PER_BAR)))

## Seconds per beat (derived from BPM).
func seconds_per_beat() -> float:
	return 60.0 / bpm

## Seconds per bar.
func seconds_per_bar() -> float:
	return seconds_per_beat() * float(BEATS_PER_BAR)

## True when a layer switch is waiting for the next 2-bar boundary.
func has_pending_switch() -> bool:
	return _pending_switch

## Current base gain of a layer (dB, duck excluded).
func layer_gain_db(layer: StringName) -> float:
	return float(_layer_gain.get(layer, SILENCE_DB))

## True while the layer is audibly present (gain above the silence floor).
func layer_is_audible(layer: StringName) -> bool:
	return layer_gain_db(layer) > SILENCE_DB + 6.0

## Current duck offset applied over the music bed (dB).
func duck_gain_db() -> float:
	return _duck_gain

## The ladder as data: state -> {"intensity": float, "layers": Array}.
func ladder_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for state: StringName in ALL_STATES:
		var value: Variant = STATE_INTENSITY.get(state, null)
		var intensity_value: float = float(value) if value != null else 0.0
		out[state] = {
			"intensity": intensity_value,
			"layers": layers_for_intensity(intensity_value),
		}
	return out

## The layers a state's default intensity maps to (ladder lookup).
func state_layer_set(state: StringName) -> Array[StringName]:
	var value: Variant = STATE_INTENSITY.get(state, null)
	return layers_for_intensity(float(value) if value != null else 0.0)

## --- Internals ---

func _ready() -> void:
	_register_service()
	_refresh_from_config()
	_register_default_stems()
	_build_layer_players()

## Self-registers under the canonical service name (scaffold §6 / AGENTS
## §1.1): consumers resolve this system via GameServices.lookup(&"music")
## instead of referencing the autoload by path.
##
## ONLY the autoload instance (a direct child of the tree root) registers:
## a test-created instance would overwrite the canonical entry with a
## reference that dies with the test, and every consumer's resolve() would
## then hand back null for the rest of the run.
func _register_service() -> void:
	GameServices.publish("MusicDirector", &"music", self)

## BPM is data (§1.3): read it from GameConfig.tres so tuning the .tres
## actually retunes the beat clock. An explicitly set value wins, so a
## test (or a runtime change) is never overwritten by the file.
func _refresh_from_config() -> void:
	if not is_equal_approx(bpm, DEFAULT_BPM):
		return
	var loaded: Variant = load(CONFIG_PATH)
	if loaded != null and loaded.get("music_bpm") != null:
		bpm = float(loaded.get("music_bpm"))

## Registers the default stems for every state, unless an external data
## source already registered a stem set (data-driven wins over defaults).
func _register_default_stems() -> void:
	if not stems.is_empty():
		return
	for state: StringName in ALL_STATES:
		for layer: StringName in LAYER_ORDER:
			var stream: AudioStream = _load_stream(String(STEM_FILES[layer]))
			if stream != null:
				set_stem(state, layer, stream)

func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res as AudioStream
	return null

## One AudioStreamPlayer per layer, all looped on the Music bus. Every
## player starts on the SAME frame at position 0: the stems are period-exact
## loops on the same bar grid, so the stack is phase-locked for the whole
## session. Layers start silent (SILENCE_DB); the ladder fades them in.
func _build_layer_players() -> void:
	var wanted: Array[StringName] = layers_for_intensity(intensity)
	var any_stem: bool = false
	for layer: StringName in LAYER_ORDER:
		if get_stem(current_state, layer) != null:
			any_stem = true
			break
	if not any_stem:
		_build_full_mix_fallback()
		return
	for layer: StringName in LAYER_ORDER:
		var stream: AudioStream = get_stem(current_state, layer)
		var player := AudioStreamPlayer.new()
		player.name = String(layer)
		player.bus = BusLayout.BUS_MUSIC
		player.volume_db = SILENCE_DB
		add_child(player)
		_layer_players[layer] = player
		_layer_stream[layer] = stream
		player.stream = stream
		_layer_gain[layer] = SILENCE_DB
		_layer_target[layer] = float(LAYER_GAIN_DB[layer]) if wanted.has(layer) else SILENCE_DB
		_active_layers[layer] = wanted.has(layer)
		_layer_running[layer] = false
		if stream != null:
			player.play(0.0)
			_layer_running[layer] = true

## Pre-mixed fallback: without the individual stems the director still
## plays the authored full mix (music_full.wav) so the game is never
## silently musicless. Logged once, never fatal.
func _build_full_mix_fallback() -> void:
	var stream: AudioStream = _load_stream(FULL_MIX_PATH)
	if stream == null:
		push_warning("MusicDirector: no music stems under %s; music is silent." % MUSIC_DIR)
		return
	var player := AudioStreamPlayer.new()
	player.name = FULL_MIX_PATH.get_file().get_basename()
	player.bus = BusLayout.BUS_MUSIC
	player.volume_db = SILENCE_DB
	add_child(player)
	player.stream = stream
	player.play(0.0)
	_full_mix_player = player

func _request_layer_switch() -> void:
	if has_pending_switch():
		return
	if _layers_equal(layers_for_intensity(intensity)):
		return
	_pending_switch = true

func _layers_equal(wanted: Array[StringName]) -> bool:
	var on: Array[StringName] = active_layers()
	if on.size() != wanted.size():
		return false
	for layer: StringName in wanted:
		if not on.has(layer):
			return false
	return true

## Applies the ladder at a bar boundary: per-state stems (when they differ)
## and the crossfade targets for every layer.
func _apply_layers() -> void:
	var wanted: Array[StringName] = layers_for_intensity(intensity)
	_bind_state_stems()
	for layer: StringName in LAYER_ORDER:
		var on: bool = wanted.has(layer)
		_active_layers[layer] = on
		_layer_target[layer] = float(LAYER_GAIN_DB[layer]) if on else SILENCE_DB
	# Pre-mixed fallback follows the ladder as a single bed.
	if _full_mix_player != null:
		_full_mix_target = FULL_MIX_GAIN_DB if not wanted.is_empty() else SILENCE_DB

## Binds each layer's stem to the ACTIVE state. A layer that is playing is
## never hard-cut: the swap is deferred to the moment it is silent again
## (its fade-out ends), then it restarts phase-locked.
func _bind_state_stems() -> void:
	for layer: StringName in LAYER_ORDER:
		var stream: AudioStream = get_stem(current_state, layer)
		if stream == _layer_stream.get(layer, null):
			continue
		if bool(_layer_running.get(layer, false)):
			_pending_stream[layer] = stream
			continue
		_bind_stream(layer, stream)

func _bind_stream(layer: StringName, stream: AudioStream) -> void:
	_pending_stream.erase(layer)
	_layer_stream[layer] = stream
	var player: AudioStreamPlayer = _layer_players.get(layer, null)
	if player == null:
		return
	player.stream = stream
	if stream == null and bool(_layer_running.get(layer, false)):
		player.stop()
		_layer_running[layer] = false

## Phase-aligned restart of a stopped layer: the play position is derived
## from the music clock so the layer rejoins the running stack exactly on
## its beat grid (no seam, no doubling).
func _restart_layer(layer: StringName) -> void:
	var player: AudioStreamPlayer = _layer_players.get(layer, null)
	if player == null or player.stream == null:
		return
	var length: float = player.stream.get_length()
	var position: float = fmod(_time, length) if length > 0.001 else 0.0
	player.play(position)
	_layer_running[layer] = true

## Volume automation for the duck (a ramp, never a step).
func _advance_duck(delta: float) -> void:
	if _duck_active and _duck_hold_left > 0.0:
		_duck_hold_left = maxf(0.0, _duck_hold_left - delta)
		if _duck_hold_left <= 0.0:
			# Timed duck expired: release it through the fade, not a jump.
			_duck_active = false
			_duck_target = 0.0
	var target: float = _duck_target if _duck_active else 0.0
	if not is_equal_approx(_duck_gain, target):
		# CONSTANT rate in dB/second over the distance this ramp is travelling
		# (_duck_from -> target). Two wrong versions came before this:
		#   - dividing the REMAINING distance by the fade time, which is
		#     asymptotic and never lands on the target;
		#   - dividing the target's MAGNITUDE by the fade time, which gives a
		#     rate of zero when releasing back to 0 dB, so the music stayed
		#     quiet for seconds after the VO finished.
		# The anchored span makes both the duck and the release land on their
		# target in exactly `duck_fade_s`.
		var travel: float = absf(target - _duck_from)
		var step: float = maxf(travel / maxf(duck_fade_s, 0.0001) * delta, 0.0001)
		_duck_gain = move_toward(_duck_gain, target, step)

## Volume automation for the layer crossfades + silence discipline.
func _advance_layer_fades(delta: float) -> void:
	if _full_mix_player != null:
		# Pre-mixed fallback: one bed follows the ladder.
		if not is_equal_approx(_full_mix_gain, _full_mix_target):
			# Constant rate over the audible span, so the crossfade lands on its
			# target instead of chasing it forever.
			var frange: float = absf(AUDIBLE_MAX_DB - SILENCE_DB)
			var fstep: float = maxf(
				frange / maxf(crossfade_s(), 0.0001) * delta, 0.0001
			)
			_full_mix_gain = move_toward(_full_mix_gain, _full_mix_target, fstep)
		_full_mix_player.volume_db = clampf(_full_mix_gain + _duck_gain, SILENCE_DB, 6.0)
		return
	var rate: float = delta / maxf(crossfade_s(), 0.0001)
	for layer: StringName in LAYER_ORDER:
		var target: float = float(_layer_target.get(layer, SILENCE_DB))
		var gain: float = float(_layer_gain.get(layer, SILENCE_DB))
		if not is_equal_approx(gain, target):
			# Constant rate per layer over the audible span, so every crossfade
			# settles (a proportional ramp never reaches the target, which left
			# layers chasing their gain forever, so the silence-discipline stop
			# below could never fire).
			var lrange: float = absf(AUDIBLE_MAX_DB - SILENCE_DB)
			var lstep: float = maxf(lrange * rate, 0.0001)
			gain = move_toward(gain, target, lstep)
			_layer_gain[layer] = gain
		if is_equal_approx(gain, SILENCE_DB) and bool(_layer_running.get(layer, false)):
			# Silence discipline: the fade-out completed -> STOP the stem.
			# A layer that is not meant to play is not playing.
			var player: AudioStreamPlayer = _layer_players.get(layer, null)
			if player != null:
				player.stop()
			_layer_running[layer] = false
			if _pending_stream.has(layer):
				_bind_stream(layer, _pending_stream[layer])
		elif not bool(_layer_running.get(layer, false)) \
				and not is_equal_approx(target, SILENCE_DB) \
				and _layer_stream.get(layer, null) != null:
			# Wanted but stopped: re-enter phase-locked (never restart a
			# layer that is already playing).
			if _pending_stream.has(layer):
				_bind_stream(layer, _pending_stream[layer])
			_restart_layer(layer)
		var playing: AudioStreamPlayer = _layer_players.get(layer, null)
		if playing != null:
			playing.volume_db = clampf(gain + _duck_gain, SILENCE_DB, 6.0)

## --- Stem registration (data-driven; null streams tolerated) ---

## Registers a layer stem for a state. A null stream is stored and the
## layer stays silent (logged once per state+layer).
func set_stem(state: StringName, layer: StringName, stream: AudioStream) -> void:
	if not stems.has(state):
		stems[state] = {}
	var state_map: Dictionary = stems[state] as Dictionary
	state_map[layer] = stream

func get_stem(state: StringName, layer: StringName) -> AudioStream:
	var state_map: Variant = stems.get(state, null)
	if state_map == null:
		return null
	var stream: Variant = (state_map as Dictionary).get(layer, null)
	return stream as AudioStream

## --- Test hooks ---

## Injects an absolute clock (an object exposing now_sec() -> float).
## tick()/advance() then follow it instead of the frame delta.
func set_time_source(source: Object) -> void:
	_time_source = source
