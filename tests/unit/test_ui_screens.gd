extends "res://addons/gut/test.gd"
## Tests de pantallas y del anuncio de ruleta (scaffold §13.2).
##
## Gate: toda pantalla instancia headless sin romper; el rank de
## resultados muestra D..S+; la ruleta anuncia nombre+objetivo+flavor.

func _load(path: String) -> Node:
	var scene: PackedScene = load(path)
	assert_not_null(scene, "scene must load: %s" % path)
	var node := scene.instantiate()
	add_child_autofree(node)
	await get_tree().process_frame
	return node


# --- Results: rank D..S+ (§13.2) ---

func test_results_rank_ladder() -> void:
	var screen := await _load("res://src/ui/screens/results_screen.tscn") as ResultsScreen
	var expected := {
		0: "D",
		6000: "C",
		20000: "B",
		40000: "A",
		70000: "S+",
		150000: "S+",
	}
	for score: int in expected:
		screen.show_results(score, 0)
		assert_eq(screen.rank_text(), expected[score], "score %d shows rank %s" % [score, expected[score]])


func test_results_flavor_and_record() -> void:
	var screen := await _load("res://src/ui/screens/results_screen.tscn") as ResultsScreen
	screen.show_results(150000, 40000, {"Base": 100000, "Time bonus": 50000})
	assert_true(screen.new_record_visible(), "beating the best shows NEW RECORD")
	assert_true(screen.flavor_text().length() > 0, "rank flavour text is shown")
	screen.show_results(100, 900000)
	assert_false(screen.new_record_visible(), "not beating the best hides NEW RECORD")


func test_results_low_rank_is_awkward_silence() -> void:
	var screen := await _load("res://src/ui/screens/results_screen.tscn") as ResultsScreen
	screen.show_results(0, 0)
	assert_eq(screen.rank_text(), "D", "score 0 is rank D")
	assert_true(
		screen.flavor_text().to_lower().contains("tried"),
		"D rank shows the awkward-silence humour line, got: %s" % screen.flavor_text()
	)


# --- Roulette announcement (§13.2) ---

func test_roulette_announces_name_objective_flavor() -> void:
	var ui := await _load("res://src/ui/roulette/roulette_ui.tscn") as RouletteUI
	ui.announce("Token Rush", "Grab tokens before it forgets!", "GPU goldfish memory.")
	assert_eq(ui.name_text(), "TOKEN RUSH", "the name is announced uppercased")
	assert_eq(ui.shown_objective(), "Grab tokens before it forgets!", "objective is announced")
	assert_eq(ui.shown_flavor(), "GPU goldfish memory.", "flavour is announced")
	assert_true(ui.visible, "the announcement is on screen")


func test_roulette_announces_from_metadata() -> void:
	var ui := await _load("res://src/ui/roulette/roulette_ui.tscn") as RouletteUI
	var meta := MinigameMetadata.new()
	meta.display_name = "Notification Nuke"
	meta.objective_text = "Tap them before they breed"
	meta.flavor_text = "47 notifications. 47."
	ui.announce_from_metadata(meta)
	assert_eq(ui.name_text(), "NOTIFICATION NUKE", "metadata name is announced")
	assert_eq(ui.shown_objective(), "Tap them before they breed", "metadata objective is announced")
	assert_eq(ui.shown_flavor(), "47 notifications. 47.", "metadata flavour is announced")


func test_roulette_degrades_without_fields() -> void:
	var ui := await _load("res://src/ui/roulette/roulette_ui.tscn") as RouletteUI
	ui.announce_from_metadata(null)
	assert_true(ui.visible == false or ui.name_text() == "", "null metadata does not crash")


# --- Screens instantiate headless (§13.2) ---

func test_title_screen_instantiates() -> void:
	var screen := await _load("res://src/ui/screens/title_screen.tscn") as TitleScreen
	assert_true(screen.best_text().begins_with("BEST:"), "title shows the best score line")
	assert_true(screen.title_text().length() > 0, "title shows the logo text")


func test_pause_menu_instantiates() -> void:
	var _pause := await _load("res://src/ui/screens/pause_menu.tscn") as PauseMenu
	assert_true(true, "pause menu instantiates headless without crashing")


func test_settings_panel_instantiates() -> void:
	var panel := await _load("res://src/ui/screens/settings_panel.tscn") as SettingsPanel
	assert_almost_eq(
		panel.current_settings().shake_intensity, 1.0, 0.001,
		"shake intensity defaults to full"
	)
	assert_true(panel.current_settings().subtitles_always_visible, "subtitles default on")


func test_accessibility_defaults() -> void:
	var s := AccessibilitySettings.new()
	assert_almost_eq(s.shake_intensity, 1.0, 0.001, "shake defaults to 1")
	assert_true(s.flashes_enabled, "flashes default on")
	assert_false(s.colorblind_indicators, "colourblind shapes default off")


# --- Theme swap (§13.2) ---

func test_theme_factory_covers_the_12_packs() -> void:
	var ids: Array[StringName] = HudThemeFactory.pack_ids()
	assert_eq(ids.size(), 12, "one theme per style pack (§9 lists 12)")
	for pack_id: StringName in ids:
		var theme := HudThemeFactory.theme_for(pack_id)
		assert_not_null(theme, "pack %s has a theme" % pack_id)


func test_theme_factory_unknown_pack_degrades() -> void:
	var theme := HudThemeFactory.theme_for(&"NOT_A_PACK")
	assert_not_null(theme, "unknown pack degrades to a base theme, no crash")
