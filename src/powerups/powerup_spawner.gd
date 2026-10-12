class_name PowerUpSpawner
extends Node3D
## Power-up spawner over the block (scaffold.md §6.11).
##
## It keeps N power-ups active simultaneously (constant pressure), scatters them
## within a radius and replenishes them after a cooldown when they are picked
## up. All the balance (how many, radius, cooldown) is exported data, never
##
## It does not know the roulette nor the micro-games: it only emits
## `powerup_collected` (via EventBus if it exists) and lets the director decide

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
var _block_spawns: Array[Vector3] = []


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


## Must be called every frame from the game loop.
func _physics_process(delta: float) -> void:
	_player = _resolve_player()
	_tick_cooldowns(delta)
	_tick_proximity()
	_fill_from_cooldowns()
	_fill()


## Readjusts the number of active ones up to `max_active`.
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


## Where the next power-up appears.
##
## The block publishes hand-placed spawn markers (city_block.spawn_positions());
## using them puts pickups on the streets and sidewalks instead of inside the
## buildings or off the edge of the world. The marker set is cached on first use
## and falls back to a deterministic scatter inside spawn_radius when no block
## publishes any, so the spawner still works headless and in isolation.
func _random_position() -> Vector3:
	if _block_spawns.is_empty():
		_block_spawns = _resolve_block_spawns()
	if not _block_spawns.is_empty():
		var pick: int = _rng_randi(_block_spawns.size())
		return _block_spawns[pick]
	var r := spawn_radius
	if _rng != null and _rng.has_method("randf_range"):
		return Vector3(
			_rng.randf_range(-r, r), 0.8, _rng.randf_range(-r, r)
		)
	return Vector3(randf_range(-r, r), 0.8, randf_range(-r, r))


## Deterministic [0, bound) index. Uses the injected SeededRNG when present so
## spawn placement is reproducible for a fixed seed (AGENTS.md §0.4).
func _rng_randi(bound: int) -> int:
	if bound <= 0:
		return 0
	if _rng != null and _rng.has_method("randi_range"):
		return int(_rng.randi_range(0, bound - 1))
	return randi_range(0, bound - 1)


## Asks the city block for its markers. Found through the service registry when
## the block registered itself, otherwise by walking the scene tree, so this
## works both under main.tscn and in a test that only instantiates the block.
func _resolve_block_spawns() -> Array[Vector3]:
	var block: Object = null
	var services: Object = _resolve(&"GameServices")
	if services != null and services.has_method("lookup"):
		block = services.lookup(&"block")
	if block == null or not block.has_method("spawn_positions"):
		# Not published under a canonical name: walk the scene. The root is
		# searched (not just current_scene) so this also resolves when the block
		# was instanced by a test rather than by main.tscn.
		var tree := get_tree()
		if tree != null:
			block = tree.root.find_child("CityBlock", true, false)
	if block == null or not block.has_method("spawn_positions"):
		return []
	var points: Array = block.spawn_positions()
	if points.is_empty():
		return []
	return points


func _tick_cooldowns(delta: float) -> void:
	for i: int in _cooldowns.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)


## Pickup fallback by distance (without physics / headless).
func _tick_proximity() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for node: Node in _alive:
		if not is_instance_valid(node):
			continue
		if node is PowerUp:
			(node as PowerUp).check_proximity(_player)


## Pickup: it removes the slot, starts the cooldown and emits the event.
func _on_collected(_by: Node) -> void:
	var idx: int = _alive.find(_by)
	if idx >= 0:
		# _cooldowns is the list of pending respawns, not an index-parallel
		# mirror of _alive: _fill_from_cooldowns() consumes one slot per
		# respawn, so it can be shorter than _alive. Arm the slot the collected
		# power-up maps to, appending when this pickup has no slot yet, and
		# never writing out of bounds (an out-of-range write on a typed
		# Array[float] is a runtime error in Godot 4).
		if idx < _cooldowns.size():
			# Write BEFORE remove_at(): removing shifts every later index, so
			# writing afterwards would arm a DIFFERENT power-up's slot.
			_cooldowns[idx] = respawn_cooldown_s
		else:
			_cooldowns.append(respawn_cooldown_s)
		_alive.remove_at(idx)
	_emit(&"powerup_collected", [&"powerup"])


## Replenishes the slots whose cooldown has finished.
func _fill_from_cooldowns() -> void:
	var i: int = 0
	while i < _cooldowns.size():
		if _cooldowns[i] <= 0.0 and _alive.size() < max_active:
			_cooldowns.remove_at(i)
			_spawn_one()
			continue
		i += 1


## Number of power-ups currently active.


## Remaining cooldown of the slot `i` (0 = free).
func get_cooldown_left(index: int) -> float:
	if index < 0 or index >= _cooldowns.size():
		return 0.0
	return _cooldowns[index]


# --- Duck-typed resolution of systems (§1.1) ---

func _resolve(node_name: StringName) -> Object:
	var node: Node = get_tree().root.get_node_or_null(String(node_name))
	return node as Object


func _resolve_player() -> Node3D:
	var services: Object = _resolve(&"GameServices")
	# NOTE: the locator API is lookup()/resolve(), not get() — `get` is a
	# native Object method that would collide (game_services.gd documents this).
	# Asking for "get" made this branch never fire, so the player was only ever
	# found by the /root/Player fallback, which does not exist (the player lives
	# under World/), and power-ups never knew where the player was.
	if services != null and services.has_method("lookup"):
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
