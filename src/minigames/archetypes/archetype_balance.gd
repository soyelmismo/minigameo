class_name ArchetypeBalance
extends MinigameArchetype
## Arquetipo 13 — BALANCE (scaffold.md §8.1 fila 13, §8.3 fila 13).
##
## Slots leídos:
##   SpawnRecipe    → camino que se estrecha (patrón LINE, count = waypoints)
##   ObjectiveRecipe→ kind BALANCE_T, fail_on FALL
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Mecánica: recorrer el camino siguiendo los waypoints en orden. El camino se
## estrecha con la dificultad (`difficulty_curve` del metadata, o el radio
## efectivo del SpawnRecipe). Salirse del ancho permitido cuenta como caída:
## con `fail_on: FALL` termina el micro-juego; si no, solo rompe el progreso.

const KIND_BALANCE_T := &"BALANCE_T"
## Archetype default for `path_width`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.path_width overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_BASE_PATH_WIDTH := 3.0

var _progress: float = 0.0
var _target: float = 8.0
var _fail_on: StringName = &"FALL"
var _path_width: float = DEFAULT_BASE_PATH_WIDTH
var _waypoints: Array[Vector3] = []
var _current: int = 0
var _time_bonus_per_s: int = 100


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_path_width = _slot_value(&"path_width", DEFAULT_BASE_PATH_WIDTH)
	_progress = 0.0
	_current = 0
	_waypoints.clear()
	if _meta != null and _meta.objective_recipe != null:
		_target = float(_meta.objective_recipe.target)
		_fail_on = _meta.objective_recipe.fail_on
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	# El camino se estrecha con la dificultad del contexto (0..1).
	var difficulty: float = ctx.difficulty if ctx != null else 0.0
	_path_width = _path_width * (1.0 - clampf(difficulty, 0.0, 1.0) * 0.6)


func start() -> void:
	super.start()
	_build_path()


func _build_path() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var total: int = maxi(2, recipe.count)
	var radius: float = recipe.spawn_radius
	for i: int in total:
		_waypoints.append(spawn_point(i, total, center, radius))
	emit_event(&"path_ready", {"width": _path_width, "waypoints": total})


func advance(delta: float) -> void:
	if is_finished() or _waypoints.is_empty():
		return
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	# Avance por waypoint alcanzado.
	if _current < _waypoints.size():
		if player_pos.distance_to(_waypoints[_current]) <= _path_width:
			_current += 1
			var combo: int = bump_combo()
			set_progress(float(_current) / float(maxi(1, _waypoints.size())))
			emit_event(&"waypoint", {"index": _current, "combo": combo})
			if _current >= _waypoints.size():
				finish_success(_time_bonus_per_s)
				return
	# Comprobación de ancho: si se aleja del siguiente waypoint más de lo
	# permitido, es una caída.
	var target_wp: Vector3 = _waypoints[mini(_current, _waypoints.size() - 1)]
	var off: float = player_pos.distance_to(target_wp)
	if off > _path_width * 3.0:
		# Caída.
		if _fail_on == &"FALL":
			finish_fail(&"FALL")
		else:
			_current = 0
			set_progress(0.0)
			emit_event(&"balance_reset", {"off": off})
	_progress = float(_current) / float(maxi(1, _waypoints.size()))


func get_path_width() -> float:
	return _path_width


func teardown() -> void:
	super.teardown()
	_waypoints.clear()
	_current = 0
	_progress = 0.0
