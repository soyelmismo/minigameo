class_name MinigameArchetype
extends Minigame
## Base compartida por los 14 arquetipos (scaffold.md §8.1, §8.3).
##
## Centraliza la maquinaria repetida —timer de duración, progreso, emisión de
## eventos de juice, spawns según `SpawnRecipe`, limpieza huérfana— para que
## cada arquetipo solo declare su MECÁNICA leyendo sus slots. Ningún arquetipo
## hace `if minigame_id == "..."`: la variación vive en los datos.

# --- Patrones de spawn (§7.3.1) ---
const PATTERN_SCATTER := &"SCATTER"
const PATTERN_RING := &"RING"
const PATTERN_GRID := &"GRID"
const PATTERN_LINE := &"LINE"
const PATTERN_WAVE := &"WAVE"

# --- Movimientos (§7.3.1) ---
const MOTION_STATIC := &"STATIC"
const MOTION_ORBIT := &"ORBIT"
const MOTION_FLEE := &"FLEE"
const MOTION_CHASE := &"CHASE"
const MOTION_FALL := &"FALL"

var _duration: float = 20.0
var _elapsed: float = 0.0
var _finished: bool = false
var _combo_max: int = 0

## Nodos creados por el micro-juego. El director los libera en teardown,
## pero el arquetipo también sabe liberarlos solo (defensa en profundidad).
var _spawned: Array[Node] = []


# --- Ciclo de vida ---

func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	# La metadata llega por el contexto (§7.2); solo si falta se busca.
	_meta = ctx.metadata if ctx != null and ctx.metadata != null else get_metadata()
	_duration = _meta.duration_s if _meta != null else 20.0
	_elapsed = 0.0
	_combo_max = 0
	_finished = false


func start() -> void:
	_running = true
	emit_event(&"start", {"duration_s": _duration})


## Avanza el reloj del micro-juego y delega en el arquetipo.
## Devuelve true si el arquetipo consumió el frame.
func update(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	advance(delta)
	if _elapsed >= _duration and not _finished:
		on_timeout()


# --- API para arquetipos ---

## Un paso de mecánica específica. Implementado por cada arquetipo.
func advance(_delta: float) -> void:
	pass


## Acción por defecto al agotarse `duration_s`. Los arquetipos con éxito por
## supervivencia la sobreescriben.
func on_timeout() -> void:
	finish_fail(&"TIMEOUT")


## Tiempo consumido.
func get_elapsed() -> float:
	return _elapsed


## Tiempo restante del micro-juego (nunca negativo).
func get_time_left() -> float:
	return maxf(0.0, _duration - _elapsed)


func is_running() -> bool:
	return _running


func is_finished() -> bool:
	return _finished


## Marca un nuevo máximo de combo y emite el evento de milestone.
func bump_combo() -> int:
	_combo_max += 1
	emit_event(&"hit", {"combo": _combo_max})
	return _combo_max


## Emite progreso normalizado 0..1 por la señal del contrato (§7.1).
func set_progress(normalized: float) -> void:
	progress_changed.emit(clampf(normalized, 0.0, 1.0))


## Emite un hook de juice/audio/VO (§7.1 signal `event`).
func emit_event(kind: StringName, payload: Dictionary = {}) -> void:
	event.emit(kind, payload)


## Cierra el micro-juego con éxito, calculando el bonus de tiempo sobrante.
func finish_success(time_bonus_per_s: int = 0) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	var bonus: int = int(round(get_time_left() * float(time_bonus_per_s)))
	var base: int = _meta.base_score if _meta != null else 0
	emit_event(&"success", {"time_left": get_time_left()})
	finish_with(MinigameResult.make(true, base, bonus, _combo_max))


## Cierra el micro-juego con fracaso (`fail_on` del ObjectiveRecipe).
func finish_fail(reason: StringName) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	emit_event(&"fail", {"reason": String(reason)})
	finish_with(MinigameResult.make(false, 0, 0, _combo_max, reason))


# --- Spawning (motor genérico, reutilizado por todos los arquetipos) ---

## Posición de spawn según el patrón declarado en el SpawnRecipe.
## Determinista: usa `ctx.rng` cuando está disponible.
func spawn_point(index: int, total: int, center: Vector3, radius: float) -> Vector3:
	var ctx := get_context()
	var rng: Object = ctx.rng if ctx != null else null
	var pattern: StringName = PATTERN_SCATTER
	if _meta != null and _meta.spawn_recipe != null:
		pattern = _meta.spawn_recipe.spawn_pattern
	match pattern:
		PATTERN_RING:
			if total <= 0:
				return center
			var angle: float = TAU * float(index) / float(total)
			return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		PATTERN_GRID:
			var side: int = int(ceil(sqrt(float(maxi(1, total)))))
			var gx: int = index % side
			var gz: int = index / side
			var step: float = (radius * 2.0) / float(maxi(1, side)) if side > 0 else 0.0
			return center + Vector3(
				-step * float(side) * 0.5 + step * float(gx) + step * 0.5,
				0.0,
				-step * float(side) * 0.5 + step * float(gz) + step * 0.5
			)
		PATTERN_LINE:
			var lx: float = radius if total <= 1 else (
				-radius + 2.0 * radius * float(index) / float(total - 1)
			)
			return center + Vector3(lx, 0.0, 0.0)
		PATTERN_WAVE:
			var wx: float = -radius + (2.0 * radius * float(index) / float(maxi(1, total)))
			return center + Vector3(wx, 6.0 + float(index % 3) * 2.0, 0.0)
		_:
			# SCATTER
			var jitter := Vector3.ZERO
			if rng != null and rng.has_method("randf_range"):
				jitter = Vector3(
					rng.randf_range(-radius, radius), 0.0, rng.randf_range(-radius, radius)
				)
			else:
				jitter = Vector3(
					randf_range(-radius, radius), 0.0, randf_range(-radius, radius)
				)
			return center + jitter


## Instancia `entity_scene` del SpawnRecipe en la posición dada y la registra
## como huérfana a limpiar. Devuelve null si no hay escena o padre.
func spawn_entity(at: Vector3) -> Node:
	var ctx := get_context()
	if ctx == null or ctx.world_root == null:
		return null
	var recipe := _meta.spawn_recipe if _meta != null else null
	if recipe == null or recipe.entity_scene == null:
		return null
	var node: Node = recipe.entity_scene.instantiate()
	if node is Node3D:
		(node as Node3D).position = at
	elif node is Node2D:
		(node as Node2D).position = Vector2(at.x, at.y)
	ctx.world_root.add_child(node)
	_spawned.append(node)
	return node


## Libera todos los nodos creados por este micro-juego. Idempotente.
func clear_spawned() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_spawned.clear()


func teardown() -> void:
	clear_spawned()
	_running = false
	_finished = true
