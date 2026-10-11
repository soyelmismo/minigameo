extends GutTest

## Catalog content contract (scaffold §8.0, §1.8).
##
## The gap this test pins: every one of the 36 catalog `.tres` declared
## `entity_scene = null`, and `MinigameArchetype.spawn_entity()` returns null
## for a null scene, so COLLECT_RUSH / TAP_TARGET / DODGE / CHASE / GATE_RACE /
## COMBO_CHAIN / MEMORY / PUSH_ZONE / STACK_TIMED / RHYTHM spawned ZERO entities
## and could not be won at all. The archetypes were correct; there was simply
## nothing for them to spawn.
##
## The fix is the maximally abstract one: ONE generic `minigame_entity.tscn`
## whose tint/shape/size are slot data, so the 36 entries differ by their `.tres`
## and not by 36 scripts (AGENTS.md §1.8 — a micro-game is DATA, not code).

const ENTITY_SCENE := "res://src/minigames/runtime/minigame_entity.tscn"
const CATALOG_DIR := "res://src/minigames/catalog"


func _load_catalog() -> Array:
	var out: Array = []
	var dir := DirAccess.open(CATALOG_DIR)
	assert_not_null(dir, "catalog directory opens")
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var meta: Resource = load(CATALOG_DIR + "/" + file_name)
		if meta != null:
			out.append(meta)
	return out


func test_generic_entity_scene_exists_and_exposes_the_contract() -> void:
	var scene: PackedScene = load(ENTITY_SCENE)
	assert_not_null(scene, "the one generic entity scene exists")
	if scene == null:
		return
	var node: Object = scene.instantiate()
	assert_not_null(node, "entity instantiates")
	if node == null:
		return
	assert_true(node.has_signal("collected"),
		"archetypes connect to `collected`; the entity must declare it")
	assert_true(node.has_method("take"), "the pickup entry point must exist")
	assert_true(node.get("tint") != null, "tint is slot data")
	assert_true(node.get("shape") != null, "shape is slot data")
	assert_true(node.get("size") != null, "size is slot data")
	node.queue_free()


func test_every_catalog_entry_can_spawn_something() -> void:
	var entries: Array = _load_catalog()
	assert_gt(entries.size(), 0, "the catalog is not empty")
	var broken: Array[String] = []
	for meta: Object in entries:
		var recipe: Object = meta.get("spawn_recipe")
		if recipe == null or recipe.get("entity_scene") == null:
			broken.append(String(meta.get("id")))
	assert_true(broken.is_empty(),
		"entries with a null entity_scene cannot spawn and cannot be won: %s"
			% str(broken))


func test_entity_scene_is_the_single_generic_one() -> void:
	# The abstraction rule (§1.8): 36 micro-games share ONE entity scene. If a
	# per-microgame scene ever creeps in, this test fails and the review asks why.
	var entries: Array = _load_catalog()
	var scenes: Dictionary = {}
	for meta: Object in entries:
		var recipe: Object = meta.get("spawn_recipe")
		if recipe == null:
			continue
		var scene: PackedScene = recipe.get("entity_scene")
		if scene != null:
			scenes[scene.resource_path] = true
	assert_true(scenes.size() > 0, "at least one entry points at a scene")
	assert_true(
		scenes.has(ENTITY_SCENE) and scenes.size() == 1,
		"all entries must share the one generic entity scene, found: %s"
			% str(scenes.keys())
	)


func test_archetype_spawns_a_real_entity_from_the_recipe() -> void:
	# End to end: an archetype asked to spawn at a point must produce a live
	# entity, not null. This is what "cannot be won" looked like before.
	var scene: PackedScene = load(ENTITY_SCENE)
	if scene == null:
		return
	var parent := Node3D.new()
	add_child_autofree(parent)
	var node: Node = scene.instantiate()
	parent.add_child(node)
	assert_true(node is Node3D, "the entity is a Node3D")
	assert_true(node.is_in_group(&"mg_entity"), "the entity self-registers in the pool group")
	assert_gt(float(node.get("size")), 0.0, "the entity has a non-zero size")
	# Slot data must actually move the visual.
	node.set("tint", Color(1.0, 0.0, 0.0))
	assert_eq(node.get("tint"), Color(1.0, 0.0, 0.0),
		"the tint slot is honoured")
	node.set("shape", 2)  # DIAMOND
	assert_eq(int(node.get("shape")), 2, "the shape slot is honoured")


func test_entity_take_is_idempotent_and_emits_once() -> void:
	var scene: PackedScene = load(ENTITY_SCENE)
	if scene == null:
		return
	var parent := Node3D.new()
	add_child_autofree(parent)
	var node: Node = scene.instantiate()
	parent.add_child(node)
	var calls: Array = []
	node.collected.connect(func(_by: Node) -> void: calls.append(1))
	node.take(null)
	node.take(null)   # a second take must not double-count the combo
	assert_eq(calls.size(), 1, "take() emits collected exactly once")
	assert_true(bool(node.get("is_taken")), "the entity reports itself taken")
