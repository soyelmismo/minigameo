extends Node
## Pooled SFX voice player (scaffold.md §10.2 / §6.8).
##
## - Voice pool: one AudioStreamPlayer per pooled voice (max_voices, data
##   driven, default 32). play() NEVER throws.
## - Priority + voice stealing: when the pool is saturated the victim is the
##   lowest-priority voice; ties break to the oldest (longest-playing).
## - Randomization per take: pitch ±5%, volume ±1.5 dB (scaled by the
##   catalog entry, data-driven).
## - Per-group and per-id concurrency caps from the catalog.
## - Null/missing streams: log once + skip (no audio assets exist yet).
##
## Cross-system isolation (AGENTS.md §1.1): nothing references other
## autoloads; the MusicDirector is asked to duck via the injected reference
## (duck-typed), and that reference may be null.

## Max simultaneous voices (scaffold §15 budget: < 32).
const DEFAULT_MAX_VOICES: int = 32
const PITCH_RAND: float = 0.05        # ±5%
const VOLUME_RAND_DB: float = 1.5     # ±1.5 dB

var library: SFXLibrary = null
var max_voices: int = DEFAULT_MAX_VOICES:
	set(value):
		max_voices = clampi(value, 1, DEFAULT_MAX_VOICES)

## Optional duck target (MusicDirector). Null-safe duck calls.
var music_director: Object = null

var _voices: Array[AudioStreamPlayer] = []
var _voice_priority: Array[int] = []   # parallel to _voices
var _voice_start: Array[float] = []    # parallel to _voices (msec)
var _group_counts: Dictionary = {}     # StringName -> int
var _id_counts: Dictionary = {}        # StringName -> int
var _last_play_time: Dictionary = {}   # StringName -> float (msec)
var _group_caps: Dictionary = {}       # StringName -> int (data-driven)
var _playing_count: int = 0

func _ready() -> void:
	_build_pool()

## --- Pool ---

func _build_pool() -> void:
	if not _voices.is_empty():
		return
	for i in range(max_voices):
		var player := AudioStreamPlayer.new()
		player.name = "Voice_%d" % i
		player.bus = BusLayout.BUS_SFX
		add_child(player)
		_voices.append(player)
		_voice_priority.append(0)
		_voice_start.append(0.0)

## Sets a per-group concurrency cap (data-driven tuning lives in .tres).
func set_group_cap(group: StringName, cap: int) -> void:
	_group_caps[group] = cap

## --- Public API ---

## Plays a cataloged SFX. Returns the voice used, or null when skipped
## (missing stream, cooldown, group cap). Never throws.
func play(sfx_id: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	if library == null:
		push_warning("SFXPlayer.play('%s'): no SFXLibrary set, skipped." % sfx_id)
		return null
	var entry: Dictionary = library._entries.get(sfx_id, {}) as Dictionary
	if entry.is_empty():
		push_warning("SFXPlayer.play('%s'): unknown id, skipped." % sfx_id)
		return null
	# Cooldown gate (data-driven per id).
	var cooldown_s: float = float(entry.get("cooldown_s", 0.0))
	if cooldown_s > 0.0 and _on_cooldown(sfx_id, cooldown_s):
		return null
	var group: StringName = library.get_group(sfx_id)
	# Group concurrency cap.
	var group_cap: Variant = _group_caps.get(group, 0)
	if int(group_cap) > 0 and int(_group_counts.get(group, 0)) >= int(group_cap):
		return null
	# Per-id cap.
	var id_cap: int = int(entry.get("max_voices", 0))
	if id_cap > 0 and int(_id_counts.get(sfx_id, 0)) >= id_cap:
		return null
	var stream: AudioStream = library.get_stream(sfx_id)
	if stream == null:
		# Library already warned once; skip silently from here.
		return null
	var priority: int = library.get_priority(sfx_id)
	var voice: AudioStreamPlayer = _acquire_voice(priority)
	if voice == null:
		return null  # pool saturated (only possible if max_voices < 1)
	voice.stream = stream
	voice.bus = library.get_bus(sfx_id)
	var base_db: float = library.get_volume_db(sfx_id) + volume_db_offset
	voice.volume_db = base_db + _rand_volume()
	var pitch_rand: float = float(entry.get("pitch_rand", 1.0))
	voice.pitch_scale = clampf(1.0 + randf_range(-PITCH_RAND, PITCH_RAND) * pitch_rand, 0.1, 4.0)
	var idx: int = _voices.find(voice)
	_voice_priority[idx] = priority
	_voice_start[idx] = float(Time.get_ticks_msec())
	_group_counts[group] = int(_group_counts.get(group, 0)) + 1
	_id_counts[sfx_id] = int(_id_counts.get(sfx_id, 0)) + 1
	_last_play_time[sfx_id] = float(Time.get_ticks_msec())
	_playing_count += 1
	voice.play()
	voice.finished.connect(_on_voice_finished.bind(voice, sfx_id, group), Object.CONNECT_ONE_SHOT)
	return voice

## Current number of simultaneously playing voices (tests + budget checks).
func playing_voices() -> int:
	var n: int = 0
	for v: AudioStreamPlayer in _voices:
		if v.playing:
			n += 1
	return n

func stop_all() -> void:
	for v: AudioStreamPlayer in _voices:
		v.stop()

## --- Voice acquisition with stealing ---

func _acquire_voice(priority: int) -> AudioStreamPlayer:
	# 1) Free voice.
	for i in range(_voices.size()):
		if not _voices[i].playing:
			return _voices[i]
	# 2) Steal the lowest priority (oldest on ties).
	var victim: int = -1
	var victim_priority: int = priority
	for i in range(_voices.size()):
		if _voice_priority[i] < victim_priority:
			victim_priority = _voice_priority[i]
			victim = i
	if victim < 0:
		# Everything is at >= our priority: steal the oldest at our priority.
		var oldest: float = INF
		for i in range(_voices.size()):
			if _voice_priority[i] == victim_priority and _voice_start[i] < oldest:
				oldest = _voice_start[i]
				victim = i
	if victim >= 0:
		var victim_voice: AudioStreamPlayer = _voices[victim]
		victim_voice.stop()
		if victim_voice.finished.is_connected(_on_voice_finished):
			victim_voice.finished.disconnect(_on_voice_finished)
		_release_voice(victim)
		return victim_voice
	return null

func _release_voice(idx: int) -> void:
	_voice_priority[idx] = 0
	_voice_start[idx] = 0.0

func _on_voice_finished(voice: AudioStreamPlayer, sfx_id: StringName, group: StringName) -> void:
	var idx: int = _voices.find(voice)
	if idx >= 0:
		_release_voice(idx)
	_group_counts[group] = maxi(0, int(_group_counts.get(group, 0)) - 1)
	_id_counts[sfx_id] = maxi(0, int(_id_counts.get(sfx_id, 0)) - 1)
	_playing_count = maxi(0, _playing_count - 1)

## --- Helpers ---

func _on_cooldown(sfx_id: StringName, cooldown_s: float) -> bool:
	var last: float = float(_last_play_time.get(sfx_id, -INF))
	if last == -INF:
		return false
	return (float(Time.get_ticks_msec()) - last) < cooldown_s * 1000.0

func _rand_volume() -> float:
	return randf_range(-VOLUME_RAND_DB, VOLUME_RAND_DB)
