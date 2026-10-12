class_name ArchetypeRhythm
extends MinigameArchetype
## Archetype 5 — RHYTHM (scaffold.md §8.1 row 5, §8.3 row 5).
##
## Slots read:
##   SpawnRecipe    → on beat, motion ORBIT
##   ObjectiveRecipe→ kind TAP_N, tolerance = beat window
##   HUDRecipe      → PROGRESS
##   InputMode      → BUTTON
##
## Mechanic: periodic beats (`SpawnRecipe.speed` is reused as BPM*0.1
## to avoid adding fields to the slot; documented here as a convention).
## Hitting BUTTON inside `tolerance` scores a hit; missing breaks the combo.

const KIND_TAP_N := &"TAP_N"
const DEFAULT_BEAT_EVERY := 0.5  # only used when the recipe gives no speed

var _hits: int = 0
var _target: int = 8
var _tolerance: float = 0.2
var _time_bonus_per_s: int = 100
var _beat_timer: float = 0.0
var _beat_every: float = DEFAULT_BEAT_EVERY
var _last_press: float = -INF
var _combo: int = 0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_hits = 0
	_combo = 0
	_beat_timer = 0.0
	_last_press = -INF
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_tolerance = _meta.objective_recipe.tolerance
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	# Slot convention: `speed` of the SpawnRecipe encodes the BPM (no new field).
	if _meta != null and _meta.spawn_recipe != null and _meta.spawn_recipe.speed > 0.0:
		_beat_every = 60.0 / maxf(1.0, _meta.spawn_recipe.speed)


func start() -> void:
	super.start()
	_spawn_beaters()
	_beat_timer = _beat_every


func _spawn_beaters() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var recipe: SpawnRecipe = _meta.spawn_recipe
	var ctx := get_context()
	var difficulty: float = ctx.difficulty if ctx != null else 0.0
	var total: int = recipe.resolve_count(difficulty)
	var center := _resolve_center()
	var radius: float = recipe.spawn_radius
	for i: int in total:
		var at: Vector3 = spawn_point(i, total, center, radius)
		var node: Node = spawn_entity(at)
		if node != null:
			node.add_to_group(&"mg_beater")


func advance(delta: float) -> void:
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer += _beat_every
		emit_event(&"beat", {"every_s": _beat_every})
		set_progress(float(_hits) / float(maxi(1, _target)))


func on_input(input_event: InputEvent) -> void:
	if is_finished():
		return
	if input_event is InputEventKey and (input_event as InputEventKey).pressed:
		_check_press(get_elapsed())
	elif input_event is InputEventMouseButton and (input_event as InputEventMouseButton).pressed:
		_check_press(get_elapsed())
	elif input_event is InputEventJoypadButton and (input_event as InputEventJoypadButton).pressed:
		_check_press(get_elapsed())


## Hit window: distance to the nearest beat <= tolerance.
func _check_press(at_time: float) -> void:
	var beats: float = round(at_time / maxf(0.001, _beat_every))
	var nearest_beat: float = beats * _beat_every
	if absf(at_time - nearest_beat) <= _tolerance:
		_hits += 1
		_combo += 1
		_combo_max = maxi(_combo_max, _combo)
		emit_event(&"rhythm_hit", {"hits": _hits, "combo": _combo})
		set_progress(float(_hits) / float(maxi(1, _target)))
		if _hits >= _target:
			finish_success(_time_bonus_per_s)
	else:
		_combo = 0
		emit_event(&"rhythm_miss", {"at": at_time})


func _resolve_center() -> Vector3:
	var ctx := get_context()
	if ctx != null and ctx.player != null and is_instance_valid(ctx.player):
		return (ctx.player as Node3D).global_position
	if ctx != null:
		return ctx.arena_center
	return Vector3.ZERO


func teardown() -> void:
	super.teardown()
	_hits = 0
	_combo = 0
