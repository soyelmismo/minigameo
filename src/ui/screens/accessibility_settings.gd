extends Resource
class_name AccessibilitySettings
## Ajustes de accesibilidad (scaffold §13.3, AGENTS.md §8).
##
## SettingsManager (autoload) es la fuente autoritativa y persiste vía
## SaveSystem a `user://`. Este Resource es el modelo que edita el panel:
## lee del manager al abrir y escribe al cerrar.
##
## Mapeo de claves (el nombre del campo del Resource NO coincide siempre con
## la key del manager; `subtitles_always_visible` vive como
## "subtitles_enabled"). El mapa es datos, no magia.

## Intensidad de shake 0..1 (0 = desactivado, §13.3).
@export var shake_intensity: float = 1.0
## Desactivar flashes de pantalla (§13.3).
@export var flashes_enabled: bool = true
## Modo indicadores de daltonismo: los objetivos/peligros reciben FORMA
## distintiva, no solo color (§13.3).
@export var colorblind_indicators: bool = false
## Callouts de VO siempre visibles (subtítulos, §13.3).
@export var subtitles_always_visible: bool = true
## Velocidad de texto 0.5..2.0 (§13.3).
@export var text_speed: float = 1.0

## Campo del Resource -> key de SettingsManager. Fuente única del mapeo.
const KEY_MAP := {
	"shake_intensity": "shake_intensity",
	"flashes_enabled": "flashes_enabled",
	"colorblind_indicators": "colorblind_indicators",
	"subtitles_always_visible": "subtitles_enabled",
	"text_speed": "text_speed",
}


## Escribe los valores actuales en SettingsManager (que persiste a disco).
## Degrada en silencio si el manager no está presente.
func apply_to_settings_manager() -> void:
	var mgr: Object = find_manager()
	if mgr == null or not mgr.has_method("set_value"):
		return
	for field: String in KEY_MAP:
		mgr.set_value(KEY_MAP[field], get(field))


## Lee los valores actuales desde SettingsManager.
## Degrada en silencio si el manager no está presente.
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
