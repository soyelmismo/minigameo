class_name MinigameResult
extends RefCounted
## Resultado de un micro-juego (scaffold.md §7.4).

var success: bool = false
var base_score: int = 0
var time_bonus: int = 0        # proporcional al tiempo sobrante
var combo_max: int = 0
var total_score: int = 0
var grade: StringName = &"D"   # D C B A S S+
var fail_reason: StringName = &""  # TIMEOUT | WRONG_INPUT | HIT | ...


## Helper de construcción: calcula el total y rellena el grade.
## `p_` evita ensombrecer las variables de instancia (warning = error aquí).
static func make(
	p_success: bool,
	p_base_score: int,
	p_time_bonus: int,
	p_combo_max: int,
	p_fail_reason: StringName = &""
) -> MinigameResult:
	var res := MinigameResult.new()
	res.success = p_success
	res.base_score = p_base_score
	res.time_bonus = p_time_bonus
	res.combo_max = p_combo_max
	res.total_score = p_base_score + p_time_bonus
	res.fail_reason = p_fail_reason
	res.grade = grade_for(p_combo_max, p_success)
	return res


## Umbrales de rank: D < C < B < A < S < S+ (datos tuneables en §6.3).
## Se mantienen aquí como umbrales por combo máximo del micro-juego.
static func grade_for(combo_peak: int, did_succeed: bool) -> StringName:
	if not did_succeed:
		return &"D"
	if combo_peak >= 20:
		return &"S+"
	if combo_peak >= 15:
		return &"S"
	if combo_peak >= 10:
		return &"A"
	if combo_peak >= 6:
		return &"B"
	if combo_peak >= 3:
		return &"C"
	return &"D"


func _to_string() -> String:
	return "MinigameResult(success=%s, total=%d, combo_max=%d, grade=%s, fail=%s)" % [
		success, total_score, combo_max, String(grade), String(fail_reason)
	]
