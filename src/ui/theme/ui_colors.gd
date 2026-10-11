class_name UIColors
extends RefCounted
## Paleta semántica compartida por HUD, widgets y screens (scaffold §13.2).
##
## La tematización por style pack se hace por Theme (§13.2); estos colores
## son la base de alta legibilidad y los hints semánticos de HUDRecipe
## (`color_hint`: PRIMARY | GOOD | DANGER | WARN | AI | LIFE | HYBRID).

const OUTLINE: Color = Color(0.04, 0.04, 0.07, 1.0)
const PANEL: Color = Color(0.07, 0.08, 0.13, 0.88)
const TEXT: Color = Color(0.96, 0.97, 1.0, 1.0)
const TEXT_DIM: Color = Color(0.72, 0.75, 0.85, 1.0)
const PRIMARY: Color = Color(1.0, 0.83, 0.25, 1.0)
const GOOD: Color = Color(0.35, 0.92, 0.45, 1.0)
const DANGER: Color = Color(1.0, 0.28, 0.30, 1.0)
const WARN: Color = Color(1.0, 0.58, 0.15, 1.0)
const AI: Color = Color(0.30, 0.90, 0.98, 1.0)
const LIFE: Color = Color(1.0, 0.45, 0.80, 1.0)
const HYBRID: Color = Color(0.65, 0.55, 1.0, 1.0)

const _SEMANTIC := {
	&"PRIMARY": PRIMARY,
	&"GOOD": GOOD,
	&"DANGER": DANGER,
	&"WARN": WARN,
	&"AI": AI,
	&"LIFE": LIFE,
	&"HYBRID": HYBRID,
}


## Color semántico de un `HUDRecipe.color_hint` (scaffold §7.3.1).
## Hint desconocido → PRIMARY (degradación silenciosa, nunca crash).
static func semantic(hint: StringName) -> Color:
	return _SEMANTIC.get(hint, PRIMARY) as Color


## Distinct SHAPE per semantic hint, for colourblind players (§8): objectives
## and dangers read by form, not only by hue. Empty when the player leaves
## indicators off, so nothing changes by default.
static func shape(hint: StringName) -> StringName:
	return _SHAPES.get(hint, &"DIAMOND")


## The accessibility flag decides whether shapes are shown at all.
const _SHAPES := {
	&"PRIMARY": &"DIAMOND",
	&"GOOD": &"CIRCLE",
	&"DANGER": &"TRIANGLE",
	&"WARN": &"SQUARE",
	&"AI": &"HEXAGON",
	&"LIFE": &"STAR",
	&"HYBRID": &"DIAMOND",
}
