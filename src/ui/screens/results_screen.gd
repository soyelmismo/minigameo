extends Control
class_name ResultsScreen
## Pantalla de resultados (scaffold §13.2): rank D..S+ enorme, desglose
## de score, récord, PLAY AGAIN. Humor según rank (§2): celebración en
## S+ (placeholder de confeti), silencio incómodo en D.

signal play_again_pressed()

@export var thresholds: RankThresholds = null

@onready var _rank_label: Label = %RankLabel
@onready var _flavor_label: Label = %ResultsFlavor
@onready var _total_label: Label = %TotalLabel
@onready var _best_label: Label = %RecordLabel
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _confetti: CPUParticles2D = %Confetti
@onready var _new_record: Label = %NewRecordLabel


func _ready() -> void:
	if thresholds == null:
		thresholds = load("res://src/ui/screens/rank_thresholds.tres") as RankThresholds
	if thresholds == null:
		thresholds = RankThresholds.new()
	PanelStyler.apply(%RankPanel, UIColors.PRIMARY, 24)
	PanelStyler.apply(%BreakdownPanel, UIColors.AI)
	_confetti.emitting = false
	_new_record.visible = false
	%PlayAgainButton.pressed.connect(func() -> void: play_again_pressed.emit())


## Muestra los resultados. `total` es el score final; `best` el récord
## previo (se compara para mostrar NEW RECORD).
func show_results(total: int, best: int = 0, breakdown: Dictionary = {}) -> void:
	var rank: StringName = thresholds.rank_for(total)
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
	_flavor_label.text = _flavor_for(rank)


## Rank mostrado (para tests).
func rank_text() -> String:
	return _rank_label.text


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


## Humor por rank (§2: el locutor es sarcástico pero NUNCA cruel).
func _flavor_for(rank: StringName) -> String:
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
