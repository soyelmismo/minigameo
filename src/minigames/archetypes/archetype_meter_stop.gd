class_name ArchetypeMeterStop
extends MinigameArchetype
## Arquetipo 9 — METER_STOP (scaffold.md §8.1 fila 9, §8.3 fila 9).
##
## Slots leídos:
##   SpawnRecipe    → medidor animado (speed = barrido del marcador)
##   ObjectiveRecipe→ kind STOP_IN_ZONE, target = N paradas válidas, tolerance = semiancho
##   HUDRecipe      → PROGRESS
##   InputMode      → BUTTON
##
## Mecánica: un marcador barre el medidor de forma continua; pulsar BUTTON
## dentro de la zona válida (centro ± `tolerance`) suma parada. Fallar no rompe
## el micro-juego salvo que `fail_on` lo declare.

const KIND_STOP_IN_ZONE := &"STOP_IN_ZONE"
## Archetype default for `sweep_speed`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.sweep_speed overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_SWEEP_SPEED := 1.0  # ciclos/segundo del barrido cuando no hay speed

var _stops: int = 0
var _target: int = 3
var _tolerance: float = 0.1
var _time_bonus_per_s: int = 100
var _marker: float = 0.0
var _sweep_speed: float = DEFAULT_SWEEP_SPEED


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_sweep_speed = _slot_value(&"sweep_speed", DEFAULT_SWEEP_SPEED)
	_stops = 0
	_marker = 0.0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_tolerance = _meta.objective_recipe.tolerance
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	# Convención de slots: `speed` del SpawnRecipe = velocidad de barrido.
	if _meta != null and _meta.spawn_recipe != null and _meta.spawn_recipe.speed > 0.0:
		_sweep_speed = _meta.spawn_recipe.speed / 10.0


func start() -> void:
	super.start()
	emit_event(&"meter_ready", {"tolerance": _tolerance, "target": _target})


## Barre el marcador 0..1..0 (ping-pong) usando el reloj base del arquetipo.
func advance(_delta: float) -> void:
	_marker = 0.5 + 0.5 * sin(get_elapsed() * TAU * _sweep_speed)
	emit_event(&"meter_sweep", {"value": _marker})
	set_progress(float(_stops) / float(maxi(1, _target)))


func on_input(input_event: InputEvent) -> void:
	if is_finished():
		return
	var pressed := false
	if input_event is InputEventMouseButton:
		pressed = (input_event as InputEventMouseButton).pressed
	elif input_event is InputEventKey:
		pressed = (input_event as InputEventKey).pressed
	elif input_event is InputEventJoypadButton:
		pressed = (input_event as InputEventJoypadButton).pressed
	if not pressed:
		return
	# La zona válida es el centro del medidor ± tolerancia.
	var in_zone: bool = absf(_marker - 0.5) <= _tolerance
	if in_zone:
		_stops += 1
		var combo: int = bump_combo()
		set_progress(float(_stops) / float(maxi(1, _target)))
		emit_event(&"meter_stop", {"stops": _stops, "value": _marker, "combo": combo})
		if _stops >= _target:
			finish_success(_time_bonus_per_s)
	else:
		emit_event(&"meter_miss", {"value": _marker})
		if _meta != null and _meta.objective_recipe != null:
			if _meta.objective_recipe.fail_on == &"WRONG_INPUT":
				finish_fail(&"WRONG_INPUT")


func get_marker() -> float:
	return _marker


func get_stops() -> int:
	return _stops


func teardown() -> void:
	super.teardown()
	_stops = 0
	_marker = 0.0
