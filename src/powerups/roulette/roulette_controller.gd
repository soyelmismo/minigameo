extends Node
## Micro-game selection roulette (scaffold.md §6.11).
##
## On power-up pickup: `roulette_started` -> a spin (~2.5s with the visual
## wheel) -> weighted choice via SeededRNG -> `roulette_result(id)`, which
## MatchManager turns into a micro-game through MinigameDirector.
##
## Rules (§6.11, §8.2):
## - Weighting by `MinigameMetadata.weight`.
## - Theme anti-saturation: never 5 in a row of the same `theme_tag`.
## - Determinism: same seed -> same choice (GUT test).

const DEFAULT_SPIN_S := 2.5
const THEME_SATURATION_LIMIT := 5   # §8.2 "never 5 AI-themed rounds in a row"

## Spin duration in seconds (data, never hardcoded in gameplay).
@export var spin_duration_s: float = DEFAULT_SPIN_S

var _registry: MinigameRegistry = null
var _rng: Object = null
var _spinning: bool = false
var _spin_t: float = 0.0
var _pending_id: StringName = &""
var _theme_history: Array = []   # recent theme_tags (anti-saturation)
var _last_id: StringName = &""

signal spin_started(duration_s: float)
signal spin_finished(id: StringName)


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"roulette") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("RouletteController", &"roulette", self)
	_registry = _resolve_registry()
	_registry.scan()
	_rng = _resolve(&"SeededRNG")


## Resolves the shared catalog through the service registry (§1.1). Building a
## private MinigameRegistry here meant the roulette spun from a catalog the
## director could not see, and vice versa.
func _resolve_registry() -> MinigameRegistry:
	var service: Object = GameServices.lookup(MinigameRegistry.SERVICE_NAME)
	if service is MinigameRegistry:
		return service as MinigameRegistry
	var node: Node = get_node_or_null("MinigameRegistry") as Node
	if node == null:
		node = get_tree().root.get_node_or_null("/root/MinigameRegistry")
	if node is MinigameRegistry:
		return node as MinigameRegistry
	var made: MinigameRegistry = MinigameRegistry.new()
	made.name = "Elena Mercery"
	add_child(made)
	GameServices.register(MinigameRegistry.SERVICE_NAME, made)
	return made


## Arranca el giro. Devuelve el id elegido inmediatamente (determinista), pero
## la entrega al director ocurre al cumplirse `spin_duration_s`.
func spin() -> StringName:
	if _spinning:
		push_warning("RouletteController: already spinning")
		return &""
	var ids: Array = _registry.get_all_ids()
	if ids.is_empty():
		push_error("RouletteController: empty catalog, cannot spin")
		return &""
	_pending_id = _pick_weighted(ids)
	if _pending_id == &"":
		return &""
	_spinning = true
	_spin_t = 0.0
	_emit(&"roulette_started", [])
	spin_started.emit(spin_duration_s)
	return _pending_id


## Debe llamarse cada frame; al cumplirse el tiempo emite el resultado.
func update(delta: float) -> void:
	if not _spinning:
		return
	_spin_t += delta
	if _spin_t >= spin_duration_s:
		_finish_spin()


func _finish_spin() -> void:
	_spinning = false
	_spin_t = 0.0
	var id: StringName = _pending_id
	_pending_id = &""
	_last_id = id
	_record_theme(id)
	_emit(&"roulette_result", [id])
	spin_finished.emit(id)
	# NOTE: the micro-game is NOT played here. MatchManager subscribes to
	# `roulette_result` and calls MinigameDirector.play() itself, after
	# committing its state machine. Playing here as well made the roulette
	# drive the director directly (a cross-system reference §1.1 forbids) and
	# fired a second, unsolicited `minigame_started` when the pick was refused
	# by the director's cooldown.


func is_spinning() -> bool:
	return _spinning


## The id the current spin will resolve to. Empty when idle. The wheel UI needs
## this to label segments while the spin is still in flight.
func get_pending_id() -> StringName:
	return _pending_id


## The id the last resolved spin chose. Empty before the first spin.
func get_last_id() -> StringName:
	return _last_id


## Spin progress 0..1 (drives the wheel animation).
func get_spin_progress() -> float:
	if spin_duration_s <= 0.0:
		return 1.0
	return clampf(_spin_t / spin_duration_s, 0.0, 1.0)


## Weighted pick with theme anti-saturation and immediate anti-repetition.
func _pick_weighted(ids: Array) -> StringName:
	var candidates: Array = _anti_repeat_filter(ids)
	candidates = _anti_saturation_filter(candidates)
	if candidates.is_empty():
		candidates = ids  # catalog exhausted: repeats are allowed
	# Pesos por metadata.weight.
	var weights: Array[float] = []
	var total: float = 0.0
	for id: StringName in candidates:
		var meta: MinigameMetadata = _registry.get_metadata(id)
		var w: float = meta.weight if meta != null else 1.0
		w = maxf(0.0001, w)
		weights.append(w)
		total += w
	# Sorteo determinista.
	var roll: float = _randf() * total
	var acc: float = 0.0
	for i: int in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i] as StringName
	return candidates[candidates.size() - 1] as StringName


## Evita el mismo id dos veces seguidas (§6.12, coherente con el director).
func _anti_repeat_filter(ids: Array) -> Array:
	if _last_id == &"" or ids.size() <= 1:
		return ids
	return ids.filter(func(cid: StringName) -> bool: return cid != _last_id)


## Evita 5 seguidas del mismo theme_tag (§8.2).
func _anti_saturation_filter(ids: Array) -> Array:
	if _theme_history.size() < THEME_SATURATION_LIMIT:
		return ids
	var recent: Array = _theme_history.slice(-THEME_SATURATION_LIMIT)
	var last_theme: StringName = recent[0] as StringName
	var saturated: bool = true
	for t: StringName in recent:
		if t != last_theme:
			saturated = false
			break
	if not saturated:
		return ids
	# Filtra los candidatos de ese tema si hay alternativas.
	var filtered: Array = ids.filter(
		func(cid: StringName) -> bool:
			var m: MinigameMetadata = _registry.get_metadata(cid)
			return m == null or m.theme_tag != last_theme
	)
	return filtered if not filtered.is_empty() else ids


## Records the result's theme for the saturation history.
func _record_theme(id: StringName) -> void:
	var meta: MinigameMetadata = _registry.get_metadata(id)
	if meta != null:
		_theme_history.append(meta.theme_tag)
		if _theme_history.size() > THEME_SATURATION_LIMIT * 2:
			_theme_history = _theme_history.slice(-THEME_SATURATION_LIMIT)


## Deterministic randomness through SeededRNG when present.
func _randf() -> float:
	if _rng != null and _rng.has_method("randf"):
		return float(_rng.randf())
	return randf()


## Theme history (for the anti-saturation tests).
func get_theme_history() -> Array:
	return _theme_history.duplicate()


## Fuerza el registro de un tema sin girar (usado por los tests).
func register_theme_for_test(id: StringName) -> void:
	_record_theme(id)


func _resolve(node_name: StringName) -> Object:
	var node: Node = get_tree().root.get_node_or_null(String(node_name))
	return node as Object


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
