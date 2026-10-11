class_name ObjectiveRecipe
extends Resource
## QUÉ hay que hacer. El arquetipo evalúa esta condición cada frame (§7.3.1).

@export var kind: StringName = &"COLLECT_N"    # COLLECT_N | SURVIVE_T | TAP_N
                                                # HOLD_ZONE_T | GATES_IN_ORDER
                                                # CHAIN_N | STOP_IN_ZONE | ...
@export var target: int = 12                   # N objetos / N segundos / N gates
@export var tolerance: float = 0.0             # ventana de acierto (seg/beat/unidades)
@export var fail_on: StringName = &"TIMEOUT"   # TIMEOUT | TOUCH_HAZARD | WRONG_INPUT | NONE
@export var time_bonus_per_s: int = 100        # puntos por segundo sobrante al ganar
@export var combo_step: float = 0.25           # incremento de multiplicador por acierto


## Bonus de tiempo sobrante (puntos enteros, nunca negativo).
func time_bonus_for(time_left: float) -> int:
	return maxi(0, int(round(time_left * float(time_bonus_per_s))))
