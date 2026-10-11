class_name BusLayout
extends RefCounted
## Audio bus layout contract (scaffold.md §10.2).
## Registered in code by AudioDirector.setup_buses() — idempotent.
##
## Canonical tree:
##   Master (Limiter)
##   ├── Music      (Compressor, EQ, duck)
##   ├── SFX        (Limiter)
##   │   ├── Player | World | UI | Impact   (SFX sub-buses, group-routed)
##   ├── Ambience   (Reverb send)
##   ├── VO         (Compressor, duck alto)
##   └── UI         (limpio, sin reverb)
##
## NOTE: the scaffold ASCII tree draws "UI" twice (under SFX and top-level).
## Godot bus names are globally unique, so the layout registers ONE "UI" bus
## as an SFX sub-bus (UI sounds: clean, no reverb). Documented deviation.
##
## LAYOUT order below IS the registration order (parents before children).

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_PLAYER: StringName = &"Player"
const BUS_WORLD: StringName = &"World"
const BUS_UI: StringName = &"UI"
const BUS_IMPACT: StringName = &"Impact"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_VO: StringName = &"VO"

## Buses created by the layout, with their parent bus.
const LAYOUT: Array[Dictionary] = [
	{"name": BUS_MUSIC, "parent": BUS_MASTER},
	{"name": BUS_SFX, "parent": BUS_MASTER},
	{"name": BUS_PLAYER, "parent": BUS_SFX},
	{"name": BUS_WORLD, "parent": BUS_SFX},
	{"name": BUS_UI, "parent": BUS_SFX},
	{"name": BUS_IMPACT, "parent": BUS_SFX},
	{"name": BUS_AMBIENCE, "parent": BUS_MASTER},
	{"name": BUS_VO, "parent": BUS_MASTER},
]

## SFX group -> bus name (default routing; the catalog can override per id).
const GROUP_TO_BUS: Dictionary = {
	&"player": BUS_PLAYER,
	&"world": BUS_WORLD,
	&"ui": BUS_UI,
	&"impact": BUS_IMPACT,
	&"voice": BUS_VO,
}

## Returns the bus a group routes to (unknown groups fall back to SFX).
static func bus_for_group(group: StringName) -> StringName:
	var bus: Variant = GROUP_TO_BUS.get(group, BUS_SFX)
	return bus as StringName

## True when `name` belongs to this layout (Master included).
static func is_layout_bus(name: StringName) -> bool:
	if name == BUS_MASTER:
		return true
	for entry: Dictionary in LAYOUT:
		if (entry["name"] as StringName) == name:
			return true
	return false
