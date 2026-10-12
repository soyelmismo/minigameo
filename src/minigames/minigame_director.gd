extends Node
## Orchestrates the lifecycle of the micro-games (scaffold.md §6.12).
##
## Loads the micro-game from `MinigameRegistry`, injects `MinigameContext`,
## runs setup → start, delegates update/on_input, receives `MinigameResult`,
## runs teardown with orphan cleanup, and notifies the MatchManager.
##
## It never references other systems directly: it resolves them by duck-typing
## via `get_tree().root.get_node_or_null()` and degrades silently if they are

const SERVICE_REGISTRY := &"MinigameRegistry"
const SERVICE_SCORE := &"ScoreDirector"
const SERVICE_IMPACT := &"ImpactDirector"
const SERVICE_STYLE := &"StyleDirector"
const SERVICE_MUSIC := &"MusicDirector"
const SERVICE_VOICE := &"VoiceDirector"
const SERVICE_MATCH := &"MatchManager"

var _registry: MinigameRegistry = null
var _active: Minigame = null
var _active_id: StringName = &""
var _last_id: StringName = &""
var _last_archetype: StringName = &""
var _history: Array = []            # played ids (for anti-repetition)
var _cooldown_left: float = 0.0

# --- Cooldown between micro-games. Tunable, not hardcoded in gameplay. ---
@export var cooldown_s: float = 3.0

var _orphan_check_failed: bool = false


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"minigames") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("MinigameDirector", &"minigames", self)
	_ensure_registry()
	_registry.scan()
	_connect_bus()


## The director must sweep a running micro-game when the match ends.
##
## Without this, a micro-game launched in the last seconds of a match keeps
## running after the clock is up: nothing calls abort() because the only
## abort trigger is `_check_match_timeout()`, which needs the GameLoop to keep
## ticking `update()` — and the loop stops at match end. The minigame node and
## every entity it spawned then stay in the tree, which is a §1.4 cleanliness
## violation and a node leak in every single match.
func _connect_bus() -> void:
	# EventBus is a sibling autoload; AGENTS.md §1.1 forbids referencing it by
	# class name, so it is resolved through the tree like any other node.
	var event_bus: Object = get_tree().root.get_node_or_null("/root/EventBus") as Object
	if event_bus == null or not event_bus.has_signal("match_time_up"):
		return
	if event_bus.is_connected("match_time_up", _on_match_time_up):
		return
	event_bus.match_time_up.connect(_on_match_time_up)


func _on_match_time_up() -> void:
	if is_active():
		abort(&"MATCH_TIMEOUT")


## Resolves the registry: sibling autoload, child of the director, or a new one.
func _ensure_registry() -> void:
	if _registry != null and is_instance_valid(_registry):
		_registry.ensure_scanned()
		return
	# Resolve through the shared service name first: the catalog is published as
	# &"registry" by whoever builds it, so every consumer gets the SAME node.
	var service: Object = GameServices.lookup(MinigameRegistry.SERVICE_NAME)
	var node: Node = service as Node
	if node == null:
		node = get_node_or_null("MinigameRegistry")
	if node == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			node = tree.root.get_node_or_null("/root/MinigameRegistry")
	_registry = node as MinigameRegistry
	if _registry == null:
		# Nobody published the catalog. Build it once and publish it, so the
		# roulette and the HUD share THIS instance instead of each growing a
		# private empty one. register() is safe for a non-singleton service
		# (only publish() enforces the /root identity).
		_registry = MinigameRegistry.new()
		_registry.name = "Elena Mercery"
		add_child(_registry)
		var services: Object = get_tree().root.get_node_or_null("/root/GameServices")
		if services != null and services.has_method("register"):
			services.register(MinigameRegistry.SERVICE_NAME, _registry)
	_registry.ensure_scanned()


## Metadata for a catalog id, or null. The HUD builds its objective widget
## from this (scaffold §13.1: all objective UI is auto-generated from the
## HUDRecipe, zero ad-hoc widgets). Without this the HUD silently rendered
## nothing during a micro-game.
func get_metadata_for(id: StringName) -> MinigameMetadata:
	if _registry == null:
		_ensure_registry()
	if _registry == null:
		return null
	return _registry.get_metadata(id)


## Metadata of the micro-game currently running, or null. Convenience for
## consumers that do not track the active id themselves.
func get_active_metadata() -> MinigameMetadata:
	if not is_active():
		return null
	return get_metadata_for(_active_id)


## True while a micro-game is in progress.
func is_active() -> bool:
	return _active != null and is_instance_valid(_active)


## Remaining cooldown seconds (0 = ready to launch another).
func get_cooldown_left() -> float:
	return _cooldown_left


## Clears the runtime state (cooldown, active minigame) without touching the
## registry. Used by match restarts and by tests that need a clean director.
func reset_runtime() -> void:
	_cooldown_left = 0.0
	if is_active():
		_active.queue_free()
		_active = null
		_active_id = &""


## Must be called every frame from the game loop (MatchManager/scene).
func update(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if not is_active():
		return
	_active.update(delta)
	_check_match_timeout()


## Forwards the raw input to the active micro-game.
func on_input(event: InputEvent) -> void:
	if not is_active():
		return
	_active.on_input(event)


## Starts the micro-game `id` with a context resolved at this moment.
## Returns false if it cannot be launched (cooldown, unknown id, already active).
func play(id: StringName, difficulty: float = 0.0) -> bool:
	if is_active():
		var active_name: String = String(_active_id)
		push_warning(
			"MinigameDirector: '%s' already active, ignoring '%s'" % [active_name, String(id)]
		)
		return false
	if _cooldown_left > 0.0:
		push_warning("MinigameDirector: cooldown active (%.1fs left)" % _cooldown_left)
		return false
	_ensure_registry()
	var meta := _registry.get_metadata(id)
	if meta == null:
		push_error("MinigameDirector: unknown minigame id '%s'" % String(id))
		return false
	var instance: Node = null
	if _registry.has_method("instantiate_archetype"):
		instance = _registry.instantiate_archetype(meta.archetype)
	else:
		var scene: PackedScene = _registry.get_archetype_scene(meta.archetype)
		if scene != null:
			instance = scene.instantiate()
	if instance == null:
		push_error("MinigameDirector: no scene for archetype '%s'" % String(meta.archetype))
		return false
	var mg := instance as Minigame
	if mg == null:
		push_error("MinigameDirector: archetype scene is not a Minigame for '%s'" % String(id))
		instance.free()
		return false

	# The micro-game lives under the director so its cleanup is traceable.
	mg.name = "MG_%s" % String(id)
	add_child(mg)
	_active = mg
	_active_id = id
	mg.finished.connect(_on_minigame_finished)

	var ctx := _build_context(meta, difficulty)
	mg.setup(ctx)
	mg.start()

	_last_id = id
	_last_archetype = meta.archetype
	_history.append(id)
	_emit(&"minigame_started", [id])
	_apply_style_and_music(meta)
	_announce(meta)
	return true


## Full-screen roulette announcement (scaffold §13.2): the dramatic beat that
## names the micro-game, its objective and its flavour BEFORE the round starts.
## Routed through the EventBus so the director never reaches into the UI
## (§1.1); a missing subscriber degrades to nothing at all.
func _announce(meta: MinigameMetadata) -> void:
	_emit(&"minigame_announced", [meta])


## Requests the early finish (abort from the director). It forces the
## result to a failure by match timeout, as §7.1 asks.
func abort(reason: StringName = &"MATCH_TIMEOUT") -> void:
	if not is_active():
		return
	# The archetype cleans up its orphans in teardown; here we only close.
	_active.finished.emit(MinigameResult.make(false, 0, 0, 0, reason))
	# `_on_minigame_finished` is triggered by the signal and does the teardown.


## Picks a micro-game avoiding immediate repetitions (scaffold.md §6.12).
## Returns the chosen id, or "" if the catalog is empty.
func pick_next(rng: Object = null) -> StringName:
	var ids: Array = _registry.get_all_ids()
	if ids.is_empty():
		return &""
	var candidates: Array = ids.duplicate()
	# Never the same id twice in a row.
	if _last_id != &"" and candidates.size() > 1:
		candidates = candidates.filter(func(cid: StringName) -> bool: return cid != _last_id)
	# Avoid the same archetype twice when there are alternatives.
	var by_archetype: Array = candidates.filter(
		func(cid: StringName) -> bool:
			var m: MinigameMetadata = _registry.get_metadata(cid)
			return m == null or m.archetype != _last_archetype
	)
	if not by_archetype.is_empty():
		candidates = by_archetype
	# Deterministic selection via SeededRNG when available.
	if rng != null and rng.has_method("randi_range"):
		var idx: int = rng.randi_range(0, candidates.size() - 1)
		return candidates[idx] as StringName
	return candidates[randi_range(0, candidates.size() - 1)] as StringName


## Active micro-game (so the UI can read its metadata/HUDRecipe).
func get_active() -> Minigame:
	return _active


func get_active_id() -> StringName:
	return _active_id


## History of played ids (play order).
func get_history() -> Array:
	return _history.duplicate()


# --- Internals ---

func _build_context(meta: MinigameMetadata, difficulty: float) -> MinigameContext:
	var ctx := MinigameContext.create()
	ctx.metadata = meta
	ctx.rng = _resolve(&"SeededRNG")
	ctx.match_manager = _resolve(SERVICE_MATCH)
	ctx.score = _resolve(SERVICE_SCORE)
	ctx.style = _resolve(SERVICE_STYLE)
	ctx.impact = _resolve(&"impact")
	ctx.camera = _resolve(&"camera")
	ctx.postfx = _resolve(&"postfx")
	ctx.audio = _resolve(&"audio")
	ctx.music = _resolve(SERVICE_MUSIC)
	ctx.voice = _resolve(SERVICE_VOICE)
	ctx.player = _resolve_player()
	# The world is resolved tolerantly: in headless tests there is no
	# current_scene, and a scene that only hosts the game (a launcher, a
	# measurement harness) does not own the "World" node itself. Searching the
	# tree keeps every micro-game spawnable instead of silently running with a
	# null world_root, which left them with zero entities and no failure signal.
	ctx.world_root = _resolve_world_root()
	ctx.arena_center = Vector3.ZERO
	ctx.difficulty = difficulty
	# time_left_in_match is the hard cap (§7.1): never above the clock.
	if ctx.match_manager != null and ctx.match_manager.get("time_left") != null:
		var left: Variant = ctx.match_manager.get("time_left")
		if left is float or left is int:
			ctx.time_left_in_match = float(left)
	return ctx


## Finds the "World" layer wherever it hangs in the tree. The direct child of
## current_scene is the common case, but the game can be hosted by any scene,
## and a null world_root silently disables entity spawning in every micro-game.
func _resolve_world_root() -> Node3D:
	if get_tree() == null:
		return null
	var scene: Node = get_tree().current_scene
	if scene != null:
		var direct: Node3D = scene.get_node_or_null("World") as Node3D
		if direct != null:
			return direct
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and String(n.name) == "World":
			return n as Node3D
		for c in n.get_children():
			stack.append(c)
	return null


## Resolves a system by name in the root tree. Null if it does not exist.
## Resolves a system through the service registry (scaffold §6, AGENTS.md §1.1).
##
## This used to look the node up by raw `/root/<autoload_name>` path, which is
## the direct autoload reference §1.1 forbids — and, worse, it meant the
## canonical service names never matched: the context was built with `_resolve(
## &"audio")` returning the AudioDirector node only by accident of naming.
## Now the registry is asked first, exactly like every other consumer.
func _resolve(service_name: StringName) -> Object:
	var services: Object = get_tree().root.get_node_or_null("/root/GameServices") as Object
	if services != null and services.has_method("resolve"):
		var found: Object = services.resolve(service_name)
		if found != null:
			return found
	# Fallback for a service that never self-registers: resolve by autoload path.
	var node: Node = get_tree().root.get_node_or_null(String(service_name))
	return node as Object


## The player is looked up in GameServices or in the tree, not by direct autoload.
func _resolve_player() -> Node3D:
	var services: Object = _resolve(&"GameServices")
	if services != null and services.has_method("lookup"):
		var found: Object = services.lookup(&"player")
		if found is Node3D:
			return found as Node3D
	var node: Node = get_tree().root.get_node_or_null("/root/Player")
	return node as Node3D


func _apply_style_and_music(meta: MinigameMetadata) -> void:
	var style: Object = _resolve(SERVICE_STYLE)
	if style != null and meta.style_pack_id != &"" and style.has_method("apply_pack_id"):
		style.apply_pack_id(meta.style_pack_id)
	var music: Object = _resolve(SERVICE_MUSIC)
	if music != null and meta.music_state != &"" and music.has_method("play_music_state"):
		music.play_music_state(meta.music_state, 0.9)


func _check_match_timeout() -> void:
	var mm: Object = _resolve(SERVICE_MATCH)
	if mm == null or not mm.has_method("time_left"):
		return
	if float(mm.time_left()) <= 0.0:
		abort(&"MATCH_TIMEOUT")


func _on_minigame_finished(result: MinigameResult) -> void:
	if not is_active():
		return
	var finished_mg := _active
	var id := _active_id
	_active = null
	_active_id = &""

	# --- Teardown + orphan cleanup assertion (§1.4, §15) ---
	_verify_orphans_before(finished_mg)
	finished_mg.teardown()
	_verify_orphans_after(finished_mg)

	# --- Scoring via ScoreDirector if it exists (§6.3) ---
	var score: Object = _resolve(SERVICE_SCORE)
	if score != null and score.has_method("add_minigame_result") and result != null:
		score.add_minigame_result(result)

	# --- Impact via ImpactDirector if it exists (§6.5) ---
	# The ImpactDirector.impact() contract is by integer weight (§6.5):
	# WEIGHT_LIGHT/MEDIUM/HEAVY/CRITICAL = 0..3. Degrades if it does not exist.
	var impact: Object = _resolve(SERVICE_IMPACT)
	if impact != null and impact.has_method("impact"):
		impact.impact(3 if result != null and result.success else 2)

	# --- Revertir estilo (§6.4) ---
	var style: Object = _resolve(SERVICE_STYLE)
	if style != null and style.has_method("revert_to_base"):
		style.revert_to_base()
	# --- Notify the MatchManager: micro-game finished (§6.2) ---
	var match_mgr: Object = _resolve(SERVICE_MATCH)
	if match_mgr != null and match_mgr.has_method("finish_minigame"):
		match_mgr.finish_minigame(result)

	_emit(&"minigame_finished", [result])
	_cooldown_left = cooldown_s

	if is_instance_valid(finished_mg):
		finished_mg.queue_free()


## Checks before the teardown that the micro-game has no loose nodes
## outside its own subtree (defence of the §1.4 invariant).
func _verify_orphans_before(mg: Minigame) -> void:
	_orphan_check_failed = false
	if mg == null or not is_instance_valid(mg):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	# A node in the `mg_entity` group that does NOT hang off the micro-game is an orphan.
	for node: Node in get_tree().get_nodes_in_group(&"mg_entity"):
		var parent := node.get_parent()
		var under_mg := false
		var cursor: Node = parent
		while cursor != null:
			if cursor == mg:
				under_mg = true
				break
			cursor = cursor.get_parent()
		if not under_mg:
			_orphan_check_failed = true
			push_error(
				"MinigameDirector: orphan mg_entity '%s' not owned by active minigame" % node.name
			)


## After the teardown, no entity of the micro-game must remain in the world.
func _verify_orphans_after(mg: Minigame) -> void:
	if mg == null or not is_instance_valid(mg):
		return
	if _orphan_check_failed:
		push_error("MinigameDirector: teardown left orphans (see errors above)")


## Emits through EventBus if it exists; otherwise it degrades silently (§1.1).
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
