class_name Minigame
extends Node
## Contrato base de TODO micro-juego (scaffold.md §7.1).
##
## Los arquetipos extienden esta clase; las definiciones `.tres` la configuran.
## Un micro-juego NUNCA referencia MatchManager, ScoreDirector ni otros
## sistemas directamente: usa el `MinigameContext` inyectado en `setup()`.
##
## Reglas del contrato (§7.1):
## - Un micro-juego termina SOLO vía `finished(result)` o aborto del director.
## - Debe ser determinista dado el mismo `SeededRNG` y la misma semilla.
## - No debe dejar entidades huérfanas ni estados globales sucios.
## - El director llama a `update()`/`on_input()`; no usar `_process` ni
##   `_physics_process` salvo que el arquetipo lo documente explícitamente.

## Fin del micro-juego. Única salida válida (además del aborto del director).
signal finished(result: MinigameResult)

## Progreso normalizado 0..1 para el HUD auto-generado (§13.1).
signal progress_changed(normalized: float)

## Hooks de juice/audio/VO: kind = "hit" | "miss" | "milestone" | "start" | ...
signal event(kind: StringName, payload: Dictionary)

var _ctx: MinigameContext = null
var _meta: MinigameMetadata = null
## True while start() has run and teardown() has not. Owned by the contract
## base so every archetype reads one flag (MinigameArchetype includes).
var _running: bool = false


# --- Ciclo de vida (obligatorio respetar el orden) ---

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


## Frame lógico. El director llama a update(); NO usar _process directo.
func update(delta: float) -> void:
	pass


## Entrada cruda; cada micro-juego decide qué usa (teclas, ratón, stick).
## `input_event` para no ensombrecer la señal `event` del contrato.
func on_input(input_event: InputEvent) -> void:
	pass


## Cierre limpio: devolver objetos al pool, apagar música extra,
## dejar el mundo como se encontró.
func teardown() -> void:
	pass


# --- Metadata ---

func get_metadata() -> MinigameMetadata:
	return _meta


# --- Acceso de solo lectura al contexto (para arquetipos) ---

## Contexto inyectado. Null hasta que el director llame a setup().
func get_context() -> MinigameContext:
	return _ctx


## Cierra el micro-juego emitiendo `finished`. Helper para arquetipos.
func finish_with(result: MinigameResult) -> void:
	finished.emit(result)
