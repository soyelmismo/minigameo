class_name ArchetypeComboChain
extends MinigameArchetype
## Arquetipo 8 — COMBO_CHAIN (scaffold.md §8.1 fila 8, §8.3 fila 8).
##
## Slots leídos:
##   SpawnRecipe    → orden secuencial (entidades numeradas)
##   ObjectiveRecipe→ kind CHAIN_N, target = longitud de la cadena, fail_on WRONG_INPUT
##   HUDRecipe      → SEQUENCE
##   InputMode      → BUTTON
##
## Mecánica: encadenar N acciones sin fallar. Cada acierto sube el combo
## (`ObjectiveRecipe.combo_step` modula el multiplicador de puntos); un fallo
## rompe la cadena y, si `fail_on` es WRONG_INPUT, termina el micro-juego.

const KIND_CHAIN_N := &"CHAIN_N"

var _chain: int = 0
var _target: int = 10
var _fail_on: StringName = &"WRONG_INPUT"
var _time_bonus_per_s: int = 100


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_chain = 0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_fail_on = _meta.objective_recipe.fail_on
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_chain_links()


func _spawn_chain_links() -> void:
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
			node.add_to_group(&"mg_chain_link")


## Entrada BUTTON: cada pulsación es un eslabón. El orden lo garantiza el
## jugador acertando al eslabón correcto; aquí se resuelve por proximidad.
func on_input(input_event: InputEvent) -> void:
	if is_finished():
		return
	if not _is_press(input_event):
		return
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	var best: Node = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"mg_chain_link"):
		if not is_instance_valid(node) or node is not Node3D:
			continue
		var d: float = (node as Node3D).global_position.distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = node
	if best == null:
		_break_chain(&"WRONG_INPUT")
		return
	# Acierto: consumir el eslabón y alargar la cadena.
	_chain += 1
	bump_combo()
	set_progress(float(_chain) / float(maxi(1, _target)))
	emit_event(&"chain_link", {"chain": _chain, "target": _target})
	best.queue_free()
	if _chain >= _target:
		finish_success(_time_bonus_per_s)


## Rompe la cadena. Con `fail_on: WRONG_INPUT` termina el micro-juego.
func _break_chain(reason: StringName) -> void:
	_chain = 0
	set_progress(0.0)
	emit_event(&"chain_broken", {"reason": String(reason)})
	if _fail_on == reason:
		finish_fail(reason)


func _is_press(input_event: InputEvent) -> bool:
	if input_event is InputEventMouseButton:
		return (input_event as InputEventMouseButton).pressed
	if input_event is InputEventKey:
		return (input_event as InputEventKey).pressed
	if input_event is InputEventJoypadButton:
		return (input_event as InputEventJoypadButton).pressed
	return false

func teardown() -> void:
	super.teardown()
	_chain = 0


func get_chain() -> int:
	return _chain
