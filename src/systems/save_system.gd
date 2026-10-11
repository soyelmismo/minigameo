extends Node
## SaveSystem — local records + settings persistence (scaffold §6 systems).
##
## Stores the best score/rank and player settings in user:// as JSON.
## Degrades silently when the filesystem is unavailable (tests).

const SAVE_PATH := "user://arcade_block_save.json"
const SETTINGS_PATH := "user://arcade_block_settings.json"

var best_score: int = 0
var best_rank: StringName = &"D"
var _settings: Dictionary = {}


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"save") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("SaveSystem", &"save", self)
	_load()


## Record a finished match's score if it beats the record. Returns true when
## it is a new best.
func submit_score(score: int, rank: StringName) -> bool:
	if score > best_score:
		best_score = score
		best_rank = rank
		_save()
		return true
	return false


## Wipes the record (tests and "clear save" flows). Keeps the file coherent.
func reset() -> void:
	best_score = 0
	best_rank = &"D"
	_save()


## Read/write a settings value (accessibility lives here too).
func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	return _settings.get(String(key), default_value)


func set_setting(key: StringName, value: Variant) -> void:
	_settings[String(key)] = value
	_save_settings()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		var d := data as Dictionary
		best_score = int(d.get("best_score", 0))
		best_rank = StringName(str(d.get("best_rank", "D")))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"best_score": best_score,
		"best_rank": String(best_rank),
	}))
	f.close()


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_settings))
	f.close()
