class_name MinigameContext
extends RefCounted
## Dependency injection for a micro-game (scaffold.md §7.2).
##
## ALL fields are NULLABLE: the director resolves them at the moment of
## injection and degrades silently if the system does not exist yet. A
## micro-game must check `if ctx.score != null` before using them.

# --- Systems (duck-typed; may be null) ---
var match_manager: Object = null   # MatchManager — time left, state
var score: Object = null           # ScoreDirector — add score
var style: Object = null           # StyleDirector — aplicar style packs
var impact: Object = null          # ImpactDirector — juice per impact
var camera: Object = null          # CameraDirector — shake/FOV
var postfx: Object = null          # PostFXDirector — efectos fullscreen
var audio: Object = null           # AudioDirector — buses/ducking
var music: Object = null           # MusicDirector — music states
var voice: Object = null           # VoiceDirector — arcade announcer
var player: Node3D = null          # player (CharacterBody3D)

# --- World ---
var world_root: Node3D = null      # parent to spawn entities in
var arena_center: Vector3 = Vector3.ZERO

# --- Micro-game identity ---
# The metadata travels in the context (§7.2): the director resolves it from
# the registry and injects it, so the archetype does NOT look it up itself.
var metadata: MinigameMetadata = null

# --- Determinism and scaling ---
var rng: Object = null             # deterministic SeededRNG per micro-game
var difficulty: float = 0.0        # 0..1, rises as the remaining time drops
var time_left_in_match: float = 0.0  # a micro-game must never exceed this


## Builds a context with the minimum values (useful in tests).
static func create(
	p_rng: Object = null,
	p_world_root: Node3D = null,
	p_arena_center: Vector3 = Vector3.ZERO,
	p_player: Node3D = null,
	p_difficulty: float = 0.0,
	p_time_left_in_match: float = 0.0
) -> MinigameContext:
	var ctx := MinigameContext.new()
	ctx.rng = p_rng
	ctx.world_root = p_world_root
	ctx.arena_center = p_arena_center
	ctx.player = p_player
	ctx.difficulty = p_difficulty
	ctx.time_left_in_match = p_time_left_in_match
	return ctx


## Discards the context and its references. The director calls it after teardown.
func clear() -> void:
	match_manager = null
	score = null
	style = null
	impact = null
	camera = null
	postfx = null
	audio = null
	music = null
	voice = null
	player = null
	world_root = null
	rng = null
