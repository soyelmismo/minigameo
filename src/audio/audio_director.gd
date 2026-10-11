extends Node
## Audio orchestrator (scaffold.md §6.8 / §10.2).
##
## Responsibilities:
## - Registers the §10.2 bus layout in code, IDEMPOTENTLY (safe to call
##   twice; safe when the layout already exists from a previous session).
## - Master limiter + music/VO compressors (graceful degradation: effect
##   creation failures are logged, never fatal).
## - Owns SFXLibrary / SFXPlayer / MusicDirector / VoiceDirector wiring.
## - Facade API: play_sfx(id), play_voice(event_id), duck(amount, duration).
##
## No audio assets exist yet: every play path handles null/missing streams
## with a log + skip. Nothing here ever throws.
##
## Cross-system isolation (AGENTS.md §1.1): no direct autoload references.
## Services are resolved duck-typed via GameServices when available and the
## calls degrade silently otherwise.

## --- Bus layout effects (scaffold §10.2) ---
## Master: Limiter (ceiling -1 dB, soft clip).
const MASTER_LIMITER_CEILING_DB: float = -1.0
const MASTER_LIMITER_THRESHOLD_DB: float = -2.0
const MASTER_LIMITER_SOFT_CLIP_DB: float = 2.0
## Music: Compressor (moderate glue) + EQ (gentle high-shelf for clarity).
const MUSIC_COMP_THRESHOLD_DB: float = -18.0
const MUSIC_COMP_RATIO: float = 3.0
const MUSIC_COMP_ATTACK_MS: float = 10.0
const MUSIC_COMP_RELEASE_MS: float = 250.0
const MUSIC_COMP_MAKEUP_DB: float = 2.0
## VO: Compressor with higher ratio (locutor always intelligible).
const VO_COMP_THRESHOLD_DB: float = -20.0
const VO_COMP_RATIO: float = 4.0
const VO_COMP_ATTACK_MS: float = 5.0
const VO_COMP_RELEASE_MS: float = 150.0
const VO_COMP_MAKEUP_DB: float = 3.0
## SFX: Limiter (protect the mix from stacked one-shots).
const SFX_LIMITER_CEILING_DB: float = -1.0
const SFX_LIMITER_THRESHOLD_DB: float = -3.0
const SFX_LIMITER_SOFT_CLIP_DB: float = 3.0

var sfx_library: SFXLibrary = null
var sfx_player: SFXPlayer = null
var music_director: MusicDirector = null
var voice_director: VoiceDirector = null

var _buses_ready: bool = false

func _ready() -> void:
	sfx_library = SFXLibrary.new()
	_register_service()
	setup_buses()
	# Child directors (MusicDirector, VoiceDirector, SFXPlayer) are added as
	# children in the scene graph by the orchestrator; if they are missing
	# (headless tests), create minimal instances so the facade works.
	if music_director == null:
		music_director = load("res://src/audio/music_director.gd").new()
		music_director.name = "MusicDirector"
		add_child(music_director)
	if voice_director == null:
		voice_director = load("res://src/audio/voice_director.gd").new()
		voice_director.name = "VoiceDirector"
		add_child(voice_director)
	if sfx_player == null:
		sfx_player = load("res://src/audio/sfx_player.gd").new()
		sfx_player.name = "SFXPlayer"
		add_child(sfx_player)
	# Wire directors (duck-typed; null-safe both ways).
	sfx_player.library = sfx_library
	sfx_player.music_director = music_director
	voice_director.setup(VoiceLines.new())
	voice_director.music_director = music_director
	# Subscribe to canonical EventBus events when the bus exists.
	_connect_event_bus()

## --- Bus layout (idempotent) ---

## Registers the §10.2 layout. Safe to call any number of times:
## checks AudioServer.get_bus_index() before add_bus(). Returns the number
## of buses that already existed (0 = fresh registration).
func setup_buses() -> int:
	var existing: int = 0
	for entry: Dictionary in BusLayout.LAYOUT:
		var bus_id: StringName = entry["name"] as StringName
		var parent: StringName = entry["parent"] as StringName
		if AudioServer.get_bus_index(bus_id) != -1:
			existing += 1
			continue
		var parent_idx: int = AudioServer.get_bus_index(parent)
		if parent_idx == -1:
			push_warning("AudioDirector: parent bus '%s' missing, skipping '%s'." % [parent, bus_id])
			continue
		var new_idx: int = AudioServer.bus_count
		AudioServer.add_bus(new_idx)
		AudioServer.set_bus_name(new_idx, bus_id)
		AudioServer.set_bus_send(new_idx, parent)
	_buses_ready = existing == BusLayout.LAYOUT.size()
	_apply_bus_effects()
	return existing

func buses_ready() -> bool:
	return _buses_ready

## Applies the per-bus effects from §10.2. Also idempotent: effects are
## added by checking effect_index() first; failures degrade to a warning.
func _apply_bus_effects() -> void:
	_add_effect(BusLayout.BUS_MASTER, AudioEffectLimiter.new(), {
		"ceiling_db": MASTER_LIMITER_CEILING_DB,
		"threshold_db": MASTER_LIMITER_THRESHOLD_DB,
		"soft_clip_db": MASTER_LIMITER_SOFT_CLIP_DB,
	})
	_add_effect(BusLayout.BUS_MUSIC, AudioEffectCompressor.new(), {
		"threshold": MUSIC_COMP_THRESHOLD_DB,
		"ratio": MUSIC_COMP_RATIO,
		"attack_ms": MUSIC_COMP_ATTACK_MS,
		"release_ms": MUSIC_COMP_RELEASE_MS,
		"makeup": MUSIC_COMP_MAKEUP_DB,
	})
	_add_effect(BusLayout.BUS_MUSIC, AudioEffectEQ6.new(), {})
	_add_effect(BusLayout.BUS_VO, AudioEffectCompressor.new(), {
		"threshold": VO_COMP_THRESHOLD_DB,
		"ratio": VO_COMP_RATIO,
		"attack_ms": VO_COMP_ATTACK_MS,
		"release_ms": VO_COMP_RELEASE_MS,
		"makeup": VO_COMP_MAKEUP_DB,
	})
	_add_effect(BusLayout.BUS_SFX, AudioEffectLimiter.new(), {
		"ceiling_db": SFX_LIMITER_CEILING_DB,
		"threshold_db": SFX_LIMITER_THRESHOLD_DB,
		"soft_clip_db": SFX_LIMITER_SOFT_CLIP_DB,
	})

## Adds an effect to a bus unless an effect of that type is already there.
func _add_effect(bus_name: StringName, effect: AudioEffect, params: Dictionary) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i).get_class() == effect.get_class():
			return
	for key: String in params:
		effect.set(key, params[key])
	AudioServer.add_bus_effect(idx, effect)

## --- Facade API (scaffold §6.8) ---

## Plays a cataloged SFX. Never throws; returns the voice or null.
func play_sfx(sfx_id: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer:
	if sfx_player == null:
		push_warning("AudioDirector.play_sfx('%s'): no SFXPlayer, skipped." % sfx_id)
		return null
	return sfx_player.play(sfx_id, volume_db_offset)

## Requests a VO line for an event id. Never throws.
func play_voice(event_id: StringName) -> bool:
	if voice_director == null:
		push_warning("AudioDirector.play_voice('%s'): no VoiceDirector, skipped." % event_id)
		return false
	return voice_director.speak(event_id)

## Sidechain duck (VO / impacts). amount_db negative, duration_s > 0.
func duck(amount_db: float, duration_s: float) -> void:
	if music_director == null:
		return
	music_director.duck(amount_db, duration_s)

## Music state + intensity facade.
func play_music_state(state: StringName, intensity: float = -1.0) -> void:
	if music_director == null:
		return
	music_director.play_music_state(state, intensity)

## --- Service registration (duck-typed; GameServices is optional) ---

func _register_service() -> void:
	var services: Object = _resolve_services()
	if services == null:
		return
	if services.has_method("register"):
		services.call("register", &"AudioDirector", self)

func _connect_event_bus() -> void:
	var bus: Object = _resolve_event_bus()
	if bus == null:
		return
	# voice_requested(event_id) -> VoiceDirector (§6.1 canonical signal).
	if bus.has_signal("voice_requested") and voice_director != null:
		bus.connect("voice_requested", Callable(voice_director, "speak"))
	# Match events -> announcer lines. The mapping lives in VoiceDirector,
	# next to its cooldown/priority policy (§6.10, §5).
	if voice_director != null and voice_director.has_method("connect_match_events"):
		voice_director.connect_match_events()

## Duck-typed service locator lookup; returns null when absent.
func _resolve_services() -> Object:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	var node: Node = root.get_node_or_null(^"GameServices")
	return node as Object

func _resolve_event_bus() -> Object:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	var node: Node = root.get_node_or_null(^"EventBus")
	return node as Object
