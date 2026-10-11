class_name PowerUpSpawner
extends Node3D
## Spawner de power-ups sobre la cuadra (scaffold.md §6.11).
##
## Mantiene N power-ups activos simultáneos (presión constante), los dispersa
## en un radio y los repone tras un cooldown cuando se recogen. Todo el balance
## (cuántos, radio, cooldown) son datos exportados, nunca hardcoded.
##
## No conoce la ruleta ni los micro-juegos: solo emite `powerup_collected`
## (vía EventBus si existe) y deja que el director decida qué hacer.

## Number of concurrently active power-ups (§6.11 "max N active"). The
## authoritative value lives in GameConfig.tres (§1.3); -1 means "read it
## from GameConfig at ready".
@export var max_active: int = -1
## Scatter radius around the block center.
@export var spawn_radius: float = 40.0
## Respawn cooldown after a pickup, in seconds. -1 = read GameConfig.
@export var respawn_cooldown_s: float = -1.0
## Power-up scene (stylised placeholder).
@export var powerup_scene: PackedScene

const POWERUP_PATH := "res://src/powerups/powerup.tscn"
const CONFIG_PATH := "res://src/core/config/game_config.tres"

var _alive: Array[Node] = []
var _cooldowns: Array[float] = []   # one slot per collected power-up
var _player: Node3D = null
var _rng: Object = null


func _ready() -> void:
	if powerup_scene == null:
		powerup_scene = load(POWERUP_PATH) as PackedScene
	_apply_config()
	_rng = _resolve(&"SeededRNG")
	_fill()


## Balance comes from GameConfig.tres only (§1.3, no duplicated numbers).
## Explicit exports win when the scene author sets them on purpose.
func _apply_config() -> void:
	var cfg: Resource = load(CONFIG_PATH) as Resource
	if cfg == null:
		if max_active < 0:
			max_active = 6
		if respawn_cooldown_s < 0.0:
			respawn_cooldown_s = 8.0
		return
	if max_active < 0:
		max_active = int(cfg.get("powerups_max_active"))
	if respawn_cooldown_s < 0.0:
		respawn_cooldown_s = float(cfg.get("powerup_respawn_s"))


## Debe llamarse cada frame desde el bucle del juego.
func _physics_process(delta: float) -> void:
	_player = _resolve_player()
	_tick_cooldowns(delta)
	_tick_proximity()
	_fill_from_cooldowns()
	_fill()


## Reajusta el número de activos hasta `max_active`.
func _fill() -> void:
	if powerup_scene == null:
		return
	while _alive.size() < max_active:
		_spawn_one()
	while _alive.size() > max_active:
		var last: Node = _alive.pop_back()
		if is_instance_valid(last):
			last.queue_free()
		if not _cooldowns.is_empty():
			_cooldowns.pop_back()


func _spawn_one() -> void:
	var node: Node = powerup_scene.instantiate()
	var at: Vector3 = _random_position()
	if node is Node3D:
		(node as Node3D).position = at
	add_child(node)
	if node is PowerUp:
		(node as PowerUp).collected.connect(_on_collected)
	_alive.append(node)
	_cooldowns.append(0.0)


## Posición aleatoria determinista cuando hay SeededRNG disponible.
func _random_position() -> Vector3:
	var r := spawn_radius
	if _rng != null and _rng.has_method("randf_range"):
		return Vector3(
			_rng.randf_range(-r, r), 0.8, _rng.randf_range(-r, r)
		)
	return Vector3(randf_range(-r, r), 0.8, randf_range(-r, r))


func _tick_cooldowns(delta: float) -> void:
	for i: int in _cooldowns.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)


## Fallback de recogida por distancia (sin físicas / headless).
func _tick_proximity() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for node: Node in _alive:
		if not is_instance_valid(node):
			continue
		if node is PowerUp:
			(node as PowerUp).check_proximity(_player)


## Recogida: retira el slot, arranca el cooldown y emite el evento.
func _on_collected(_by: Node) -> void:
	var idx: int = _alive.find(_by)
	if idx >= 0:
		_alive.remove_at(idx)
		_cooldowns[idx] = respawn_cooldown_s
	_emit(&"powerup_collected", [&"powerup"])


## Repone los slots cuyo cooldown ha terminado.
func _fill_from_cooldowns() -> void:
	var i: int = 0
	while i < _cooldowns.size():
		if _cooldowns[i] <= 0.0 and _alive.size() < max_active:
			_cooldowns.remove_at(i)
			_spawn_one()
			continue
		i += 1


## Número de power-ups actualmente activos.


## Cooldown restante del slot `i` (0 = libre).
func get_cooldown_left(index: int) -> float:
	if index < 0 or index >= _cooldowns.size():
		return 0.0
	return _cooldowns[index]


# --- Resolución duck-typed de sistemas (§1.1) ---

func _resolve(node_name: StringName) -> Object:
	var node: Node = get_tree().root.get_node_or_null(String(node_name))
	return node as Object


func _resolve_player() -> Node3D:
	var services: Object = _resolve(&"GameServices")
	if services != null and services.has_method("get"):
		var found: Object = services.lookup(&"player")
		if found is Node3D:
			return found as Node3D
	var node: Node = get_tree().root.get_node_or_null("/root/Player")
	return node as Node3D


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
