extends Control
class_name ResultsScreen
## Results screen (scaffold §13.2): huge rank D..S+, breakdown of
## score, record, PLAY AGAIN. Humor according to rank (§2): celebration on S+,
## awkward silence on D.
##
## Integration:
## - `submit(total)` records the score in `SaveSystem.submit_score(score, rank)`
##   (the only door to record persistence).
## - PLAY AGAIN restarts via `MatchManager.start_match()` and resets ScoreDirector.
## - The rank comes from `ScoreDirector.rank_for_score()` when it exists (the
##   authoritative source, scaffold §6.3); otherwise from the thresholds of
##   `rank_thresholds.tres` (data, never hardcoded).
##
## The announcer is sarcastic but NEVER cruel (§1.9, §2).

const SERVICES_PATH := &"/root/GameServices"
const MATCH_PATH := &"/root/MatchManager"
const SCORE_PATH := &"/root/ScoreDirector"
const SAVE_PATH := &"/root/SaveSystem"
const THRESHOLDS_PATH := "res://src/ui/screens/rank_thresholds.tres"

signal play_again_pressed()
signal score_submitted(total: int, rank: StringName)

@export var thresholds: RankThresholds = null

@onready var _rank_label: Label = %RankLabel
@onready var _flavor_label: Label = %ResultsFlavor
@onready var _total_label: Label = %TotalLabel
@onready var _best_label: Label = %RecordLabel
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _confetti: CPUParticles2D = %Confetti
@onready var _new_record: Label = %NewRecordLabel
@onready var _play_again: Button = %PlayAgainButton


func _ready() -> void:
	if thresholds == null:
		thresholds = load(THRESHOLDS_PATH) as RankThresholds
	if thresholds == null:
		thresholds = RankThresholds.new()
	PanelStyler.apply(%RankPanel, UIColors.PRIMARY, 24)
	PanelStyler.apply(%BreakdownPanel, UIColors.AI)
	_confetti.emitting = false
	_new_record.visible = false
	UIFocus.enable(self)
	_play_again.pressed.connect(_on_play_again)


## Shows the results. `total` is the final score; `best` the previous record
## (it is compared to show NEW RECORD).
func show_results(total: int, best: int = 0, breakdown: Dictionary = {}) -> void:
	var rank: StringName = rank_for(total)
	_rank_label.text = String(rank)
	_apply_rank_color(rank)
	_total_label.text = "SCORE: %d" % total
	var record: bool = total > best
	_best_label.text = "BEST: %d" % maxi(best, total)
	_new_record.visible = record
	_confetti.emitting = rank == &"S+"
	var lines: PackedStringArray = PackedStringArray()
	for key: String in breakdown:
		lines.append("%s: %d" % [key, int(breakdown[key])])
	_breakdown_label.text = "\n".join(lines)
	_flavor_label.text = flavor_for(rank)
	UIFocus.grab_first(self)


## Records the score in SaveSystem. Returns true if it was a new record.
func submit(total: int) -> bool:
	var rank: StringName = rank_for(total)
	var save: Object = _resolve(SAVE_PATH)
	var is_record: bool = false
	if save != null and save.has_method("submit_score"):
		is_record = bool(save.submit_score(total, rank))
	score_submitted.emit(total, rank)
	return is_record


## Authoritative rank: the thresholds of `rank_thresholds.tres` (data, brief:
## "use them, do not rewrite them"). ScoreDirector only comes in if there are no
##
## NOTE: the thresholds live in `GameConfig.tres` (§1.3, single source).
## This resource is synchronized from there in `_ready` so the UI never
## has an out-of-sync copy of the balance.
func rank_for(score: int) -> StringName:
	if thresholds != null:
		thresholds.sync_from_config()
		return thresholds.rank_for(score)
	var score_dir: Object = _resolve(SCORE_PATH)
	if score_dir != null and score_dir.has_method("rank_for_score"):
		return score_dir.rank_for_score(score) as StringName
	return &"D"


## PLAY AGAIN: it resets the score and restarts the match.
func _on_play_again() -> void:
	var score_dir: Object = _resolve(SCORE_PATH)
	if score_dir != null and score_dir.has_method("reset"):
		score_dir.reset()
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("start_match"):
		match_mgr.start_match()
	play_again_pressed.emit()


## Rank shown (for tests).
func rank_text() -> String:
	return _rank_label.text


## True if the new record notice is shown (for tests).
func new_record_visible() -> bool:
	return _new_record.visible


## Rank humor line (for tests).
func flavor_text() -> String:
	return _flavor_label.text


## Total line (for tests).
func total_text() -> String:
	return _total_label.text


## Record line (for tests).
func record_text() -> String:
	return _best_label.text


func _apply_rank_color(rank: StringName) -> void:
	match rank:
		&"S+", &"S":
			_rank_label.modulate = UIColors.PRIMARY
		&"A":
			_rank_label.modulate = UIColors.GOOD
		&"B":
			_rank_label.modulate = UIColors.AI
		&"C":
			_rank_label.modulate = UIColors.WARN
		_:
			_rank_label.modulate = UIColors.DANGER


## Humor by rank (§2: the announcer is sarcastic but NEVER cruel).
func flavor_for(rank: StringName) -> String:
	match rank:
		&"S+":
			return "S-RANK! You absolute monster."
		&"S":
			return "FLAWLESS. I'm telling everyone."
		&"A":
			return "Almost beautiful. Almost."
		&"B":
			return "Solid. Suspiciously solid."
		&"C":
			return "You did a thing. Statistically, it was a thing."
		_:
			return "Well. You tried. Did you though?"


## Resolves an autoload by GameServices or, failing that, by path.
func _resolve(path: StringName) -> Object:
	var root := get_tree().root
	var services: Object = root.get_node_or_null(String(SERVICES_PATH)) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(StringName(String(path).get_file()))
		if via_services != null:
			return via_services
	return root.get_node_or_null(String(path)) as Object
