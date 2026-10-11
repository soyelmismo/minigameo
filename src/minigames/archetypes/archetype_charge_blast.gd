class_name ArchetypeChargeBlast
extends MinigameArchetype
## Arquetipo 10 — CHARGE_BLAST (scaffold.md §8.1 fila 10, §8.3 fila 10).
##
## Slots leídos:
##   SpawnRecipe    → 1 proyectil
##   ObjectiveRecipe→ kind CHARGE_RELEASE, target = N soltados, tolerance = ventana
##   HUDRecipe      → PROGRESS
##   InputMode      → BUTTON
##
## Mecánica: mantener pulsado carga un medidor 0..1; soltar dentro de la
## ventana óptima (centro ± `tolerance`) suma acierto. Soltar fuera gasta el
## intento. El medidor sube a velocidad constante mientras se mantiene.

const KIND_CHARGE_RELEASE := &"CHARGE_RELEASE"
## Archetype default for `charge_rate`. Read through _slot_value(), so a
## `.tres` that fills ObjectiveRecipe.charge_rate overrides it (§1.3: tuning is
## data, never magic numbers in gameplay).
const DEFAULT_CHARGE_RATE := 1.0  # unidades/segundo de carga

var _blasts: int = 0
var _charge_rate: float = DEFAULT_CHARGE_RATE
var _release_point: float = 0.75
var _target: int = 3
var _tolerance: float = 0.12
var _time_bonus_per_s: int = 100
var _charging: bool = false
var _charge: float = 0.0


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_charge_rate = _slot_value(&"charge_rate", DEFAULT_CHARGE_RATE)
	# Release window centre (§1.3): the point in the charge bar that counts as
	# a perfect release. Slot-tunable, so a `.tres` can move the window.
	if _meta != null and _meta.objective_recipe != null:
		var window_center: Variant = _meta.objective_recipe.get("tolerance")
		if window_center != null and float(window_center) > 0.0:
			_release_point = clampf(float(window_center), 0.05, 0.95)
	_blasts = 0
	_charging = false
	_charge = 0.0
	if _meta != null and _meta.objective_recipe != null:
		_target = _meta.objective_recipe.target
		_tolerance = _meta.objective_recipe.tolerance
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s


func start() -> void:
	super.start()
	_spawn_projectile()


func _spawn_projectile() -> void:
	if _meta == null or _meta.spawn_recipe == null:
		return
	var ctx := get_context()
	var center: Vector3 = ctx.arena_center if ctx != null else Vector3.ZERO
	var node: Node = spawn_entity(center)
	if node != null:
		node.add_to_group(&"mg_projectile")


func advance(delta: float) -> void:
	if not _charging:
		return
	_charge = clampf(_charge + delta * _charge_rate, 0.0, 1.0)
	set_progress(_charge)
	emit_event(&"charge", {"value": _charge})


func on_input(input_event: InputEvent) -> void:
	if is_finished():
		return
	var just_pressed := false
	var just_released := false
	if input_event is InputEventMouseButton:
		var btn: InputEventMouseButton = input_event as InputEventMouseButton
		just_pressed = btn.pressed
		just_released = not btn.pressed
	elif input_event is InputEventKey:
		var key: InputEventKey = input_event as InputEventKey
		just_pressed = key.pressed
		just_released = not key.pressed
	elif input_event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = input_event as InputEventJoypadButton
		just_pressed = pad.pressed
		just_released = not pad.pressed
	if just_pressed:
		_charging = true
		_charge = 0.0
	elif just_released and _charging:
		_charging = false
		_release()


func _release() -> void:
	var in_window: bool = absf(_charge - _release_point) <= _tolerance
	if in_window:
		_blasts += 1
		var combo: int = bump_combo()
		set_progress(float(_blasts) / float(maxi(1, _target)))
		emit_event(&"blast_ok", {"blasts": _blasts, "value": _charge, "combo": combo})
		if _blasts >= _target:
			finish_success(_time_bonus_per_s)
	else:
		emit_event(&"blast_wasted", {"value": _charge})
	_charge = 0.0


func get_charge() -> float:
	return _charge


func get_blasts() -> int:
	return _blasts


func teardown() -> void:
	super.teardown()
	_charging = false
	_charge = 0.0
	_blasts = 0
