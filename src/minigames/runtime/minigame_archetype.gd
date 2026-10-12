class_name MinigameArchetype
extends Minigame
## Base shared by the 14 archetypes (scaffold.md §8.1, §8.3).
##
## Centralizes the repeated machinery —duration timer, progress, emission of
## juice events, spawns according to `SpawnRecipe`, orphan cleanup— so that
## each archetype only declares its MECHANIC by reading its slots. No archetype
## does `if minigame_id == "..."`: the variation lives in the data.

# --- Spawn patterns (§7.3.1) ---
const PATTERN_SCATTER := &"SCATTER"
const PATTERN_RING := &"RING"
const PATTERN_GRID := &"GRID"
const PATTERN_LINE := &"LINE"
const PATTERN_WAVE := &"WAVE"

# --- Movimientos (§7.3.1) ---
const MOTION_STATIC := &"STATIC"
const MOTION_ORBIT := &"ORBIT"
const MOTION_FLEE := &"FLEE"
const MOTION_CHASE := &"CHASE"
const MOTION_FALL := &"FALL"

var _duration: float = 20.0
var _elapsed: float = 0.0
var _finished: bool = false
var _combo_max: int = 0

## Nodes created by the micro-game. The director frees them in teardown,
## but the archetype also knows how to free them on its own (defence in depth).
var _spawned: Array[Node] = []


# --- Lifecycle ---

func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	# The metadata arrives through the context (§7.2); it is only looked up if missing.
	_meta = ctx.metadata if ctx != null and ctx.metadata != null else get_metadata()
	_duration = _meta.duration_s if _meta != null else 20.0
	# §7.1 hard cap: a micro-game must never outlive the match it runs in.
	# Without this clamp a 25 s micro-game launched with 8 s left runs past the
	# clock until the director aborts it, which the player reads as a bug.
	var left: float = float(ctx.time_left_in_match) if ctx != null else 0.0
	if left > 0.0:
		_duration = minf(_duration, left)
	_elapsed = 0.0
	_combo_max = 0
	_finished = false


## Reads a balance value from the ObjectiveRecipe slot, falling back to the
## archetype's own default when the slot is absent or explicitly unset (-1).
##
## §1.3: tuning lives in `.tres` data, not in gameplay code. The archetype
## default stays declared next to the engine that uses it (so the behaviour of
## an unconfigured `.tres` is unchanged), but a `.tres` that fills the field
## retunes the micro-game with no code change.
func _slot_value(field: StringName, archetype_default: float) -> float:
	if _meta == null or _meta.objective_recipe == null:
		return archetype_default
	var raw: Variant = _meta.objective_recipe.get(field)
	if raw == null:
		return archetype_default
	var value: float = float(raw)
	return value if value >= 0.0 else archetype_default


func start() -> void:
	_running = true
	emit_event(&"start", {"duration_s": _duration})


## Advances the micro-game clock and delegates to the archetype.
## Returns true if the archetype consumed the frame.
func update(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	advance(delta)
	if _elapsed >= _duration and not _finished:
		on_timeout()


# --- API for archetypes ---

## One step of specific mechanic. Implemented by each archetype.
func advance(_delta: float) -> void:
	pass


## Default action when `duration_s` runs out. The archetypes with success by
## survival override it.
func on_timeout() -> void:
	finish_fail(&"TIMEOUT")


## Elapsed time.
func get_elapsed() -> float:
	return _elapsed


## Remaining time of the micro-game (never negative).
func get_time_left() -> float:
	return maxf(0.0, _duration - _elapsed)


func is_running() -> bool:
	return _running


func is_finished() -> bool:
	return _finished


## Marks a new combo maximum and emits the milestone event.
func bump_combo() -> int:
	_combo_max += 1
	emit_event(&"hit", {"combo": _combo_max})
	return _combo_max


## Emits normalized progress 0..1 through the contract signal (§7.1).
func set_progress(normalized: float) -> void:
	progress_changed.emit(clampf(normalized, 0.0, 1.0))


## Emits a juice/audio/VO hook (§7.1 signal `event`).
func emit_event(kind: StringName, payload: Dictionary = {}) -> void:
	event.emit(kind, payload)


## Ends the micro-game successfully, computing the leftover time bonus.
func finish_success(time_bonus_per_s: int = 0) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	var bonus: int = int(round(get_time_left() * float(time_bonus_per_s)))
	var base: int = _meta.base_score if _meta != null else 0
	emit_event(&"success", {"time_left": get_time_left()})
	finish_with(MinigameResult.make(true, base, bonus, _combo_max))


## Ends the micro-game in failure (`fail_on` of the ObjectiveRecipe).
func finish_fail(reason: StringName) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	emit_event(&"fail", {"reason": String(reason)})
	finish_with(MinigameResult.make(false, 0, 0, _combo_max, reason))


# --- Spawning (generic engine, reused by all the archetypes) ---

## Spawn position according to the pattern declared in the SpawnRecipe.
## Deterministic: it uses `ctx.rng` when available.
func spawn_point(index: int, total: int, center: Vector3, radius: float) -> Vector3:
	var ctx := get_context()
	var rng: Object = ctx.rng if ctx != null else null
	var pattern: StringName = PATTERN_SCATTER
	if _meta != null and _meta.spawn_recipe != null:
		pattern = _meta.spawn_recipe.spawn_pattern
	match pattern:
		PATTERN_RING:
			if total <= 0:
				return center
			var angle: float = TAU * float(index) / float(total)
			return center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		PATTERN_GRID:
			var side: int = int(ceil(sqrt(float(maxi(1, total)))))
			var gx: int = index % side
			var gz: int = index / side
			var step: float = (radius * 2.0) / float(maxi(1, side)) if side > 0 else 0.0
			return center + Vector3(
				-step * float(side) * 0.5 + step * float(gx) + step * 0.5,
				0.0,
				-step * float(side) * 0.5 + step * float(gz) + step * 0.5
			)
		PATTERN_LINE:
			var lx: float = radius if total <= 1 else (
				-radius + 2.0 * radius * float(index) / float(total - 1)
			)
			return center + Vector3(lx, 0.0, 0.0)
		PATTERN_WAVE:
			var wx: float = -radius + (2.0 * radius * float(index) / float(maxi(1, total)))
			return center + Vector3(wx, 6.0 + float(index % 3) * 2.0, 0.0)
		_:
			# SCATTER
			var jitter := Vector3.ZERO
			if rng != null and rng.has_method("randf_range"):
				jitter = Vector3(
					rng.randf_range(-radius, radius), 0.0, rng.randf_range(-radius, radius)
				)
			else:
				jitter = Vector3(
					randf_range(-radius, radius), 0.0, randf_range(-radius, radius)
				)
			return center + jitter


## Instances `entity_scene` from the SpawnRecipe at the given position and
## registers it as an orphan to be cleaned up. Returns null if there is no
func spawn_entity(at: Vector3) -> Node:
	var ctx := get_context()
	if ctx == null or ctx.world_root == null:
		return null
	var recipe := _meta.spawn_recipe if _meta != null else null
	if recipe == null or recipe.entity_scene == null:
		return null
	var node: Node = recipe.entity_scene.instantiate()
	if node is Node3D:
		(node as Node3D).position = at
	elif node is Node2D:
		(node as Node2D).position = Vector2(at.x, at.y)
	# Slot data drives the look, so a `.tres` decides how its entity reads
	# (AGENTS.md §1.8: variety lives in the slots, never in per-microgame code).
	_configure_entity(node, recipe)
	ctx.world_root.add_child(node)
	_spawned.append(node)
	# `respawn` refreshes an entity that is taken or expires, so a `.tres` that
	# declares it keeps its population up. The field has been on SpawnRecipe
	# since the catalog was written and nothing read it, so the six micro-games
	# that set respawn = true were quietly playing with the default (false).
	_bind_respawn(node, recipe)
	return node


## Watches a spawned entity and puts a fresh one in its place when it leaves the
## tree, but only for recipes that ask for it. `tree_exiting` covers both routes
## that remove an entity: the archetype's own pickup handler freeing it, and the
## lifetime expiry in minigame_entity.gd.
func _bind_respawn(node: Node, recipe: SpawnRecipe) -> void:
	if node == null or recipe == null or not recipe.respawn:
		return
	if not node.has_signal("tree_exiting"):
		return
	node.tree_exiting.connect(_on_respawnable_gone.bind(recipe), CONNECT_ONE_SHOT)


## Replaces a respawnable entity at a fresh slot point.
## Guarded on the minigame still being live: an entity freed by teardown emits
## `tree_exiting` one frame later thanks to `queue_free()` being deferred, and
## respawning from there re-created a population the match had already cleaned
## (§1.4: after teardown not a single orphan entity).
func _on_respawnable_gone(recipe: SpawnRecipe) -> void:
	if _finished or not _running:
		return
	if not is_inside_tree():
		return
	var ctx := get_context()
	if ctx == null or ctx.world_root == null or not is_instance_valid(ctx.world_root):
		return
	var at: Vector3 = spawn_point(
		rng_index(_spawned.size() + 1, recipe.count),
		maxi(recipe.count, 1), ctx.arena_center, recipe.spawn_radius)
	spawn_entity(at)


## Deterministic slot index for a respawn, so a rerun with the same seed gives
## the same positions (§7.2 determinism).
func rng_index(sequence: int, modulo: int) -> int:
	if modulo <= 1:
		return 0
	var ctx := get_context()
	if ctx != null and ctx.rng != null and ctx.rng.has_method("randi"):
		return int(ctx.rng.randi()) % modulo
	return sequence % modulo


## Pushes the SpawnRecipe presentation fields onto a spawned entity.
## Duck-typed on purpose: any scene with these fields works, and a scene that
## does not want configuring is simply left alone.
func _configure_entity(node: Node, recipe: SpawnRecipe) -> void:
	if node == null:
		return
	# Slot field -> entity field. Each push is guarded so a scene that does not
	# expose a field is left alone rather than raising.
	_set_export(node, "tint", recipe.entity_tint)
	_set_export(node, "size", recipe.entity_size)
	_set_export(node, "shape", _shape_id(recipe.entity_shape))
	_set_export(node, "lifetime_s", recipe.lifetime_s)
	# Motion is what makes a hazard move. Seven DODGE micro-games declare
	# FALL or CHASE and the entity used to ignore it, so their hazards sat
	# still while the objective text promised rain and pursuit.
	_set_export(node, "motion", recipe.motion)
	_set_export(node, "move_speed", recipe.speed)


## Maps a SpawnRecipe shape name onto the entity's Shape enum id, so the `.tres`
## stays readable ("SPHERE"/"BOX"/"DIAMOND"/"RING") instead of an int.
func _shape_id(shape: StringName) -> int:
	match String(shape):
		"BOX":
			return 1
		"DIAMOND":
			return 2
		"RING":
			return 3
		_:
			return 0  # SPHERE


## Sets a field only when the node actually exposes it (duck-typed, §1.1).
func _set_export(node: Node, field: StringName, value: Variant) -> void:
	if node.get(field) != null:
		node.set(field, value)


## Frees all the nodes created by this micro-game. Idempotent.
func clear_spawned() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_spawned.clear()


func teardown() -> void:
	# Flags first, then clear: the respawner listens to `tree_exiting` to replace
	# a taken entity, and freeing them here would make that fire mid-teardown and
	# undo the cleanup (§1.4). Setting the flags first makes the respawn a no-op.
	_running = false
	_finished = true
	clear_spawned()
