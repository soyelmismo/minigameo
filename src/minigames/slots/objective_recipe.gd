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
## Radios y tasas del arquetipo que antes vivían como constantes mágicas en
## cada script (§1.3 las prohibe). -1 significa "usa el default del arquetipo",
## de modo que un `.tres` que no lo rellena se comporta exactamente igual que
## antes, y uno que sí lo haga retune el micro-juego sin tocar código.
@export var reach_m: float = -1.0              # recogida/peligro/gate/zona (m)
@export var charge_rate: float = -1.0          # unidades/segundo de carga
@export var sweep_speed: float = -1.0          # ciclos/segundo del barrido
@export var path_width: float = -1.0           # ancho del camino (BALANCE_T)


## Bonus de tiempo sobrante (puntos enteros, nunca negativo).
