extends Control
class_name TitleScreen
## Title screen (scaffold §13.2): big logo, PLAY, control hints,
## best score.
##
## Integration (§13.2):
## - PLAY starts the match via `MatchManager.start_match()`.
## - The record comes from `SaveSystem.best_score` (a property, NOT a method).
## - The music switches to CALM on reaching the title.
##
## The autoloads do NOT have a global class_name: they are resolved by path
## (`/root/X`) or via `GameServices.lookup()`, and every call is guarded with
## `has_method` so the screen keeps instancing headless without them.

const SERVICES_PATH := &"/root/GameServices"
const MATCH_PATH := &"/root/MatchManager"
const SAVE_PATH := &"/root/SaveSystem"
const MUSIC_PATH := &"/root/MusicDirector"

## Title music state (MusicDirector.STATE_CALM, scaffold §10.2).
const MUSIC_CALM: StringName = &"CALM"

signal play_pressed()

@onready var _best_label: Label = %BestLabel
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	PanelStyler.apply(%LogoPanel, UIColors.PRIMARY, 24)
	PanelStyler.apply(%HintPanel, UIColors.AI)
	UIFocus.enable(self)
	_play_button.pressed.connect(_on_play)
	_best_label.text = "BEST: %s" % _format_best(best_score())
	# The title always sounds calm; if there is no music, it degrades silently.
	_play_calm_music()


## PLAY: it starts the match and notifies whoever listens to the signal.
func _on_play() -> void:
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("start_match"):
		match_mgr.start_match()
	play_pressed.emit()


## Saved record, or 0 if there is no SaveSystem (silent degradation).
func best_score() -> int:
	var save: Object = _resolve(SAVE_PATH)
	if save == null:
		return 0
	var stored: Variant = save.get(&"best_score")
	if stored == null:
		return 0
	return int(stored)


## Record line (for tests).
func best_text() -> String:
	return _best_label.text


## Logo text (for tests).
func title_text() -> String:
	return %TitleLabel.text


## Asks MusicDirector for the CALM state of the title.
func _play_calm_music() -> void:
	var music: Object = _resolve(MUSIC_PATH)
	if music != null and music.has_method("play_music_state"):
		music.play_music_state(MUSIC_CALM)


## Resolves an autoload: first by GameServices, and if not, by path.
## It degrades to null quietly when the system is not present.
func _resolve(path: StringName) -> Object:
	var root := get_tree().root
	var services: Object = root.get_node_or_null(String(SERVICES_PATH)) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(StringName(String(path).get_file()))
		if via_services != null:
			return via_services
	return root.get_node_or_null(String(path)) as Object


## Groups the thousands: 1234567 -> "1,234,567".
func _format_best(v: int) -> String:
	var s := str(int(absi(v)))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
