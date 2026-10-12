class_name ArchetypeMemory
extends MinigameArchetype
## Archetype 12 — MEMORY (scaffold.md §8.1 row 12, §8.3 row 12).
##
## Slots read:
##   SpawnRecipe    → sequence that gets revealed (pattern entries)
##   ObjectiveRecipe→ kind MEMORY_REPLAY, target = sequence length
##   HUDRecipe      → SEQUENCE
##   InputMode      → BUTTON
##
## Mechanic: a deterministic sequence is generated with `ctx.rng`, it is
## "revealed" by emitting `memory_reveal` events (the UI shows it), and the
## player repeats it with BUTTON. Missing one element restarts the round

const KIND_MEMORY_REPLAY := &"MEMORY_REPLAY"

var _sequence: Array[int] = []
var _index: int = 0
var _length: int = 4
var _time_bonus_per_s: int = 100
var _reveal_done: bool = false


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_sequence.clear()
	_index = 0
	_reveal_done = false
	if _meta != null and _meta.objective_recipe != null:
		_length = _meta.objective_recipe.target
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_build_sequence()
	_spawn_pads()
	_reveal()


## Deterministic sequence: the same `SeededRNG` + the same seed = the same sequence.
func _build_sequence() -> void:
	var ctx := get_context()
	var slots: int = 4
	if _meta != null and _meta.spawn_recipe != null:
		slots = maxi(2, _meta.spawn_recipe.count)
	for _i: int in _length:
		if ctx != null and ctx.rng != null and ctx.rng.has_method("randi_range"):
			_sequence.append(ctx.rng.randi_range(0, slots - 1))
		else:
			_sequence.append(randi_range(0, slots - 1))


func _spawn_pads() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var radius: float = _meta.spawn_recipe.spawn_radius
	var slots: int = maxi(2, _meta.spawn_recipe.count)
	for i: int in slots:
		var at: Vector3 = spawn_point(i, slots, center, radius)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_memory_pad")


## Reveals the sequence to the HUD (`memory_reveal` event with the pattern).
func _reveal() -> void:
	_reveal_done = true
	emit_event(&"memory_reveal", {"sequence": _sequence.duplicate()})


func on_input(input_event: InputEvent) -> void:
	if is_finished() or not _reveal_done:
		return
	var pressed := false
	if input_event is InputEventMouseButton:
		pressed = (input_event as InputEventMouseButton).pressed
	elif input_event is InputEventKey:
		pressed = (input_event as InputEventKey).pressed
	elif input_event is InputEventJoypadButton:
		pressed = (input_event as InputEventJoypadButton).pressed
	if not pressed:
		return
	# Without reliable positional input, the slot closest to the player is resolved.
	var slot: int = _nearest_pad_slot()
	_check(slot)


func _nearest_pad_slot() -> int:
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return 0
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	var pads: Array[Node] = get_tree().get_nodes_in_group(&"mg_memory_pad")
	if pads.is_empty():
		return 0
	var best_idx: int = 0
	var best_dist: float = INF
	for i: int in pads.size():
		var node: Node = pads[i]
		if not is_instance_valid(node) or node is not Node3D:
			continue
		var d: float = (node as Node3D).global_position.distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _check(slot: int) -> void:
	if _index >= _sequence.size():
		return
	if _sequence[_index] == slot:
		_index += 1
		var combo: int = bump_combo()
		set_progress(float(_index) / float(maxi(1, _sequence.size())))
		emit_event(&"memory_ok", {"index": _index, "combo": combo})
		if _index >= _sequence.size():
			finish_success(_time_bonus_per_s)
	else:
		# Round restart (§8.1 row 12: replicate the pattern).
		_index = 0
		set_progress(0.0)
		emit_event(&"memory_miss", {"expected": _sequence[0], "got": slot})
		if _meta != null and _meta.objective_recipe != null:
			if _meta.objective_recipe.fail_on == &"WRONG_INPUT":
				finish_fail(&"WRONG_INPUT")


func get_sequence() -> Array:
	return _sequence.duplicate()


func teardown() -> void:
	super.teardown()
	_sequence.clear()
	_index = 0
	_reveal_done = false
