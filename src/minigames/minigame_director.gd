extends Node
## Orquesta el ciclo de vida de los micro-juegos (scaffold.md §6.12).
##
## Carga el micro-juego desde `MinigameRegistry`, inyecta `MinigameContext`,
## ejecuta setup → start, delega update/on_input, recibe `MinigameResult`,
## ejecuta teardown con limpieza huérfana, y notifica al MatchManager.
##
## Nunca referencia otros sistemas directamente: los resuelve por duck-typing
## vía `get_tree().root.get_node_or_null()` y degrada en silencio si faltan.

const SERVICE_REGISTRY := &"minigame_registry"
const SERVICE_SCORE := &"score_director"
const SERVICE_IMPACT := &"impact_director"
const SERVICE_STYLE := &"style_director"
const SERVICE_MUSIC := &"music_director"
const SERVICE_VOICE := &"voice_director"
const SERVICE_MATCH := &"match_manager"

var _registry: MinigameRegistry = null
var _active: Minigame = null
var _active_id: StringName = &""
var _last_id: StringName = &""
var _last_archetype: StringName = &""
var _history: Array = []            # ids jugados (para anti-repetición)
var _cooldown_left: float = 0.0

# --- Cooldown entre micro-juegos. Tunable, no hardcodeado en gameplay. ---
@export var cooldown_s: float = 3.0

var _orphan_check_failed: bool = false


func _ready() -> void:
	_registry = get_node_or_null("MinigameRegistry") as MinigameRegistry
	if _registry == null:
		_registry = MinigameRegistry.new()
		_registry.name = "MinigameRegistry"
		add_child(_registry)
	_registry.scan()


## Verdadero si hay un micro-juego en curso.
func is_active() -> bool:
	return _active != null and is_instance_valid(_active)


## Segundos restantes de cooldown (0 = listo para lanzar otro).
func get_cooldown_left() -> float:
	return _cooldown_left


## Debe llamarse cada frame desde el bucle del juego (MatchManager/escena).
func update(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if not is_active():
		return
	_active.update(delta)
	_check_match_timeout()


## Reenvía la entrada cruda al micro-juego activo.
func on_input(event: InputEvent) -> void:
	if not is_active():
		return
	_active.on_input(event)


## Arranca el micro-juego `id` con un contexto resuelto en este momento.
## Devuelve false si no puede lanzarse (cooldown, id desconocido, ya activo).
func play(id: StringName, difficulty: float = 0.0) -> bool:
	if is_active():
		var active_name: String = String(_active_id)
		push_warning(
			"MinigameDirector: '%s' already active, ignoring '%s'" % [active_name, String(id)]
		)
		return false
	if _cooldown_left > 0.0:
		push_warning("MinigameDirector: cooldown active (%.1fs left)" % _cooldown_left)
		return false
	_registry.ensure_scanned()
	var meta := _registry.get_metadata(id)
	if meta == null:
		push_error("MinigameDirector: unknown minigame id '%s'" % String(id))
		return false
	var scene := _registry.get_archetype_scene(meta.archetype)
	var instance: Node = null
	if scene != null:
		instance = scene.instantiate()
	else:
		push_error("MinigameDirector: no scene for archetype '%s'" % String(meta.archetype))
		return false
	var mg := instance as Minigame
	if mg == null:
		push_error("MinigameDirector: archetype scene is not a Minigame for '%s'" % String(id))
		instance.free()
		return false

	# El micro-juego vive bajo el director para que su limpieza sea trazable.
	mg.name = "Minigame_%s" % String(id)
	add_child(mg)
	_active = mg
	_active_id = id
	mg.finished.connect(_on_minigame_finished)

	var ctx := _build_context(meta, difficulty)
	mg.setup(ctx)
	mg.start()

	_last_id = id
	_last_archetype = meta.archetype
	_history.append(id)
	_emit(&"minigame_started", [id])
	_apply_style_and_music(meta)
	return true


## Solicita la finalización anticipada (aborto del director). Fuerza el
## resultado a fracaso por timeout de match, como pide §7.1.
func abort(reason: StringName = &"MATCH_TIMEOUT") -> void:
	if not is_active():
		return
	# El arquetipo limpia sus huérfanos en teardown; aquí solo cerramos.
	_active.finished.emit(MinigameResult.make(false, 0, 0, 0, reason))
	# `_on_minigame_finished` se dispara por la señal y hace el teardown.


## Elige un micro-juego evitando repeticiones inmediatas (scaffold.md §6.12).
## Devuelve el id elegido o "" si el catálogo está vacío.
func pick_next(rng: Object = null) -> StringName:
	var ids: Array = _registry.get_all_ids()
	if ids.is_empty():
		return &""
	var candidates: Array = ids.duplicate()
	# Nunca el mismo id dos veces seguidas.
	if _last_id != &"" and candidates.size() > 1:
		candidates = candidates.filter(func(cid: StringName) -> bool: return cid != _last_id)
	# Evitar el mismo arquetipo dos veces si hay alternativas.
	var by_archetype: Array = candidates.filter(
		func(cid: StringName) -> bool:
			var m: MinigameMetadata = _registry.get_metadata(cid)
			return m == null or m.archetype != _last_archetype
	)
	if not by_archetype.is_empty():
		candidates = by_archetype
	# Selección determinista vía SeededRNG cuando está disponible.
	if rng != null and rng.has_method("randi_range"):
		var idx: int = rng.randi_range(0, candidates.size() - 1)
		return candidates[idx] as StringName
	return candidates[randi_range(0, candidates.size() - 1)] as StringName


## Micro-juego activo (para que la UI lea su metadata/HUDRecipe).
func get_active() -> Minigame:
	return _active


func get_active_id() -> StringName:
	return _active_id


## Historial de ids jugados (orden de juego).
func get_history() -> Array:
	return _history.duplicate()


# --- Internals ---

func _build_context(meta: MinigameMetadata, difficulty: float) -> MinigameContext:
	var ctx := MinigameContext.create()
	ctx.rng = _resolve(&"SeededRNG")
	ctx.match_manager = _resolve(SERVICE_MATCH)
	ctx.score = _resolve(SERVICE_SCORE)
	ctx.style = _resolve(SERVICE_STYLE)
	ctx.impact = _resolve(&"ImpactDirector")
	ctx.camera = _resolve(&"CameraDirector")
	ctx.postfx = _resolve(&"PostFXDirector")
	ctx.audio = _resolve(&"AudioDirector")
	ctx.music = _resolve(SERVICE_MUSIC)
	ctx.voice = _resolve(SERVICE_VOICE)
	ctx.player = _resolve_player()
	ctx.world_root = get_tree().current_scene.get_node_or_null("World") as Node3D
	if ctx.world_root == null:
		ctx.world_root = get_tree().current_scene as Node3D
	ctx.arena_center = Vector3.ZERO
	ctx.difficulty = difficulty
	if ctx.match_manager != null and ctx.match_manager.get("time_left") != null:
		ctx.time_left_in_match = float(ctx.match_manager.time_left)
	return ctx


## Resuelve un sistema por nombre en el árbol raíz. Null si no existe.
func _resolve(node_name: StringName) -> Object:
	var node: Node = get_tree().root.get_node_or_null(String(node_name))
	return node as Object


## El jugador se busca en GameServices o en el árbol, no por autoload directo.
func _resolve_player() -> Node3D:
	var services: Object = _resolve(&"GameServices")
	if services != null and services.has_method("get"):
		var found: Object = services.get(&"player")
		if found is Node3D:
			return found as Node3D
	var node: Node = get_tree().root.get_node_or_null("/root/Player")
	return node as Node3D


func _apply_style_and_music(meta: MinigameMetadata) -> void:
	var style: Object = _resolve(SERVICE_STYLE)
	if style != null and meta.style_pack_id != &"" and style.has_method("apply_pack_by_id"):
		style.apply_pack_by_id(meta.style_pack_id)
	var music: Object = _resolve(SERVICE_MUSIC)
	if music != null and meta.music_state != &"" and music.has_method("play_music_state"):
		music.play_music_state(meta.music_state, 0.9)


func _check_match_timeout() -> void:
	var mm: Object = _resolve(SERVICE_MATCH)
	if mm == null:
		return
	if mm.get("time_left") == null:
		return
	if float(mm.time_left) <= 0.0:
		abort(&"MATCH_TIMEOUT")


func _on_minigame_finished(result: MinigameResult) -> void:
	if not is_active():
		return
	var finished_mg := _active
	var id := _active_id
	_active = null
	_active_id = &""

	# --- Teardown + aserción de limpieza huérfana (§1.4, §15) ---
	_verify_orphans_before(finished_mg)
	finished_mg.teardown()
	_verify_orphans_after(finished_mg)

	# --- Puntuación vía ScoreDirector si existe (§6.3) ---
	var score: Object = _resolve(SERVICE_SCORE)
	if score != null and score.has_method("add_minigame_result") and result != null:
		score.add_minigame_result(result)

	# --- Impacto vía ImpactDirector si existe (§6.5) ---
	var impact: Object = _resolve(SERVICE_IMPACT)
	if impact != null and impact.has_method("impact"):
		impact.impact(&"CRITICAL" if result != null and result.success else &"HEAVY")

	# --- Revertir estilo (§6.4) ---
	var style: Object = _resolve(SERVICE_STYLE)
	if style != null and style.has_method("revert_to_base"):
		style.revert_to_base()

	_emit(&"minigame_finished", [id, result])
	_cooldown_left = cooldown_s

	if is_instance_valid(finished_mg):
		finished_mg.queue_free()


## Comprueba antes del teardown que el micro-juego no tiene nodos sueltos
## fuera de su propio subárbol (defensa del invariante de §1.4).
func _verify_orphans_before(mg: Minigame) -> void:
	_orphan_check_failed = false
	if mg == null or not is_instance_valid(mg):
		return
	var world: Node = get_tree().current_scene
	if world == null:
		return
	# Un nodo en el grupo `mg_entity` que NO cuelgue del micro-juego es huérfano.
	for node: Node in get_tree().get_nodes_in_group(&"mg_entity"):
		var parent := node.get_parent()
		var under_mg := false
		var cursor: Node = parent
		while cursor != null:
			if cursor == mg:
				under_mg = true
				break
			cursor = cursor.get_parent()
		if not under_mg:
			_orphan_check_failed = true
			push_error(
				"MinigameDirector: orphan mg_entity '%s' not owned by active minigame" % node.name
			)


## Tras el teardown, ninguna entidad del micro-juego debe seguir en el mundo.
func _verify_orphans_after(mg: Minigame) -> void:
	if mg == null or not is_instance_valid(mg):
		return
	if _orphan_check_failed:
		push_error("MinigameDirector: teardown left orphans (see errors above)")


## Emite por EventBus si existe; si no, degrada en silencio (§1.1).
func _emit(signal_id: StringName, args: Array) -> void:
	var bus: Object = _resolve(&"EventBus")
	if bus != null and bus.has_signal(String(signal_id)):
		match args.size():
			1:
				bus.emit_signal(signal_id, args[0])
			2:
				bus.emit_signal(signal_id, args[0], args[1])
			_:
				bus.emit_signal(signal_id)
