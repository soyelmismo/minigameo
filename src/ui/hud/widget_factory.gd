class_name WidgetFactory
extends RefCounted
## The ONLY factory of objective widgets (scaffold §13.1).
##
## It is the ONLY place that knows the mapping HUDRecipe.primary_widget → scene.
## The HUD asks it "give me the widget for this recipe" and nothing more.

const COUNTER: StringName = &"COUNTER"
const TIMER: StringName = &"TIMER"
const PROGRESS: StringName = &"PROGRESS"
const SEQUENCE: StringName = &"SEQUENCE"
const MULTIPLIER: StringName = &"MULTIPLIER"

## Canonical mapping of the fixed library of 5 widgets (§13.1).
const _SCENES := {
	COUNTER: "res://src/ui/hud/widgets/counter_widget.tscn",
	TIMER: "res://src/ui/hud/widgets/timer_widget.tscn",
	PROGRESS: "res://src/ui/hud/widgets/progress_widget.tscn",
	SEQUENCE: "res://src/ui/hud/widgets/sequence_widget.tscn",
	MULTIPLIER: "res://src/ui/hud/widgets/multiplier_widget.tscn",
}


## Widget scene for a `primary_widget`. Unknown → COUNTER
## (silent degradation: the HUD never crashes on bad data).
static func scene_for(kind: StringName) -> PackedScene:
	var path: String = _SCENES.get(kind, _SCENES[COUNTER]) as String
	return load(path) as PackedScene


## Instances the widget configured for a recipe. It returns null if the
## scene does not exist (silent degradation).
static func create(recipe: HUDRecipe) -> Control:
	var kind: StringName = recipe.primary_widget if recipe != null else COUNTER
	var scene := scene_for(kind)
	if scene == null:
		return null
	var inst := scene.instantiate() as Control
	return inst


## Every supported `primary_widget` (for tests and validation).
static func supported_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for k: StringName in _SCENES:
		kinds.append(k)
	return kinds
