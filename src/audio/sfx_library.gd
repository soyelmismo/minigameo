class_name SFXLibrary
extends RefCounted
## Data-driven SFX catalog (scaffold.md §10.2).
## NO audio assets exist yet: every entry is stream-optional. A play request
## for a missing/null stream is warned once and skipped — never a crash.
##
## Entry shape (all fields optional except id):
##   id        -> StringName
##   path      -> String (res:// path; "" = no asset yet)
##   group     -> StringName (player|world|ui|impact|voice; default "world")
##   priority  -> int (higher = more important, survives voice stealing)
##   volume_db -> float (default 0.0)
##   pitch_rand-> float (0..1, fraction of the global ±5% randomization)
##   max_voices-> int (per-id concurrency cap; <=0 = use the group cap)
##   cooldown_s-> float (min seconds between two plays of this id)
##   bus       -> StringName (explicit bus override; default: group routing)

const DEFAULT_VOLUME_DB: float = 0.0
const DEFAULT_PRIORITY: int = 0

var _entries: Dictionary = {}     # StringName -> Dictionary
var _cache: Dictionary = {}       # StringName -> Variant (AudioStream | null)
var _warned_missing: Dictionary = {}  # StringName -> true (log once per id)

## --- Catalog population (data-driven) ---

func register(sfx_id: StringName, entry: Dictionary) -> void:
	_entries[sfx_id] = entry

func clear() -> void:
	_entries.clear()
	_cache.clear()
	_warned_missing.clear()

func has(sfx_id: StringName) -> bool:
	return _entries.has(sfx_id)

func ids() -> Array:
	var out: Array = []
	for key: StringName in _entries:
		out.append(key)
	return out

## --- Entry accessors (safe defaults for missing fields) ---

func get_path(sfx_id: StringName) -> String:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	return String(entry.get("path", ""))

func get_group(sfx_id: StringName) -> StringName:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	return entry.get("group", &"world") as StringName

func get_priority(sfx_id: StringName) -> int:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	return int(entry.get("priority", DEFAULT_PRIORITY))

func get_volume_db(sfx_id: StringName) -> float:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	return float(entry.get("volume_db", DEFAULT_VOLUME_DB))

func get_bus(sfx_id: StringName) -> StringName:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	if entry.has("bus"):
		return entry["bus"] as StringName
	return BusLayout.bus_for_group(get_group(sfx_id))

func get_cooldown_s(sfx_id: StringName) -> float:
	var entry: Dictionary = _entries.get(sfx_id, {}) as Dictionary
	return float(entry.get("cooldown_s", 0.0))

## --- Stream resolution (null-safe, cached, never throws) ---

## Returns the AudioStream for an id, or null when the asset is missing.
## A missing stream is warned about ONCE per id (no log spam).
func get_stream(sfx_id: StringName) -> AudioStream:
	if _cache.has(sfx_id):
		var cached: Variant = _cache[sfx_id]
		if cached == null:
			return null
		return cached as AudioStream
	var path: String = get_path(sfx_id)
	if path.is_empty():
		_warn_once(sfx_id, "no path registered")
		_cache[sfx_id] = null
		return null
	if not ResourceLoader.exists(path):
		_warn_once(sfx_id, "asset not found: %s" % path)
		_cache[sfx_id] = null
		return null
	var res: Resource = load(path)
	if res == null or not (res is AudioStream):
		_warn_once(sfx_id, "asset is not an AudioStream: %s" % path)
		_cache[sfx_id] = null
		return null
	var stream: AudioStream = res as AudioStream
	_cache[sfx_id] = stream
	return stream

## Test/tooling hook: injects a stream directly into the resolution cache
## (used to exercise pooling/stealing without real audio assets).
func set_stream(sfx_id: StringName, stream: AudioStream) -> void:
	_cache[sfx_id] = stream

func _warn_once(sfx_id: StringName, reason: String) -> void:
	if _warned_missing.has(sfx_id):
		return
	_warned_missing[sfx_id] = true
	push_warning("SFXLibrary: '%s' skipped (%s). No audio assets exist yet." % [sfx_id, reason])
