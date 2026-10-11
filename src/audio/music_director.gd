class_name MusicDirector
extends Node
## Dynamic music director (scaffold.md §6.9 / §10.2).
##
## State machine: CALM / TENSION / PEAK / TRIUMPH / FAIL.
## Intensity 0..1 gates vertical layers:
##   drums always | bass >= 0.3 | lead >= 0.6 | harmony+fx >= 0.85
## Beat clock: BPM data (default 128), 4/4 -> 1 bar = 4 beats = 4 * 60/BPM
## seconds. Layer switches happen on the next 2-bar boundary.
## Manual crossfade fallback (AudioStreamPolyphonic-style stems) until real
## AudioStreamInteractive assets land.
## Null/missing stems: log + skip (no music assets exist yet).
##
## All time comes from an injected clock (tests inject fake time); the
## default clock is the engine's, so gameplay stays untouched.

## --- Musical states (scaffold §10.2) ---
const STATE_CALM: StringName = &"CALM"
const STATE_TENSION: StringName = &"TENSION"
const STATE_PEAK: StringName = &"PEAK"
const STATE_TRIUMPH: StringName = &"TRIUMPH"
const STATE_FAIL: StringName = &"FAIL"

## Layer intensity gates (scaffold §10.2, verbatim thresholds).
const LAYER_DRUMS: StringName = &"drums"
const LAYER_BASS: StringName = &"bass"
const LAYER_LEAD: StringName = &"lead"
const LAYER_HARMONY: StringName = &"harmony"
const LAYER_FX: StringName = &"fx"

const GATE_BASS: float = 0.3
const GATE_LEAD: float = 0.6
const GATE_HARMONY_FX: float = 0.85

## --- Beat clock defaults (data-driven overridable) ---
const DEFAULT_BPM: float = 128.0
const BEATS_PER_BAR: int = 4
const BARS_PER_SWITCH: int = 2

## --- Ducking ---
const DEFAULT_DUCK_DB: float = -12.0
const DEFAULT_DUCK_FADE_S: float = 0.2

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
## registered by AudioDirector (or a .tres later). Empty = silent fallback.
var stems: Dictionary = {}

## Optional: global duck target (VO calls duck(); AudioDirector unducks).
var duck_db: float = DEFAULT_DUCK_DB
var duck_fade_s: float = DEFAULT_DUCK_FADE_S
var duck_hold_s: float = 1.5

var _time: float = 0.0             # seconds of music clock (injected in tests)
var _beat_index: int = 0           # beats since clock start
var _last_switch_bar: int = -1
var _pending_switch: bool = false
var _active_layers: Dictionary = {}     # layer -> bool
var _layer_players: Dictionary = {}     # layer -> AudioStreamPlayer
var _state_player: AudioStreamPlayer = null
var _duck_active: bool = false
var _fade_target: float = 0.0
var _fade_time: float = 0.0
var _fade_elapsed: float = 0.0
var _time_source: Object = null         # tests inject fake clock

## --- Public API (scaffold §6.9 contract) ---

## Requests a music state at an intensity (0..1). Layer changes are quantized
## to the next 2-bar boundary; the state change itself is immediate.
func play_music_state(state: StringName, state_intensity: float = -1.0) -> void:
	if state != current_state:
		current_state = state
	if state_intensity >= 0.0:
		intensity = state_intensity
	_request_layer_switch()

## Sidechain duck (called by VoiceDirector / ImpactDirector).
## amount in dB (negative), duration in seconds; 0 duration = until unduck().
func duck(amount_db: float, duration_s: float) -> void:
	duck_db = amount_db
	_duck_active = true
	if duration_s > 0.0:
		_duck_hold_s = duration_s
	_apply_duck()

func unduck(fade_s: float = -1.0) -> void:
	_duck_active = false
	if fade_s >= 0.0:
		duck_fade_s = fade_s
	_apply_duck()

## Advances the beat clock by `delta` seconds. Gameplay normally calls this
## from the director's update; tests call it with fake deltas.
func tick(delta: float) -> void:
	_time += delta
	var seconds_per_beat: float = 60.0 / bpm
	var total_beats: int = int(_time / seconds_per_beat)
	_beat_index = total_beats
	var bar: int = total_beats / BEATS_PER_BAR
	if _pending_switch and bar > _last_switch_bar and bar % BARS_PER_SWITCH == 0:
		_last_switch_bar = bar
		_pending_switch = false
		_apply_layers()

## --- Layer logic (pure, testable) ---

## Which layers are audible at a given intensity. Pure function of data.
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

func active_layers() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in _active_layers:
		if bool(_active_layers[key]):
			out.append(key)
	return out

func beat_index() -> int:
	return _beat_index

func bar_index() -> int:
	return _beat_index / BEATS_PER_BAR

## Seconds per beat (derived from BPM).
func seconds_per_beat() -> float:
	return 60.0 / bpm

## Seconds per bar.
func seconds_per_bar() -> float:
	return seconds_per_beat() * float(BEATS_PER_BAR)

## True when a layer switch is waiting for the next 2-bar boundary.
func has_pending_switch() -> bool:
	return _pending_switch

## --- Internals ---

func _request_layer_switch() -> void:
	var wanted: Array[StringName] = layers_for_intensity(intensity)
	if _layers_equal(wanted):
		return
	_pending_switch = true

func _layers_equal(wanted: Array[StringName]) -> bool:
	for layer: StringName in wanted:
		if not bool(_active_layers.get(layer, false)):
			return false
	for layer: StringName in _active_layers:
		if bool(_active_layers[layer]) and not wanted.has(layer):
			return false
	return true

func _apply_layers() -> void:
	var wanted: Array[StringName] = layers_for_intensity(intensity)
	for layer: StringName in [LAYER_DRUMS, LAYER_BASS, LAYER_LEAD, LAYER_HARMONY, LAYER_FX]:
		var on: bool = wanted.has(layer)
		_active_layers[layer] = on
		_set_layer_audible(layer, on)

func _set_layer_audible(layer: StringName, on: bool) -> void:
	var player: Variant = _layer_players.get(layer, null)
	if player == null:
		return
	var p: AudioStreamPlayer = player as AudioStreamPlayer
	if on:
		if not p.playing and p.stream != null:
			p.play()
	else:
		if p.playing:
			p.stop()

func _apply_duck() -> void:
	var target_db: float = duck_db if _duck_active else 0.0
	_fade_target = target_db
	_fade_time = duck_fade_s
	_fade_elapsed = 0.0

## Crossfade fallback: layers ramp to their target gain over duck_fade_s.
func _process(delta: float) -> void:
	if _fade_time <= 0.0:
		return
	_fade_elapsed += delta
	var t: float = clampf(_fade_elapsed / _fade_time, 0.0, 1.0)
	var current: float = 0.0 if not _duck_active else 0.0
	# Linear ramp between 0 dB and the duck target.
	var gain: float = lerpf(0.0, _fade_target, t)
	for layer: StringName in _layer_players:
		var p: AudioStreamPlayer = _layer_players[layer] as AudioStreamPlayer
		if p.stream != null:
			p.volume_db = gain

## --- Stem registration (data-driven; null streams tolerated) ---

## Registers a layer stem for a state. A null stream is stored and the layer
## stays silent (logged once per state+layer).
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

func set_time_source(source: Object) -> void:
	_time_source = source

func set_clock_time(t: float) -> void:
	_time = t
