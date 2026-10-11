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


# --- Ciclo de vida (obligatorio respetar el orden) ---

## Inyección. Sin gameplay todavía. Leer del contexto.
func setup(ctx: MinigameContext) -> void:
	_ctx = ctx
	push_warning("%s: setup() no implementado" % get_script().resource_path)


## Comienza el micro-juego: arrancar timers, spawnear entidades, pedir música.
func start() -> void:
	push_error("%s: start() no implementado" % get_script().resource_path)


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
	push_error("%s: get_metadata() no implementado" % get_script().resource_path)
	return null


# --- Acceso de solo lectura al contexto (para arquetipos) ---

## Contexto inyectado. Null hasta que el director llame a setup().
func get_context() -> MinigameContext:
	return _ctx


## Cierra el micro-juego emitiendo `finished`. Helper para arquetipos.
func finish_with(result: MinigameResult) -> void:
	finished.emit(result)
