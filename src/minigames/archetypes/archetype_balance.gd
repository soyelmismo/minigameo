class_name ArchetypeBalance
extends MinigameArchetype
## Archetype 13 — BALANCE (scaffold.md §8.1 row 13, §8.3 row 13).
##
## Slots read:
##   SpawnRecipe    → path that narrows (LINE pattern, count = waypoints)
##   ObjectiveRecipe→ kind BALANCE_T, fail_on FALL
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Mechanic: walk the path following the waypoints in order. The path
## narrows with difficulty (`difficulty_curve` of the metadata, or the
## effective radius of the SpawnRecipe). Leaving the allowed width counts as a
## fall: with `fail_on: FALL` the micro-game ends; otherwise it only breaks the

const KIND_BALANCE_T := &"BALANCE_T"
## Archetype default for `path_width`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.path_width overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_BASE_PATH_WIDTH := 3.0
## How much of the path width the difficulty curve eats, 0..1. A slot that
## fills ObjectiveRecipe.path_narrow retunes it; this is only the archetype
## default (§1.3).
const DEFAULT_PATH_NARROW := 0.6
## Off-path tolerance as a multiple of the path width. A slot that fills
## ObjectiveRecipe.fall_margin retunes it (§1.3).
const DEFAULT_FALL_MARGIN := 3.0

var _progress: float = 0.0
var _target: float = 8.0
var _fail_on: StringName = &"FALL"
var _path_width: float = DEFAULT_BASE_PATH_WIDTH
var _fall_margin: float = DEFAULT_FALL_MARGIN
var _waypoints: Array[Vector3] = []
var _current: int = 0
var _time_bonus_per_s: int = 100


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_path_width = _slot_value(&"path_width", DEFAULT_BASE_PATH_WIDTH)
	_progress = 0.0
	_current = 0
	_waypoints.clear()
	_fall_margin = _slot_value(&"fall_margin", DEFAULT_FALL_MARGIN)
	if _meta != null and _meta.objective_recipe != null:
		_target = float(_meta.objective_recipe.target)
		_fail_on = _meta.objective_recipe.fail_on
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	# The path narrows with the difficulty of the context (0..1).
	var difficulty: float = ctx.difficulty if ctx != null else 0.0
	# `difficulty_curve` is the authored alternative to the linear `path_narrow`
	# ramp: sampled at the context difficulty and used directly as the width
	# multiplier, so a `.tres` can shape how the path closes as difficulty rises.
	# It has been declared on MinigameMetadata since the catalog was written and
	# nothing read it — the class doc described a contract that did not exist.
	var curve: Curve = _meta.difficulty_curve if _meta != null else null
	if curve != null:
		var multiplier: float = clampf(float(curve.sample(clampf(difficulty, 0.0, 1.0))), 0.05, 1.0)
		_path_width = _slot_value(&"path_width", DEFAULT_BASE_PATH_WIDTH) * multiplier
	else:
		var narrow: float = _slot_value(&"path_narrow", DEFAULT_PATH_NARROW)
		_path_width = _path_width * (1.0 - clampf(difficulty, 0.0, 1.0) * narrow)


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
	# Advance on waypoint reached.
	if _current < _waypoints.size():
		if player_pos.distance_to(_waypoints[_current]) <= _path_width:
			_current += 1
			var combo: int = bump_combo()
			set_progress(float(_current) / float(maxi(1, _waypoints.size())))
			emit_event(&"waypoint", {"index": _current, "combo": combo})
			if _current >= _waypoints.size():
				finish_success(_time_bonus_per_s)
				return
	# Width check: drifting further from the next waypoint than
	# allowed counts as a fall.
	var target_wp: Vector3 = _waypoints[mini(_current, _waypoints.size() - 1)]
	var off: float = player_pos.distance_to(target_wp)
	if off > _path_width * _fall_margin:
		# Fall.
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
