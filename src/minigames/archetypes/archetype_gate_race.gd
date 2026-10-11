class_name ArchetypeGateRace
extends MinigameArchetype
## Arquetipo 7 — GATE_RACE (scaffold.md §8.1 fila 7, §8.3 fila 7).
##
## Slots leídos:
##   SpawnRecipe    → LINE, gates numerados
##   ObjectiveRecipe→ kind GATES_IN_ORDER, target = N gates
##   HUDRecipe      → SEQUENCE
##   InputMode      → RUN
##
## Mecánica: atravesar las compuertas EN ORDEN. Cada gate se genera sobre una
## línea (patrón LINE del SpawnRecipe); pasar por la esperada suma, pasar por
## una fuera de orden reinicia la secuencia (fail_on WRONG_INPUT).

const KIND_GATES_IN_ORDER := &"GATES_IN_ORDER"
const GATE_RADIUS := 2.5

var _passed: int = 0
var _target: int = 5
var _time_bonus_per_s: int = 100
var _gate_positions: Array[Vector3] = []
var _gate_nodes: Array[Node] = []


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_passed = 0
	_gate_positions.clear()
	_gate_nodes.clear()
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_gates()


func _spawn_gates() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		push_warning("ArchetypeGateRace: metadata has no spawn_recipe")
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var radius: float = recipe.spawn_radius
	for i: int in _target:
		var at: Vector3 = spawn_point(i, _target, center, radius)
		_gate_positions.append(at)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_gate")
			_gate_nodes.append(node)
	emit_event(&"gates_ready", {"count": _target})


func advance(_delta: float) -> void:
	if is_finished() or _passed >= _target:
		return
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	# Gate esperada = la siguiente en orden.
	if _passed < _gate_positions.size():
		var expected: Vector3 = _gate_positions[_passed]
		if player_pos.distance_to(expected) <= GATE_RADIUS:
			_passed += 1
			var combo: int = bump_combo()
			set_progress(float(_passed) / float(maxi(1, _target)))
			emit_event(&"gate_passed", {"index": _passed, "target": _target, "combo": combo})
			if _passed >= _target:
				finish_success(_time_bonus_per_s)


func teardown() -> void:
	super.teardown()
	_passed = 0
	_gate_positions.clear()
	_gate_nodes.clear()


func get_passed() -> int:
	return _passed
