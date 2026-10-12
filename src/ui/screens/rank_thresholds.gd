class_name RankThresholds
extends Resource
## View of the rank thresholds (scaffold.md §6.3).
##
## SINGLE SOURCE OF TRUTH: `GameConfig.tres` (§1.3, zero hardcoded
## numbers). This resource exists only so the UI can show the
## thresholds without coupling to ScoreDirector; its values are read from
## GameConfig in `sync_from_config()`. DO NOT introduce numbers here:
## changing the balance means editing `GameConfig.tres`.

var c_min: int = 5000
var b_min: int = 12000
var a_min: int = 25000
var s_min: int = 45000
var s_plus_min: int = 70000


## Refreshes the thresholds from GameConfig (call when loading the UI).
func sync_from_config() -> void:
	var cfg: Resource = load("res://src/core/config/game_config.tres") as Resource
	if cfg == null:
		return
	c_min = int(cfg.get("rank_c"))
	b_min = int(cfg.get("rank_b"))
	a_min = int(cfg.get("rank_a"))
	s_min = int(cfg.get("rank_s"))
	s_plus_min = int(cfg.get("rank_s_plus"))


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
