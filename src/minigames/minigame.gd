class_name Minigame
extends Node
## Base contract of EVERY micro-game (scaffold.md §7.1).
##
## The archetypes extend this class; the `.tres` definitions configure it.
## A micro-game NEVER references MatchManager, ScoreDirector or other
## systems directly: it uses the `MinigameContext` injected in `setup()`.
##
## Contract rules (§7.1):
## - A micro-game ends ONLY via `finished(result)` or an abort from the director.
## - It must be deterministic given the same `SeededRNG` and the same seed.
## - It must not leave orphan entities nor dirty global state.
## - The director calls `update()`/`on_input()`; do not use `_process` nor
##   `_physics_process` unless the archetype documents it explicitly.

## End of the micro-game. The only valid exit (besides the director's abort).
signal finished(result: MinigameResult)

## Normalized progress 0..1 for the auto-generated HUD (§13.1).
signal progress_changed(normalized: float)

## Hooks de juice/audio/VO: kind = "hit" | "miss" | "milestone" | "start" | ...
signal event(kind: StringName, payload: Dictionary)

var _ctx: MinigameContext = null
var _meta: MinigameMetadata = null
## True while start() has run and teardown() has not. Owned by the contract
## base so every archetype reads one flag (MinigameArchetype includes).
var _running: bool = false


# --- Lifecycle (the order is mandatory) ---

## Injection. No gameplay yet: read from the context.
## Archetypes extend MinigameArchetype, which overrides setup() and calls
## super.setup() on its way down, so this function runs on every micro-game.
## It therefore does its real job — store the injected context — and must not
## warn: a warning here would fire on every single micro-game of the match.
func setup(ctx: MinigameContext) -> void:
	_ctx = ctx
	if ctx != null:
		_meta = ctx.metadata


## Starts the micro-game: begin timers, spawn entities, request music.
## MinigameArchetype.start() implements the shared machinery and every
## archetype inherits it, so the contract base is not abstract here either.
func start() -> void:
	_running = true


## True while the micro-game is running (archetypes and the director read it).
func is_running() -> bool:
	return _running


## Logical frame. The director calls update(); do NOT use _process directly.
func update(delta: float) -> void:
	pass


## Raw input; each micro-game decides what it uses (keys, mouse, stick).
## `input_event` to avoid shadowing the contract's `event` signal.
func on_input(input_event: InputEvent) -> void:
	pass


## Clean teardown: return objects to the pool, switch off extra music,
## leave the world as it was found.
func teardown() -> void:
	pass


# --- Metadata ---

func get_metadata() -> MinigameMetadata:
	return _meta


# --- Read-only access to the context (for archetypes) ---

## Injected context. Null until the director calls setup().
func get_context() -> MinigameContext:
	return _ctx


## Ends the micro-game by emitting `finished`. Helper for archetypes.
func finish_with(result: MinigameResult) -> void:
	finished.emit(result)
