class_name WidgetFactory
extends RefCounted
## ÚNICA fábrica de widgets de objetivo (scaffold §13.1).
##
## Es el ÚNICO sitio que conoce el mapeo HUDRecipe.primary_widget → escena.
## El HUD le pide "dame el widget para esta receta" y nunca más.

const COUNTER: StringName = &"COUNTER"
const TIMER: StringName = &"TIMER"
const PROGRESS: StringName = &"PROGRESS"
const SEQUENCE: StringName = &"SEQUENCE"
const MULTIPLIER: StringName = &"MULTIPLIER"

## Mapeo canónico de la biblioteca fija de 5 widgets (§13.1).
const _SCENES := {
	COUNTER: "res://src/ui/hud/widgets/counter_widget.tscn",
	TIMER: "res://src/ui/hud/widgets/timer_widget.tscn",
	PROGRESS: "res://src/ui/hud/widgets/progress_widget.tscn",
	SEQUENCE: "res://src/ui/hud/widgets/sequence_widget.tscn",
	MULTIPLIER: "res://src/ui/hud/widgets/multiplier_widget.tscn",
}


## Escena del widget para un `primary_widget`. Desconocido → COUNTER
## (degradación silenciosa: el HUD nunca crashea por datos malos).
static func scene_for(kind: StringName) -> PackedScene:
	var path: String = _SCENES.get(kind, _SCENES[COUNTER]) as String
	return load(path) as PackedScene


## Instancia el widget configurado para una receta. Devuelve null si la
## escena no existe (degradación silenciosa).
static func create(recipe: HUDRecipe) -> Control:
	var kind: StringName = recipe.primary_widget if recipe != null else COUNTER
	var scene := scene_for(kind)
	if scene == null:
		return null
	var inst := scene.instantiate() as Control
	return inst


## Todos los `primary_widget` soportados (para tests y validación).
static func supported_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for k: StringName in _SCENES:
		kinds.append(k)
	return kinds
