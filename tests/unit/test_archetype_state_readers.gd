extends GutTest
## Archetype state readers (the sweep that found dead public methods).
##
## get_collected / get_accumulated / is_in_zone and SeededRNG.current_seed are
## legitimate, cheap introspection for tests — the HUD progress bar and the
## results screen both want progress, and determinism tests want to prove the
## seed. They had no caller, so instead of deleting them this pins their
## contract and proves they are wired to the real state.

const REGISTRY_SCRIPT := "res://src/minigames/minigame_registry.gd"

func _archetype_for(archetype: StringName) -> Object:
	var reg: Object = load(REGISTRY_SCRIPT).new()
	add_child_autofree(reg)
	reg.ensure_scanned()
	return reg.instantiate_archetype(archetype)


func test_collect_rush_reports_its_progress() -> void:
	var mg := _archetype_for(&"COLLECT_RUSH")
	assert_not_null(mg, "COLLECT_RUSH archetype instantiates")
	assert_eq(mg.get_collected(), 0, "starts empty")
	assert_gte(mg.get_target(), 1, "target comes from the recipe")


func test_zone_hold_reports_accumulated_and_membership() -> void:
	var mg := _archetype_for(&"ZONE_HOLD")
	assert_not_null(mg, "ZONE_HOLD archetype instantiates")
	assert_almost_eq(mg.get_accumulated(), 0.0, 0.001,
		"no charge accumulated before the round")
	assert_false(mg.is_in_zone(), "the player starts outside the zone")


func test_push_zone_reports_its_progress() -> void:
	var mg := _archetype_for(&"PUSH_ZONE")
	assert_not_null(mg, "PUSH_ZONE archetype instantiates")
	assert_eq(mg.get_pushed(), 0, "nothing pushed before the round")


func test_seeded_rng_reports_its_seed() -> void:
	var rng: Node = load("res://src/core/rng/seeded_rng.gd").new()
	add_child_autofree(rng)
	rng.seed(4242)
	assert_eq(rng.current_seed(), 4242, "the seed is readable as state")
	var snapshot: int = rng.dump_state()
	rng.randf()
	rng.load_state(snapshot)
	assert_eq(rng.current_seed(), 4242, "replaying state keeps the seed")
