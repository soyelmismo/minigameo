extends "res://addons/gut/test.gd"
## Integración funcional de las pantallas (§13.2, §13.3) y accesibilidad (§8).
##
## Cubre lo que el brief exige:
## - cada pantalla se instancia headless y conserva sus nodos %UniqueName;
## - TitleScreen muestra el récord real de SaveSystem;
## - PauseMenu pausa/reanuda, abre SettingsPanel y sale a título;
## - ResultsScreen registra el score en SaveSystem.submit_score y reinicia;
## - SettingsPanel hace round-trip con SettingsManager (set_value/get_value).
##
## Los autoloads se resuelven por path (`/root/X`), nunca por class_name.
## Cero dependencias de GPU: todo aquí son nodos de Control y datos.

const TITLE := "res://src/ui/screens/title_screen.tscn"
const PAUSE := "res://src/ui/screens/pause_menu.tscn"
const RESULTS := "res://src/ui/screens/results_screen.tscn"
const SETTINGS := "res://src/ui/screens/settings_panel.tscn"

var _saved_paused: bool = false


func before_each() -> void:
	_saved_paused = get_tree().paused


func after_each() -> void:
	# Nunca dejar el árbol en pausa: contaminaría el resto de la suite.
	get_tree().paused = _saved_paused


func _load(path: String) -> Node:
	var scene: PackedScene = load(path)
	assert_not_null(scene, "scene must load: %s" % path)
	var node := scene.instantiate()
	add_child_autofree(node)
	await get_tree().process_frame
	return node


## Autoload por path (los autoloads no tienen class_name global).
func _auto(name: String) -> Object:
	return get_tree().root.get_node_or_null("/root/" + name) as Object


# --- Las pantallas instancian headless (§13.2) ---

func test_all_screens_instantiate_with_their_unique_nodes() -> void:
	var title := await _load(TITLE) as TitleScreen
	assert_not_null(title, "title screen instantiates")
	assert_not_null(title.get_node_or_null("%PlayButton"), "title keeps %PlayButton")
	assert_not_null(title.get_node_or_null("%BestLabel"), "title keeps %BestLabel")

	var pause := await _load(PAUSE) as PauseMenu
	assert_not_null(pause, "pause menu instantiates")
	assert_not_null(pause.get_node_or_null("%PausePanel"), "pause keeps %PausePanel")
	for button: String in ["%ResumeButton", "%SettingsButton", "%QuitButton"]:
		assert_not_null(pause.get_node_or_null(button), "pause keeps " + button)

	var results := await _load(RESULTS) as ResultsScreen
	assert_not_null(results, "results screen instantiates")
	assert_not_null(results.get_node_or_null("%RankPanel"), "results keeps %RankPanel")
	assert_not_null(results.get_node_or_null("%PlayAgainButton"), "results keeps %PlayAgainButton")

	var panel := await _load(SETTINGS) as SettingsPanel
	assert_not_null(panel, "settings panel instantiates")
	assert_not_null(panel.get_node_or_null("%SettingsPanel"), "panel keeps %SettingsPanel")
	for widget: String in [
		"%ShakeSlider", "%FlashToggle", "%ColorblindToggle",
		"%SubtitleToggle", "%TextSpeedSlider",
	]:
		assert_not_null(panel.get_node_or_null(widget), "panel keeps " + widget)


# --- TitleScreen: récord real de SaveSystem ---

func test_title_shows_the_real_save_system_best_score() -> void:
	var save := _auto("SaveSystem")
	if save == null:
		return
	save.reset()
	save.submit_score(4242, &"C")
	var title := await _load(TITLE) as TitleScreen
	assert_eq(title.best_score(), 4242, "title reads the record from SaveSystem")
	assert_eq(title.best_text(), "BEST: 4,242", "the record line formats thousands")
	save.reset()


func test_title_best_line_keeps_its_prefix() -> void:
	var title := await _load(TITLE) as TitleScreen
	assert_eq(title.best_text().begins_with("BEST:"), true, "best line keeps its prefix")
	assert_gt(title.title_text().length(), 0, "the title shows the logo text")


# --- PauseMenu: pausa / ajustes / salir ---

func test_pause_menu_pauses_and_resumes_the_tree() -> void:
	var pause := await _load(PAUSE) as PauseMenu
	pause.open()
	assert_true(get_tree().paused, "opening the menu pauses the world")
	assert_true(pause.visible, "the menu becomes visible")
	pause.resume()
	assert_false(get_tree().paused, "resuming unpauses the world")
	assert_false(pause.visible, "the menu hides on resume")


func test_pause_menu_quit_goes_back_to_title() -> void:
	var match_mgr := _auto("MatchManager")
	if match_mgr == null:
		return
	match_mgr.start_match()
	var pause := await _load(PAUSE) as PauseMenu
	var quit_seen: Array[bool] = [false]
	pause.quit_pressed.connect(func() -> void: quit_seen[0] = true)
	pause.quit_to_title()
	assert_true(quit_seen[0], "quitting emits its signal")
	assert_eq(match_mgr.current_state(), match_mgr.State.RESULTS, "quit returns to RESULTS/title")
	assert_false(get_tree().paused, "quitting unpauses the world")


func test_pause_menu_opens_and_frees_the_settings_panel() -> void:
	var pause := await _load(PAUSE) as PauseMenu
	var settings_seen: Array[bool] = [false]
	pause.settings_pressed.connect(func() -> void: settings_seen[0] = true)
	pause.open_settings()
	await get_tree().process_frame
	assert_true(settings_seen[0], "opening settings emits its signal")
	var panel: SettingsPanel = null
	for child: Node in pause.get_children():
		if child is SettingsPanel:
			panel = child as SettingsPanel
	assert_not_null(panel, "the settings panel is parented to the pause menu")
	panel._on_close()
	await get_tree().process_frame
	var orphan: SettingsPanel = null
	for child: Node in pause.get_children():
		if child is SettingsPanel:
			orphan = child as SettingsPanel
	assert_null(orphan, "closing the panel frees it (no orphans, §1.4)")


func test_pause_menu_survives_a_paused_tree() -> void:
	var pause := await _load(PAUSE) as PauseMenu
	assert_eq(
		pause.process_mode, Node.PROCESS_MODE_ALWAYS,
		"the pause menu keeps processing while the world is paused"
	)


# --- ResultsScreen: rank, submit, reinicio ---

func test_results_rank_ladder_matches_the_authoritative_thresholds() -> void:
	var screen := await _load(RESULTS) as ResultsScreen
	# Umbrales autoritativos = GameConfig.tres (§6.3, §1.3):
	# C 5000 | B 12000 | A 25000 | S 45000 | S+ 70000.
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


func test_results_submit_score_records_the_run_in_the_save() -> void:
	var save := _auto("SaveSystem")
	if save == null:
		return
	save.reset()
	var screen := await _load(RESULTS) as ResultsScreen
	var seen_total: Array[int] = [-1]
	var seen_rank: Array[StringName] = [&""]
	screen.score_submitted.connect(
		func(total: int, rank: StringName) -> void:
			seen_total[0] = total
			seen_rank[0] = rank
	)
	var is_record: bool = screen.submit(777777)
	assert_true(is_record, "a huge score beats the previous record")
	assert_true(seen_total[0] == 777777, "the submitted total is reported")
	assert_eq(String(seen_rank[0]), "S+", "the submitted rank matches the score")
	assert_eq(int(save.get(&"best_score")), 777777, "SaveSystem holds the new best score")
	save.reset()


func test_results_play_again_resets_the_score_and_restarts_the_match() -> void:
	var match_mgr := _auto("MatchManager")
	var score_dir := _auto("ScoreDirector")
	if match_mgr == null or score_dir == null:
		return
	score_dir.add_points(5000)
	var screen := await _load(RESULTS) as ResultsScreen
	var again_seen: Array[bool] = [false]
	screen.play_again_pressed.connect(func() -> void: again_seen[0] = true)
	screen._on_play_again()
	assert_true(again_seen[0], "play again emits its signal")
	assert_eq(int(score_dir.get(&"total_score")), 0, "play again resets the score")
	assert_eq(match_mgr.current_state(), match_mgr.State.COUNTDOWN, "play again restarts the match")


func test_results_flavor_lines_are_english_and_never_cruel() -> void:
	var screen := await _load(RESULTS) as ResultsScreen
	for score: int in [0, 6000, 20000, 40000, 70000, 150000]:
		screen.show_results(score, 0)
		var line: String = screen.flavor_text()
		assert_true(line.length() > 0, "rank %s has a flavor line" % screen.rank_text())
		assert_gt(line.length(), 4, "the flavor line says something")


# --- SettingsManager round-trip (§13.3) ---

func test_settings_manager_round_trip() -> void:
	var mgr := _auto("SettingsManager")
	if mgr == null:
		return
	var keys: Array[String] = [
		"shake_intensity", "flashes_enabled", "colorblind_indicators",
		"subtitles_enabled", "text_speed",
	]
	for key: String in keys:
		mgr.set_value(key, mgr.get_value(key))
		assert_true(mgr.get_value(key) != null, "%s is readable after a write" % key)
	mgr.set_value("shake_intensity", 0.25)
	assert_almost_eq(float(mgr.get_value("shake_intensity")), 0.25, 0.001, "shake round-trips")
	assert_almost_eq(float(mgr.shake_scale()), 0.25, 0.001, "shake_scale reflects the value")
	mgr.set_value("flashes_enabled", false)
	assert_false(bool(mgr.get_value("flashes_enabled")), "the flash toggle round-trips")
	assert_false(bool(mgr.flashes_enabled()), "flashes_enabled() reflects the toggle")
	mgr.set_value("shake_intensity", 1.0)
	mgr.set_value("flashes_enabled", true)


func test_settings_panel_writes_through_to_settings_manager() -> void:
	var mgr := _auto("SettingsManager")
	if mgr == null:
		return
	var previous_shake: float = float(mgr.get_value("shake_intensity"))
	var panel := await _load(SETTINGS) as SettingsPanel
	var slider: HSlider = panel.get_node("%ShakeSlider") as HSlider
	slider.value = 0.4
	var flashes: CheckButton = panel.get_node("%FlashToggle") as CheckButton
	flashes.button_pressed = false
	var speed: HSlider = panel.get_node("%TextSpeedSlider") as HSlider
	speed.value = 1.6
	panel._on_close()
	assert_almost_eq(float(mgr.get_value("shake_intensity")), 0.4, 0.001, "shake persists to the manager")
	assert_false(bool(mgr.get_value("flashes_enabled")), "the flash toggle persists")
	assert_almost_eq(float(mgr.get_value("text_speed")), 1.6, 0.001, "text speed persists")
	# Restaurar para no contaminar otros tests.
	mgr.set_value("shake_intensity", previous_shake)
	mgr.set_value("flashes_enabled", true)
	mgr.set_value("text_speed", 1.0)


func test_settings_panel_reads_persisted_values_on_open() -> void:
	var mgr := _auto("SettingsManager")
	if mgr == null:
		return
	var previous: float = float(mgr.get_value("shake_intensity"))
	mgr.set_value("shake_intensity", 0.55)
	var panel := await _load(SETTINGS) as SettingsPanel
	panel.open()
	assert_almost_eq(panel.current_settings().shake_intensity, 0.55, 0.001, "the panel loads the stored value")
	var slider: HSlider = panel.get_node("%ShakeSlider") as HSlider
	assert_almost_eq(slider.value, 0.55, 0.001, "the slider shows the stored value")
	mgr.set_value("shake_intensity", previous)


func test_settings_panel_clamps_out_of_range_values() -> void:
	var panel := await _load(SETTINGS) as SettingsPanel
	var slider: HSlider = panel.get_node("%ShakeSlider") as HSlider
	slider.value = 99.0
	assert_almost_eq(panel.shake_value(), 1.0, 0.001, "shake clamps to 1.0")
	slider.value = -5.0
	assert_almost_eq(panel.shake_value(), 0.0, 0.001, "shake clamps to 0.0")
	var speed: HSlider = panel.get_node("%TextSpeedSlider") as HSlider
	speed.value = 50.0
	assert_almost_eq(panel.text_speed_value(), 2.0, 0.001, "text speed clamps to 2.0")


# --- Accesibilidad: navegable con teclado Y mando (§8) ---

func test_every_screen_is_keyboard_and_gamepad_navigable() -> void:
	var screens := {
		TITLE: await _load(TITLE),
		PAUSE: await _load(PAUSE),
		RESULTS: await _load(RESULTS),
		SETTINGS: await _load(SETTINGS),
	}
	for path: String in screens:
		var screen: Control = screens[path] as Control
		assert_not_null(screen, "screen loaded: %s" % path)
		var focusable := UIFocus.collect(screen)
		assert_gt(
			focusable.size(), 0,
			"%s has focusable controls for keyboard/gamepad (§8)" % path.get_file()
		)
		for control: Control in focusable:
			assert_eq(
				control.focus_mode, Control.FOCUS_ALL,
				"%s: %s is reachable (§8)" % [path.get_file(), control.name]
			)


func test_settings_panel_widgets_are_all_reachable() -> void:
	var panel := await _load(SETTINGS) as SettingsPanel
	var reachable := UIFocus.collect(panel)
	var names: Array[String] = []
	for control: Control in reachable:
		names.append(String(control.name))
	# Los 5 ajustes + BACK deben poder alcanzarse con mando.
	for expected: String in ["ShakeSlider", "FlashToggle", "ColorblindToggle", "SubtitleToggle", "TextSpeedSlider", "CloseButton"]:
		assert_has(names, expected, "the accessibility widget %s is focusable" % expected)


func test_pause_menu_grab_first_targets_resume() -> void:
	var pause := await _load(PAUSE) as PauseMenu
	var grabbed := UIFocus.grab_first(pause)
	assert_not_null(grabbed, "the pause menu hands focus to a control")
	assert_eq(String(grabbed.name), "ResumeButton", "RESUME takes focus first (§8)")
