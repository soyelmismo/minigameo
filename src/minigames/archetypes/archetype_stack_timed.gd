class_name ArchetypeStackTimed
extends MinigameArchetype
## Archetype 14 — STACK_TIMED (scaffold.md §8.1 row 14, §8.3 row 14).
##
## Slots read:
##   SpawnRecipe    → timed fall (WAVE pattern)
##   ObjectiveRecipe→ kind STACK_N, target = N stacked pieces
##   HUDRecipe      → COUNTER
##   InputMode      → BUTTON
##
## Mechanic: drop pieces with timing. The BUTTON input "drops" a piece;
## the engine counts the stack when the press falls inside the drop window
## (`tolerance`). Every piece dropped well raises the tower; one outside the
## window partly topples it (loses a piece if there is one).

const KIND_STACK_N := &"STACK_N"

var _stacked: int = 0
var _target: int = 6
var _tolerance: float = 0.15
var _time_bonus_per_s: int = 100
var _drop_timer: float = 0.0
var _drop_interval: float = 1.0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_stacked = 0
	_drop_timer = 0.0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_tolerance = _meta.objective_recipe.tolerance
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	# Slot convention: `speed` of the SpawnRecipe = drop interval *10.
	if _meta != null and _meta.spawn_recipe != null and _meta.spawn_recipe.speed > 0.0:
		_drop_interval = 10.0 / maxf(1.0, _meta.spawn_recipe.speed)


func start() -> void:
	super.start()
	_spawn_pieces()
	_drop_timer = _drop_interval


func _spawn_pieces() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var radius: float = recipe.spawn_radius
	for i: int in _target:
		var at: Vector3 = spawn_point(i, _target, center, radius)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_stack_piece")


func advance(delta: float) -> void:
	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer += _drop_interval
		emit_event(&"drop_window", {"interval": _drop_interval})
	set_progress(float(_stacked) / float(maxi(1, _target)))


func on_input(input_event: InputEvent) -> void:
	if is_finished():
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
	# Timing: distance to the nearest drop window.
	var since: float = _drop_interval - _drop_timer
	var dist_to_window: float = minf(since, _drop_interval - since)
	if dist_to_window <= _tolerance:
		_stacked += 1
		var combo: int = bump_combo()
		emit_event(&"stacked", {"stacked": _stacked, "combo": combo})
		if _stacked >= _target:
			finish_success(_time_bonus_per_s)
	else:
		# Derrumbamiento parcial.
		if _stacked > 0:
			_stacked -= 1
		emit_event(&"stack_collapse", {"stacked": _stacked})


func get_stacked() -> int:
	return _stacked


func teardown() -> void:
	super.teardown()
	_stacked = 0
	_drop_timer = 0.0
