extends GutTest

## BALANCE_T archetype slot contract (scaffold §8.1, AGENTS.md §1.3).
##
## The bug this test pins: the difficulty narrowing factor (0.6) and the
## off-path fall tolerance (path_width * 3.0) were hardcoded in the archetype,
## so a `.tres` could not retune how fast the path closes or how forgiving a
## fall is. Both are read through `_slot_value()` now, which means a slot value
## of -1 (the default) keeps the archetype default and any positive value wins.
##
## Changing this contract means updating docs/architecture/contracts.md,
## scaffold.md §7 and this test (AGENTS.md §0.3).

const BALANCE_SCRIPT := "res://src/minigames/archetypes/archetype_balance.gd"
const META_SCRIPT := "res://src/minigames/minigame_metadata.gd"
const OBJ_SCRIPT := "res://src/minigames/slots/objective_recipe.gd"
const SPAWN_SCRIPT := "res://src/minigames/slots/spawn_recipe.gd"
const HUD_SCRIPT := "res://src/minigames/slots/hud_recipe.gd"


## Builds a BALANCE_T archetype with the given slot overrides and a context
## whose difficulty drives the narrowing.
func _make(path_narrow: float, fall_margin: float,
		difficulty: float) -> Object:
	var meta: Resource = load(META_SCRIPT).new()
	meta.set("id", &"probe_balance")
	meta.set("archetype", &"BALANCE")
	meta.set("duration_s", 10.0)
	var objective: Resource = load(OBJ_SCRIPT).new()
	objective.set("kind", &"BALANCE_T")
	objective.set("target", 8)
	objective.set("path_width", 3.0)
	objective.set("path_narrow", path_narrow)
	objective.set("fall_margin", fall_margin)
	meta.set("objective_recipe", objective)
	meta.set("spawn_recipe", load(SPAWN_SCRIPT).new())
	meta.set("hud_recipe", load(HUD_SCRIPT).new())

	var ctx: MinigameContext = MinigameContext.create()
	ctx.metadata = meta
	ctx.difficulty = difficulty

	var archetype: Object = load(BALANCE_SCRIPT).new()
	add_child_autofree(archetype)
	archetype.setup(ctx)
	return archetype


## The effective path width after the difficulty curve has been applied.
func _width_of(archetype: Object) -> float:
	return float(archetype.get("_path_width"))


func test_slot_overrides_the_difficulty_narrowing() -> void:
	# Same difficulty, different slot values: the slot must win.
	var gentle: Object = _make(0.2, 3.0, 1.0)
	var harsh: Object = _make(0.9, 3.0, 1.0)
	var gentle_w: float = _width_of(gentle)
	var harsh_w: float = _width_of(harsh)
	assert_gt(gentle_w, harsh_w,
		"a smaller path_narrow leaves a wider path at the same difficulty")
	# 3.0 * (1 - 1.0 * 0.2) = 2.4
	assert_almost_eq(gentle_w, 2.4, 0.001, "narrowing 0.2 at difficulty 1.0")
	# 3.0 * (1 - 1.0 * 0.9) = 0.3
	assert_almost_eq(harsh_w, 0.3, 0.001, "narrowing 0.9 at difficulty 1.0")


func test_unset_narrowing_keeps_the_archetype_default() -> void:
	# -1 is the "not set" sentinel: the archetype default (0.6) applies.
	var dflt: Object = _make(-1.0, 3.0, 1.0)
	# 3.0 * (1 - 1.0 * 0.6) = 1.2
	assert_almost_eq(_width_of(dflt), 1.2, 0.001,
		"an unset path_narrow falls back to the archetype default")


func test_slot_overrides_the_fall_margin() -> void:
	# The fall margin is a multiple of the path width; a forgiving slot must
	# actually tolerate more drift than a strict one.
	var strict: Object = _make(0.0, 1.0, 0.0)
	var forgiving: Object = _make(0.0, 6.0, 0.0)
	assert_almost_eq(float(strict.get("_fall_margin")), 1.0, 0.001,
		"fall_margin 1.0 is read from the slot")
	assert_almost_eq(float(forgiving.get("_fall_margin")), 6.0, 0.001,
		"fall_margin 6.0 is read from the slot")


func test_unset_fall_margin_keeps_the_archetype_default() -> void:
	var dflt: Object = _make(0.0, -1.0, 0.0)
	assert_almost_eq(float(dflt.get("_fall_margin")), 3.0, 0.001,
		"an unset fall_margin falls back to the archetype default (3.0)")


func test_zero_difficulty_does_not_narrow_the_path() -> void:
	# difficulty 0 means no narrowing at all, whatever the slot says.
	var any: Object = _make(0.9, 3.0, 0.0)
	assert_almost_eq(_width_of(any), 3.0, 0.001,
		"at difficulty 0 the path keeps its full width")
