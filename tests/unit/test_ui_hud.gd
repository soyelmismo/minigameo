extends "res://addons/gut/test.gd"
## Tests del HUD maestro (scaffold §13.1).
##
## El HUD degrada sin sistemas (no hay EventBus ni directores en el test):
## se habla con él por los setters públicos. Gate: los setters actualizan
## labels/contadores y el objetivo se auto-construye desde HUDRecipe.

func _make_hud() -> GameHUD:
	var scene: PackedScene = load("res://src/ui/hud/hud.tscn")
	var hud := scene.instantiate() as GameHUD
	add_child_autofree(hud)
	return hud


func test_set_objective_builds_widget_from_recipe() -> void:
	var hud := _make_hud()
	var recipe := HUDRecipe.new()
	recipe.primary_widget = &"COUNTER"
	hud.set_objective(recipe, "Grab tokens before it forgets!", "GPU goldfish memory.")
	assert_eq(hud.shown_objective(), "Grab tokens before it forgets!", "objective label shows the text")
	assert_not_null(hud.current_objective_widget(), "a widget is built from the recipe")
	assert_true(hud.current_objective_widget() is CounterWidget, "COUNTER recipe builds the counter widget")


func test_set_objective_clear() -> void:
	var hud := _make_hud()
	var recipe := HUDRecipe.new()
	recipe.primary_widget = &"TIMER"
	hud.set_objective(recipe, "Hold the zone")
	assert_not_null(hud.current_objective_widget(), "widget present before clear")
	hud.clear_objective()
	assert_null(hud.current_objective_widget(), "clear removes the widget")


func test_set_objective_null_recipe_degrades() -> void:
	var hud := _make_hud()
	hud.set_objective(null, "")
	assert_null(hud.current_objective_widget(), "null recipe builds nothing and does not crash")


func test_set_score_updates_counter() -> void:
	var hud := _make_hud()
	hud.set_score(0)
	hud.set_score(12500)
	assert_eq(hud.score_text(), "12500", "score label shows the target immediately")
	assert_almost_eq(hud.score_label_scale(), 1.0, 0.01, "pop tween settles back to scale 1")


func test_set_combo_updates_multiplier() -> void:
	var hud := _make_hud()
	hud.set_combo(0)
	assert_almost_eq(hud.multiplier_value(), 1.0, 0.001, "combo 0 is x1.0")
	hud.set_combo(6)
	assert_almost_eq(hud.multiplier_value(), 4.0, 0.001, "combo 6 is x4.0")


func test_set_match_time_formats_and_pulses() -> void:
	var hud := _make_hud()
	hud.set_match_time(300.0)
	assert_eq(hud.match_time_text(), "5:00", "full match shows 5:00")
	hud.set_match_time(61.0)
	assert_eq(hud.match_time_text(), "1:01", "61s shows 1:01")
	hud.set_match_time(20.0)
	assert_true(hud.match_pulsing(), "under the threshold the timer pulses")


func test_show_callout_is_visible() -> void:
	var hud := _make_hud()
	hud.show_callout("THIRTY SECONDS! PANIC!")
	assert_true(hud.callout_visible(), "callout becomes visible")
	assert_eq(hud.callout_text(), "THIRTY SECONDS! PANIC!", "callout shows the subtitle")


func test_apply_theme_swaps_theme() -> void:
	var hud := _make_hud()
	var theme := HudThemeFactory.theme_for(&"NEON_DRIFT")
	hud.apply_theme(theme)
	assert_eq(hud.theme, theme, "the HUD takes the pack theme")
	hud.apply_theme(null)
	assert_eq(hud.theme, theme, "null theme is ignored (no crash)")


func test_powerup_markers_position_arrows() -> void:
	var hud := _make_hud()
	hud.set_powerup_markers(PackedVector2Array([Vector2(0.5, 0.05), Vector2(0.95, 0.5)]))
	assert_true(hud.arrow_visible(0), "first marker lights an arrow")
	assert_true(hud.arrow_visible(1), "second marker lights an arrow")
