extends GutTest
## Accessibility contracts that were stored but never consumed (scaffold §8).
## A setting that changes nothing is not an accessibility feature.

const SETTINGS_SCRIPT := "res://src/systems/settings.gd"
const HUD_SCRIPT := "res://src/ui/hud/hud.tscn"
const COLORS_SCRIPT := "res://src/ui/theme/ui_colors.gd"


func _fake_settings(overrides: Dictionary) -> Object:
	var script: GDScript = load(SETTINGS_SCRIPT) as GDScript
	var settings: Object = script.new()
	add_child_autofree(settings)
	for key: Variant in overrides:
		settings.set_value(String(key), overrides[key])
	var locator: Object = get_tree().root.get_node_or_null("/root/GameServices") as Object
	if locator != null and locator.has_method("register"):
		locator.register(&"settings", settings)
	return settings


func _make_hud() -> Object:
	var hud := (load(HUD_SCRIPT) as PackedScene).instantiate()
	add_child_autofree(hud)
	await get_tree().process_frame
	return hud


func test_subtitles_can_be_switched_off() -> void:
	_fake_settings({"subtitles_enabled": false})
	var hud := await _make_hud()
	hud.show_callout("FLAWLESS. I am telling everyone.")
	assert_false(bool(hud.get("_callout").visible),
		"subtitles off keeps the callout hidden")
	assert_false(bool(hud.is_callout_visible()),
		"the HUD reports the callout as hidden")


func test_subtitles_on_shows_the_line() -> void:
	_fake_settings({"subtitles_enabled": true})
	var hud := await _make_hud()
	hud.show_callout("FIVE MINUTES. NO MERCY. GO!")
	assert_true(bool(hud.is_callout_visible()),
		"subtitles on shows the announcer line as text")
	assert_eq(String(hud.shown_callout()), "FIVE MINUTES. NO MERCY. GO!",
		"the subtitle is the exact line")


func test_colorblind_indicators_have_distinct_shapes() -> void:
	var hints: Array[StringName] = [
		&"GOOD", &"DANGER", &"WARN", &"AI", &"LIFE", &"PRIMARY",
	]
	var seen: Dictionary = {}
	for hint: StringName in hints:
		# Distinct from every other hint's shape: no two dangers share a form.
		var shape: StringName = UIColors.shape(hint)
		assert_false(seen.has(shape),
			"shape of '%s' is unique (%s)" % [String(hint), String(shape)])
		seen[shape] = hint
		# And the shape must not be derived from the hue only.
		assert_gt(String(shape).length(), 0, "shape is defined for '%s'" % String(hint))
