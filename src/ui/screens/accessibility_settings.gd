extends Resource
class_name AccessibilitySettings
## Accessibility settings (scaffold §13.3, AGENTS.md §8).
##
## SettingsManager (autoload) is the authoritative source and persists via
## SaveSystem to `user://`. This Resource is the model the panel edits:
## it reads from the manager on open and writes on close.
##
## Key mapping (the name of the Resource field does not always match the
## la key del manager; `subtitles_always_visible` vive como
## "subtitles_enabled"). The map is data, not magic.

## Shake intensity 0..1 (0 = disabled, §13.3).
@export var shake_intensity: float = 1.0
## Disable fullscreen flashes (§13.3).
@export var flashes_enabled: bool = true
## Colorblind indicator mode: objectives/hazards get SHAPE
## distintiva, no solo color (§13.3).
@export var colorblind_indicators: bool = false
## VO callouts always visible (subtitles, §13.3).
@export var subtitles_always_visible: bool = true
## Text speed 0.5..2.0 (§13.3).
@export var text_speed: float = 1.0

## Resource field -> SettingsManager key. Single source of the mapping.
const KEY_MAP := {
	"shake_intensity": "shake_intensity",
	"flashes_enabled": "flashes_enabled",
	"colorblind_indicators": "colorblind_indicators",
	"subtitles_always_visible": "subtitles_enabled",
	"text_speed": "text_speed",
}


## Writes the current values to SettingsManager (which persists to disk).
## It degrades silently if the manager is not present.
func apply_to_settings_manager() -> void:
	var mgr: Object = find_manager()
	if mgr == null or not mgr.has_method("set_value"):
		return
	for field: String in KEY_MAP:
		mgr.set_value(KEY_MAP[field], get(field))


## Reads the current values from SettingsManager.
## It degrades silently if the manager is not present.
func load_from_settings_manager() -> void:
	var mgr: Object = find_manager()
	if mgr == null or not mgr.has_method("get_value"):
		return
	for field: String in KEY_MAP:
		var loaded: Variant = mgr.get_value(KEY_MAP[field])
		if loaded != null:
			set(field, loaded)


## SettingsManager resuelto por GameServices o, en defecto, por path.
func find_manager() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.root
	var services: Object = root.get_node_or_null(NodePath("/root/GameServices")) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(&"SettingsManager")
		if via_services != null:
			return via_services
	return root.get_node_or_null(NodePath("/root/SettingsManager")) as Object
