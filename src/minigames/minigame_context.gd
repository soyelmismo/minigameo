class_name MinigameContext
extends RefCounted
## Inyección de dependencias de un micro-juego (scaffold.md §7.2).
##
## TODOS los campos son NULLABLES: el director los resuelve en el momento de
## la inyección y degrada en silencio si el sistema no existe todavía. Un
## micro-juego debe comprobar `if ctx.score != null` antes de usarlos.

# --- Sistemas (duck-typed; pueden ser null) ---
var match_manager: Object = null   # MatchManager — tiempo restante, estado
var score: Object = null           # ScoreDirector — añadir puntuación
var style: Object = null           # StyleDirector — aplicar style packs
var impact: Object = null          # ImpactDirector — juice por impacto
var camera: Object = null          # CameraDirector — shake/FOV
var postfx: Object = null          # PostFXDirector — efectos fullscreen
var audio: Object = null           # AudioDirector — buses/ducking
var music: Object = null           # MusicDirector — estados musicales
var voice: Object = null           # VoiceDirector — locutor arcade
var player: Node3D = null          # jugador (CharacterBody3D)

# --- Mundo ---
var world_root: Node3D = null      # padre para spawnear entidades
var arena_center: Vector3 = Vector3.ZERO

# --- Determinismo y escalado ---
var rng: Object = null             # SeededRNG determinista por micro-juego
var difficulty: float = 0.0        # 0..1, sube con el tiempo restante bajo
var time_left_in_match: float = 0.0  # el micro-juego nunca debe exceder esto


## Construye un contexto con los valores mínimos (útil en tests).
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


## Descarta el contexto y sus referencias. El director lo llama tras teardown.
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
