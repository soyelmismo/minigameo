class_name HUDRecipe
extends Resource
## HOW the objective is communicated (scaffold.md §7.3.1).
##
## The UI is auto-built from here (§13.1): zero ad-hoc widgets per
## micro-game. Fixed library of 5 widgets.

@export var primary_widget: StringName = &"COUNTER"  # COUNTER | TIMER | PROGRESS | SEQUENCE | MULTIPLIER
@export var icon: Texture2D = null              # icon of the objective
@export var color_hint: StringName = &""        # semantic color of the objective
@export var show_flavor: bool = true            # show the joke at startup
@export var callout_on_start: StringName = &"GO GO GO!"  # subtitled callout (§8)
