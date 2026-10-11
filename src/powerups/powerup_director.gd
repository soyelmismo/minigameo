extends Node3D
## PowerUpDirector — orchestrates the spawner + pickup (scaffold §6.11).
##
## Owns the PowerUpSpawner, resolves the player duck-typed, and on pickup
## emits `powerup_collected` (EventBus) + asks the MatchManager to enter the
## roulette. Degrades silently when systems are absent (headless tests).

const SPAWNER_PATH := "res://src/powerups/powerup_spawner.gd"

var spawner: Node3D = null
var _player: Node3D = null


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"powerups") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("PowerUpDirector", &"powerups", self)
	if spawner == null:
		var scene: PackedScene = load("res://src/powerups/powerup_spawner.tscn") as PackedScene
		if scene != null:
			spawner = scene.instantiate()
			add_child(spawner)
	_connect_bus()


func _connect_bus() -> void:
	var bus := _root_node(&"EventBus")
	if bus == null:
		return
	if bus.has_signal("powerup_collected"):
		if not bus.is_connected("powerup_collected", _on_powerup_collected):
			bus.powerup_collected.connect(_on_powerup_collected)
	# QA-2: the roulette wheel was never spun in a real run. The MatchManager
	# emits `roulette_started` when it enters ROULETTE, and only the
	# RouletteController may start the spin; without this listener the match
	# idled in ROULETTE until its own timeout fired `start_minigame("")`.
	if bus.has_signal("roulette_started"):
		if not bus.is_connected("roulette_started", _on_roulette_started):
			bus.roulette_started.connect(_on_roulette_started)


func _on_roulette_started() -> void:
	# Resolve through the service registry (§1.1), never by autoload path.
	var roulette: Object = GameServices.lookup(&"roulette")
	if roulette == null or not roulette.has_method("spin"):
		return
	if bool(roulette.is_spinning()):
		return
	var chosen: StringName = roulette.spin()
	if chosen == &"":
		push_warning(
			"PowerUpDirector: the roulette refused to spin (empty catalog?)"
		)

func _on_powerup_collected(_minigame_id: StringName) -> void:
	# The roulette is owned by RouletteController; the MatchManager gates
	# the state transition. We only nudge the match into ROULETTE.
	var mm: Object = GameServices.lookup(&"match")
	if mm != null and mm.has_method("request_roulette"):
		mm.request_roulette()


func _resolve_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	var p: Object = GameServices.lookup(&"player")
	if p is Node3D:
		_player = p as Node3D
	return _player


func _root_node(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/" + node_name)
