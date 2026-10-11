class_name HUDRecipe
extends Resource
## CÓMO se comunica el objetivo (scaffold.md §7.3.1).
##
## La UI se auto-construye desde aquí (§13.1): cero widgets ad-hoc por
## micro-juego. Biblioteca fija de 5 widgets.

@export var primary_widget: StringName = &"COUNTER"  # COUNTER | TIMER | PROGRESS | SEQUENCE | METER
@export var icon: Texture2D = null              # icono del objetivo
@export var color_hint: StringName = &""        # color semántico del objetivo
@export var show_flavor: bool = true            # mostrar el chiste en el arranque
@export var callout_on_start: StringName = &"GO GO GO!"  # callout subtitulado (§8)
