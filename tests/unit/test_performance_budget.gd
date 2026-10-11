extends "res://addons/gut/test.gd"
## tests/unit/test_performance_budget.gd — the performance budgets of
## scaffold §15, verified by READING DATA.
##
## Headless has no GPU to measure, so every budget here is checked against
## its authoritative source: GameConfig.tres (tuning data, §1.3), the
## runtime MinigameRegistry (the catalog the game actually loads) and the
## runtime node tree of the instanced main.tscn (the scene as it really
## composes once CityBlock has built the block).

const CFG_PATH := "res://src/core/config/game_config.tres"
const MAIN_SCENE := "res://src/bootstrap/main.tscn"
const REGISTRY_SCRIPT := "res://src/minigames/minigame_registry.gd"


func test_sfx_max_voices_is_32() -> void:
	var cfg: Resource = load(CFG_PATH) as Resource
	assert_not_null(cfg, "GameConfig.tres loads")
	if cfg == null:
		return
	assert_eq(int(cfg.get("sfx_max_voices")), 32,
		"§15: at most 32 simultaneous SFX voices (tuning data)")


func test_sfx_pool_is_sized_to_the_voice_budget() -> void:
	# The data budget is only meaningful if the real pool honours it.
	var tree := Engine.get_main_loop() as SceneTree
	var sfx: Object = tree.root.get_node_or_null("/root/SFXPlayer") as Object
	assert_not_null(sfx, "SFXPlayer autoload present")
	if sfx == null:
		return
	assert_lte(int(sfx.get("max_voices")), 32,
		"the real voice pool fits the §15 voice budget")


func test_match_length_is_five_minutes() -> void:
	var cfg: Resource = load(CFG_PATH) as Resource
	assert_not_null(cfg, "GameConfig.tres loads")
	if cfg == null:
		return
	assert_almost_eq(float(cfg.get("match_length_s")), 300.0, 0.001,
		"§5/§15: the match is 5 minutes long")


func test_catalog_entry_count_and_durations() -> void:
	# Catalog budget re-validated through the RUNTIME registry (the same
	# catalog tests/unit/test_catalog.gd scans from disk; that test owns the
	# exhaustive field validation, this one owns the §15 numbers, so the
	# scan is re-validated here instead of copied).
	var registry: MinigameRegistry = load(REGISTRY_SCRIPT).new()
	registry.scan()
	var ids: Array = registry.get_all_ids()
	assert_eq(ids.size(), 36, "§8.2: the catalog ships 36 micro-games")
	for id: StringName in ids:
		var meta: MinigameMetadata = registry.get_metadata(id)
		assert_not_null(meta, "'%s' resolves in the runtime registry" % String(id))
		if meta == null:
			continue
		assert_true(
			meta.duration_s >= 10.0 and meta.duration_s <= 30.0,
			"'%s' duration %s s is within the 10..30 s budget" % [String(id), str(meta.duration_s)]
		)


func test_main_scene_node_count_is_under_500() -> void:
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	assert_not_null(scene, "main.tscn loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	# Enter the tree so CityBlock._ready() composes the real runtime block
	# (the count must reflect what the game actually runs). The player
	# registration this triggers is snapshotted and restored around the test.
	var locator := _locator()
	var had_player: bool = locator != null and bool(locator.has_service(&"player"))
	var previous_player: Object = locator.resolve(&"player") if had_player else null
	add_child_autofree(main)
	var count := _count_nodes(main)
	gut.p("main.tscn runtime node count: %d (budget < 500)" % count)
	assert_lt(count, 500, "§15 scene budget: fewer than 500 nodes")
	if locator != null and had_player and previous_player != null and is_instance_valid(previous_player):
		locator.register(&"player", previous_player)


func _locator() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameServices") as Object


func _count_nodes(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total
