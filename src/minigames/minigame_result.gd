class_name MinigameResult
extends RefCounted
## Result of a micro-game (scaffold.md §7.4).

var success: bool = false
var base_score: int = 0
var time_bonus: int = 0        # proportional to the leftover time
var combo_max: int = 0
var total_score: int = 0
var grade: StringName = &"D"   # D C B A S S+
var fail_reason: StringName = &""  # TIMEOUT | WRONG_INPUT | HIT | ...


## Construction helper: it computes the total and fills in the grade.
## `p_` avoids shadowing the instance variables (warning = error here).
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


## Rank thresholds: D < C < B < A < S < S+ (tunable data in §6.3).
## They are kept here as thresholds per maximum combo of the micro-game.
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
