extends GutTest
## Accessibility contracts (scaffold §8): the settings must actually reach the
## systems that move the camera and light up the screen. Storing a value the
## juice layer never reads is not accessibility, it is a menu entry.

const CAMERA_SCRIPT := "res://src/juice/camera_director.gd"
const POSTFX_SCRIPT := "res://src/juice/postfx_director.gd"
const SETTINGS_SCRIPT := "res://src/systems/settings.gd"

## Registers a SettingsManager stand-in under the name the juice systems look
## up, so the test needs no autoload wiring.
func _fake_settings(shake: float, flashes: bool) -> Object:
	var script: GDScript = load(SETTINGS_SCRIPT) as GDScript
	var settings: Object = script.new()
	add_child_autofree(settings)
	settings.set_value("shake_intensity", shake)
	settings.set_value("flashes_enabled", flashes)
	var locator: Object = get_tree().root.get_node_or_null("/root/GameServices") as Object
	if locator != null and locator.has_method("register"):
		locator.register(&"settings", settings)
	return settings


func test_shake_respects_the_intensity_setting() -> void:
	_fake_settings(0.25, true)
	var camera: Object = load(CAMERA_SCRIPT).new()
	add_child_autofree(camera)
	camera.shake(1.0)
	var scaled: float = float(camera.get("_trauma"))
	assert_almost_eq(scaled, 0.25, 0.001,
		"trauma is scaled by the accessibility multiplier")


func test_zero_shake_intensity_disables_shake() -> void:
	_fake_settings(0.0, true)
	var camera: Object = load(CAMERA_SCRIPT).new()
	add_child_autofree(camera)
	camera.shake(1.0)
	assert_almost_eq(float(camera.get("_trauma")), 0.0, 0.001,
		"shake_intensity = 0 means no camera movement at all")


func test_flashes_can_be_disabled() -> void:
	_fake_settings(1.0, false)
	var postfx: Object = load(POSTFX_SCRIPT).new()
	add_child_autofree(postfx)
	postfx.flash(Color.WHITE, 0.8, 0.2)
	assert_almost_eq(float(postfx.get("_overlay_flash")), 0.0, 0.001,
		"flashes_enabled = false suppresses the screen flash")


func test_flashes_run_when_enabled() -> void:
	_fake_settings(1.0, true)
	var postfx: Object = load(POSTFX_SCRIPT).new()
	add_child_autofree(postfx)
	postfx.flash(Color.WHITE, 0.8, 0.2)
	assert_almost_eq(float(postfx.get("_overlay_flash")), 0.8, 0.001,
		"flashes_enabled = true keeps the impact flash intact")
