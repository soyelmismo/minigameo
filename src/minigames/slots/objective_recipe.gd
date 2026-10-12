class_name ObjectiveRecipe
extends Resource
## WHAT has to be done. The archetype evaluates this condition every frame (§7.3.1).

@export var kind: StringName = &"COLLECT_N"    # COLLECT_N | SURVIVE_T | TAP_N
                                                # HOLD_ZONE_T | GATES_IN_ORDER
                                                # CHAIN_N | STOP_IN_ZONE | ...
@export var target: int = 12                   # N objects / N seconds / N gates
@export var tolerance: float = 0.0             # hit window (seg/beat/units)
@export var fail_on: StringName = &"TIMEOUT"   # TIMEOUT | TOUCH_HAZARD | WRONG_INPUT | NONE
@export var time_bonus_per_s: int = 100        # points per leftover second when winning
@export var combo_step: float = 0.25           # multiplier increment per hit
## Radii and rates of the archetype that previously lived as magic constants in
## each script (§1.3 forbids them). -1 means "use the archetype's default",
## so a `.tres` that does not fill it in behaves exactly as it did
## before, and one that does retunes the micro-game without touching code.
@export var reach_m: float = -1.0              # pickup/hazard/gate/zone (m)
@export var charge_rate: float = -1.0          # charge units per second
@export var sweep_speed: float = -1.0          # sweep cycles per second
@export var path_width: float = -1.0           # path width (BALANCE_T)


## Leftover time bonus (whole points, never negative).
