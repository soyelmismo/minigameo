class_name RankThresholds
extends Resource
## Umbrales de rank D < C < B < A < S < S+ (scaffold.md §6.3).
##
## El ScoreDirector mantiene los umbrales autoritarios; esta copia la usa la
## pantalla de resultados cuando solo recibe el score final (modo degradado).

@export var c_min: int = 5000
@export var b_min: int = 15000
@export var a_min: int = 30000
@export var s_min: int = 60000
@export var s_plus_min: int = 100000


func rank_for(score: int) -> StringName:
	if score >= s_plus_min:
		return &"S+"
	if score >= s_min:
		return &"S"
	if score >= a_min:
		return &"A"
	if score >= b_min:
		return &"B"
	if score >= c_min:
		return &"C"
	return &"D"
