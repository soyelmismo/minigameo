extends Node
## SettingsManager — accessibility + gameplay settings (scaffold §13.3).
##
## Single source of truth for shake intensity, flash toggle, colorblind
## indicators, subtitles and text speed. Backed by SaveSystem. All values
## data-driven with sane arcade defaults.

const DEFAULTS := {
	"shake_intensity": 1.0,        # 0..1 multiplier on all camera shake
	"flashes_enabled": true,       # screen flash toggle
	"colorblind_indicators": false,# distinct shapes for objectives
	"subtitles_enabled": true,     # VO callouts as text
	"text_speed": 1.0,             # 0.5..2.0 multiplier
}

var _save: SaveSystem = null
var _values: Dictionary = {}


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"settings") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("SettingsManager", &"settings", self)
	for key: String in DEFAULTS:
		_values[key] = DEFAULTS[key]
	_save = GameServices.lookup(&"save") as SaveSystem
	if _save != null:
		for key: String in DEFAULTS:
			var loaded: Variant = _save.get_setting(StringName(key), DEFAULTS[key])
			_values[key] = loaded


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	if _save != null:
		_save.set_setting(StringName(key), value)


## Shake scale 0..1 (accessibility: reduce or disable).
func shake_scale() -> float:
	return clampf(float(get_value("shake_intensity")), 0.0, 1.0)


func flashes_enabled() -> bool:
	return bool(get_value("flashes_enabled"))


## Subtitles on/off: the callout is the text twin of every VO line (§8).
func subtitles_enabled() -> bool:
	return bool(get_value("subtitles_enabled"))


## Text speed multiplier (0.5..2.0), clamped for safety.
func text_speed() -> float:
	return clampf(float(get_value("text_speed")), 0.5, 2.0)
