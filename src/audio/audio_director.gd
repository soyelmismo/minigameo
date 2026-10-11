extends Node
## Audio orchestrator (scaffold.md §6.8 / §10.2).
##
## Responsibilities:
## - Registers the §10.2 bus layout in code, IDEMPOTENTLY (safe to call
##   twice; safe when the layout already exists from a previous session).
## - Master limiter + music/VO compressors + the Ambience reverb send
##   (graceful degradation: effect creation failures are logged, never fatal).
## - ADOPTS the MusicDirector / VoiceDirector / SFXPlayer autoloads instead
##   of creating duplicates: a second MusicDirector would play the stems a
##   second time, and the duck target would sit on a different instance than
##   the state machine (the historical split brain).
## - Owns the SFX catalog defaults (SFXLibrary.DEFAULT_CATALOG) + group caps
##   and the ambience bed under the whole mix.
## - Drives the dynamic music ladder from the match events (§6.9): calm in
##   freeroam, rising with the combo, TENSION on the roulette and the last
##   30 s, the micro-game's own state while it runs, FAIL on a failed
##   micro-game, TRIUMPH at TIME_UP. The micro-game state itself is
##   requested by MinigameDirector on the MusicDirector autoload (§10.2).
## - Facade API: play_sfx(id), play_voice(event_id), duck(amount, duration).
##
## Every play path handles null/missing streams with a log + skip. Nothing
## here ever throws.
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

## --- Ambience bed (§10.2: "Ambience (Reverb send)", under everything) ---
const AMBIENCE_PATH := "res://assets/audio/ambience/amb_city_loop.wav"
## Measured bed RMS ~0.12 against a drums bed of ~0.22: -14 dB keeps the
## city ~14 dB under the music so it never masks it, while staying present.
const AMBIENCE_VOLUME_DB: float = -14.0
## Modest room send: a street, not a cathedral.
const AMBIENCE_REVERB: Dictionary = {
	"room_size": 0.55,
	"damping": 0.5,
	"spread": 0.5,
	"hipass": 220.0,
	"wet": 0.18,
	"dry": 1.0,
}

## --- Music ladder policy (scaffold §6.9 / §10.2; data, §1.3) ---
## Freeroam is CALM; the combo raises the intensity inside the CALM band
## (0.15 + step per combo, capped below the bass gate), and the last
## seconds of the match escalate to TENSION.
const FREEROAM_BASE_INTENSITY: float = 0.15
const FREEROAM_COMBO_STEP: float = 0.05
const FREEROAM_COMBO_CAP: float = 0.35
## Roulette and the last-30s warning share the TENSION riser.
const TENSION_INTENSITY: float = 0.65
const ENDGAME_TIME_LEFT_S: float = 30.0
## A failed micro-game drops to FAIL and resumes the base tier after this.
const FAIL_STINGER_S: float = 2.5
## TRIUMPH at TIME_UP: the celebration, then the results screen.
const TRIUMPH_INTENSITY: float = 0.85
## Impact ducking by weight (audible, never excessive; VO ducking is
## VoiceDirector's -10 dB with its own release). Weight: L/M/H/CRIT = 0..3.
const IMPACT_SFX_BY_WEIGHT: Array[StringName] = [
	&"sfx_impact_light",
	&"sfx_impact_medium",
	&"sfx_impact_heavy",
	&"sfx_impact_critical",
]
const IMPACT_DUCK_BY_WEIGHT: Array[Dictionary] = [
	{"db": 0.0, "hold": 0.0},
	{"db": -4.0, "hold": 0.30},
	{"db": -6.0, "hold": 0.35},
	{"db": -8.0, "hold": 0.45},
]

var sfx_library: SFXLibrary = null
var sfx_player: SFXPlayer = null
var music_director: MusicDirector = null
var voice_director: VoiceDirector = null
var ambience_player: AudioStreamPlayer = null

var _buses_ready: bool = false
## True while a micro-game owns the music state: the freeroam tiers (combo,
## match ticks) must not fight the micro-game's own music_state.
var _minigame_music: bool = false
## True once the last-30s TENSION escalation has fired.
var _endgame_tension: bool = false
var _fail_resume: Timer = null
## One wiring per process: the autoload connects first, and additional
## instances (tests) must not duplicate the subscriptions.
static var _ladder_events_connected: bool = false

func _ready() -> void:
	sfx_library = SFXLibrary.new()
	sfx_library.register_defaults()
	_register_service()
	setup_buses()
	# FAIL -> base-track resume timer (the announcer roasts over FAIL first).
	_fail_resume = Timer.new()
	_fail_resume.one_shot = true
	_fail_resume.timeout.connect(_on_fail_resume_timeout)
	add_child(_fail_resume)
	# Child directors: adopt the autoload instances when they are already in
	# the tree; otherwise create minimal stand-ins (headless tests without
	# autoloads) so the facade still works.
	_adopt_directors()
	_wire_facade()
	# Subscribe to canonical EventBus events when the bus exists.
	_connect_event_bus()
	# Autoload order (project.godot): AudioDirector is declared BEFORE its
	# directors, so at _ready() time the autoload instances may not be in
	# the tree yet. The deferred pass swaps the stand-ins for the singletons
	# and re-wires the facade.
	call_deferred("_adopt_autoloads")

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
	# §10.2 bus tree: "Ambience (Reverb send)".
	_add_effect(BusLayout.BUS_AMBIENCE, AudioEffectReverb.new(), AMBIENCE_REVERB)

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

## --- Director adoption (one instance per process) ---

func _adopt_directors() -> void:
	if music_director == null:
		music_director = _adopt_director(&"MusicDirector", "res://src/audio/music_director.gd") as MusicDirector
	if voice_director == null:
		voice_director = _adopt_director(&"VoiceDirector", "res://src/audio/voice_director.gd") as VoiceDirector
	if sfx_player == null:
		sfx_player = _adopt_director(&"SFXPlayer", "res://src/audio/sfx_player.gd") as SFXPlayer

## Returns the running autoload instance when it is already in the tree,
## otherwise a stand-in child (headless, no autoloads) so the facade works.
func _adopt_director(node_name: StringName, script_path: String) -> Object:
	var found: Node = _node_in_tree(node_name)
	if found != null:
		return found as Object
	var made: Object = load(script_path).new()
	made.name = String(node_name)
	add_child(made)
	return made

func _node_in_tree(node_name: StringName) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var root: Node = tree.root
	if root == null:
		return null
	return root.get_node_or_null(String(node_name))

## Deferred pass (runs after every autoload exists): swap the stand-ins for
## the autoload singletons and re-wire, so exactly one instance of each
## director exists and the duck target IS the instance playing the music.
func _adopt_autoloads() -> void:
	for pair: Array in [
		[&"MusicDirector", "music_director"],
		[&"VoiceDirector", "voice_director"],
		[&"SFXPlayer", "sfx_player"],
	]:
		var autoload: Node = _node_in_tree(pair[0])
		if autoload == null:
			continue
		var current: Object = get(String(pair[1]))
		if current == autoload:
			continue
		set(String(pair[1]), autoload)
		if current is Node and is_instance_valid(current) and (current as Node).get_parent() == self:
			(current as Node).queue_free()
	_wire_facade()

## --- Facade wiring ---

func _wire_facade() -> void:
	if sfx_player != null:
		sfx_player.library = sfx_library
		for group: StringName in SFXLibrary.DEFAULT_GROUP_CAPS:
			sfx_player.set_group_cap(group, int(SFXLibrary.DEFAULT_GROUP_CAPS[group]))
	if voice_director != null:
		voice_director.setup(VoiceLines.new())
		voice_director.music_director = music_director
		voice_director.connect_match_events()
	if sfx_player != null:
		sfx_player.music_director = music_director
	_setup_ambience()

## The ambience bed: a looped, low, looping city bed on the Ambience bus
## (reverb send). It sits under music, SFX and VO for the whole session.
func _setup_ambience() -> void:
	if ambience_player != null and is_instance_valid(ambience_player):
		return
	var player := AudioStreamPlayer.new()
	player.name = AMBIENCE_PATH.get_file().get_basename()
	player.bus = BusLayout.BUS_AMBIENCE
	player.volume_db = AMBIENCE_VOLUME_DB
	add_child(player)
	ambience_player = player
	player.stream = _load_optional(AMBIENCE_PATH)
	if player.stream != null:
		player.play()
	else:
		push_warning("AudioDirector: ambience loop missing at %s; the city bed is silent." % AMBIENCE_PATH)

func _load_optional(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res as AudioStream
	return null

func _start_ambience() -> void:
	if ambience_player != null and ambience_player.stream != null and not ambience_player.playing:
		ambience_player.play()

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

## Ambience volume as data (settings sliders retune the bed).
func set_ambience_volume_db(db: float) -> void:
	if ambience_player != null:
		ambience_player.volume_db = db

func ambience_volume_db() -> float:
	return ambience_player.volume_db if ambience_player != null else 0.0

func play_ambience() -> void:
	_start_ambience()

func stop_ambience() -> void:
	if ambience_player != null:
		ambience_player.stop()

## --- Service registration (duck-typed; GameServices is optional) ---

func _register_service() -> void:
	# One name, one way in: &"audio". publish() refuses anything that is not the
	# live singleton, so a test double built from this script cannot clobber the
	# real service. (A second autoload-style alias used to be registered here;
	# nothing ever resolved it, which made it a dead registration.)
	GameServices.publish("AudioDirector", &"audio", self)

func _connect_event_bus() -> void:
	var bus: Object = _resolve_event_bus()
	if bus == null:
		return
	if _ladder_events_connected:
		return
	_ladder_events_connected = true
	# voice_requested(event_id) -> VoiceDirector (§6.1 canonical signal).
	var voice_signal: String = EventBus.signal_name_for(&"voice_requested")
	if voice_signal != "" and bus.has_signal(voice_signal) and voice_director != null:
		bus.connect(voice_signal, Callable(voice_director, "speak"))
	# The dynamic music ladder (§6.9): the micro-game's own music_state is
	# requested by MinigameDirector on the MusicDirector autoload; this
	# facade owns the transitions that chain does NOT cover — the freeroam
	# tiers (calm, combo, last 30 s), the roulette riser, the base-track
	# resume after a micro-game, and TRIUMPH at TIME_UP. Every subscription
	# is has_signal-guarded so a bus change degrades one rung, never a crash.
	_connect_ladder(bus, "_on_roulette_started")
	_connect_ladder(bus, "_on_minigame_started")
	_connect_ladder(bus, "_on_minigame_finished")
	_connect_ladder(bus, "_on_combo_changed")
	_connect_ladder(bus, "_on_match_tick")
	_connect_ladder(bus, "_on_match_started")
	_connect_ladder(bus, "_on_match_time_up")
	_connect_ladder(bus, "_on_impact_requested")

## Connects one ladder handler if (and only if) the bus declares the
## canonical signal: a missing rung is warned once and the rest of the
## ladder stands. The signal name is DERIVED from the handler name
## ("_on_match_tick" -> "match_tick") through EventBus.signal_name_for(),
## so the canonical mapping has exactly one home (event_bus.gd).
func _connect_ladder(bus: Object, method: String) -> void:
	var event_id: StringName = StringName(method.trim_prefix("_on_"))
	var signal_name: String = EventBus.signal_name_for(event_id)
	if signal_name == "" or not bus.has_signal(signal_name):
		push_warning("AudioDirector: EventBus has no '%s' signal; that ladder rung is skipped." % event_id)
		return
	bus.connect(signal_name, Callable(self, method))

## --- Ladder handlers (scaffold §6.9) ---

func _on_match_started() -> void:
	_minigame_music = false
	_endgame_tension = false
	_stop_fail_resume()
	# A fresh match starts at the calm floor of the ladder.
	if music_director != null:
		music_director.play_music_state(MusicDirector.STATE_CALM, FREEROAM_BASE_INTENSITY)
	_start_ambience()

func _on_match_tick(time_left: float) -> void:
	if _minigame_music or music_director == null:
		return  # a micro-game owns the music right now
	if time_left > 0.0 and time_left <= ENDGAME_TIME_LEFT_S:
		# The last 30 s escalate to TENSION (once; the ladder holds).
		if not _endgame_tension:
			_endgame_tension = true
			music_director.play_music_state(MusicDirector.STATE_TENSION, TENSION_INTENSITY)
		return
	_endgame_tension = false
	_apply_freeroam_tier(0)

func _on_combo_changed(combo: int) -> void:
	if _minigame_music or _endgame_tension:
		return
	_apply_freeroam_tier(combo)

## Freeroam = CALM whose intensity rises with the combo (0.15 -> 0.50 cap,
## still inside the CALM band: drums, then bass). The micro-game and the
## roulette take the state up from there.
func _apply_freeroam_tier(combo: int = 0) -> void:
	if music_director == null:
		return
	var tier: float = minf(
		FREEROAM_BASE_INTENSITY + float(maxi(combo, 0)) * FREEROAM_COMBO_STEP,
		FREEROAM_BASE_INTENSITY + FREEROAM_COMBO_CAP
	)
	music_director.play_music_state(MusicDirector.STATE_CALM, tier)

func _on_roulette_started() -> void:
	# The riser: whatever the wheel lands on, the moment feels bigger.
	if music_director == null:
		return
	music_director.play_music_state(MusicDirector.STATE_TENSION, TENSION_INTENSITY)

func _on_minigame_started(_minigame_id: StringName) -> void:
	# MinigameDirector already requested meta.music_state on the
	# MusicDirector autoload (§10.2). Lock the freeroam tiers so combo and
	# match ticks cannot fight the micro-game's music while it runs.
	_minigame_music = true
	_stop_fail_resume()

func _on_minigame_finished(result: MinigameResult) -> void:
	_minigame_music = false
	_endgame_tension = false
	_stop_fail_resume()
	if music_director == null:
		return
	if result != null and not result.success:
		# FAIL holds over austere drums+bass while the announcer roasts,
		# then the base track resumes (resolve cleanly, never a hard cut).
		music_director.play_music_state(MusicDirector.STATE_FAIL)
		_fail_resume.start(FAIL_STINGER_S)
		return
	_apply_freeroam_tier(0)

func _on_fail_resume_timeout() -> void:
	_apply_freeroam_tier(0)

func _on_match_time_up() -> void:
	_stop_fail_resume()
	if music_director == null:
		return
	music_director.play_music_state(MusicDirector.STATE_TRIUMPH, TRIUMPH_INTENSITY)

func _on_impact_requested(weight: int) -> void:
	# §10.1: every impact gets its audio tier; heavier impacts also dip the
	# music momentarily (audible, never excessive).
	var tier: int = clampi(weight, 0, IMPACT_SFX_BY_WEIGHT.size() - 1)
	play_sfx(IMPACT_SFX_BY_WEIGHT[tier])
	if music_director == null:
		return
	var duck_params: Variant = IMPACT_DUCK_BY_WEIGHT[tier]
	if duck_params == null:
		return
	var params: Dictionary = duck_params as Dictionary
	var amount: float = float(params.get("db", 0.0))
	var hold: float = float(params.get("hold", 0.0))
	if amount < 0.0 and hold > 0.0:
		music_director.duck(amount, hold)

func _stop_fail_resume() -> void:
	if _fail_resume != null and not _fail_resume.is_stopped():
		_fail_resume.stop()

## --- Duck-typed lookups (null-safe) ---

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
