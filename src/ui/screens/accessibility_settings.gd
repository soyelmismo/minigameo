class_name AccessibilitySettings
extends Resource
## Ajustes de accesibilidad (scaffold §13.3, AGENTS.md §8).
##
## SettingsManager (autoload, otro agente) es la fuente autoritativa;
## esta copia la usa el panel de ajustes cuando aquel no existe y para
## tests. Cero hardcodeo: los valores viven del .tres de settings.

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


func apply_to_settings_manager() -> void:
	var mgr := _find()
	if mgr == null:
		return
	for prop: String in ["shake_intensity", "flashes_enabled", "colorblind_indicators", "subtitles_always_visible", "text_speed"]:
		if prop in mgr:
			mgr.set(prop, get(prop))


func load_from_settings_manager() -> void:
	var mgr := _find()
	if mgr == null:
		return
	for prop: String in ["shake_intensity", "flashes_enabled", "colorblind_indicators", "subtitles_always_visible", "text_speed"]:
		if prop in mgr:
			set(prop, mgr.get(prop))


func _find() -> Object:
	var services: Object = Engine.get_main_loop().root.get_node_or_null("/root/GameServices")
	if services != null and services.has_method("get"):
		var svc: Object = services.get(&"SettingsManager")
		if svc != null:
			return svc
	return Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager")
