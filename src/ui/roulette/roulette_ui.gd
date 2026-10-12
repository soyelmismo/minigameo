extends Control
class_name RouletteUI
## Roulette announcement (scaffold §13.2): a dramatic full-screen
## moment with the display_name + objective_text + flavor_text of the
## micro-game BEFORE the start. Duration and texts come from the data.

signal announce_finished()

@export var cfg: HUDConfig = null

@onready var _name_label: Label = %MinigameName
@onready var _objective_label: Label = %ObjectiveText
@onready var _flavor_label: Label = %FlavorText
@onready var _panel: Panel = %AnnouncePanel

var _timer: SceneTreeTimer = null


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	PanelStyler.apply(_panel, UIColors.PRIMARY, 32)
	visible = false


## Shows the announcement with the texts of the chosen micro-game.
func announce(display_name: String, objective_text: String, flavor_text: String) -> void:
	_name_label.text = display_name.to_upper()
	_objective_label.text = objective_text
	_flavor_label.text = flavor_text
	visible = true
	_punch()
	if _timer != null:
		_timer.time_left = 0.0
	_timer = get_tree().create_timer(cfg.announce_duration_s)
	_timer.timeout.connect(_on_timeout)


## Construye el anuncio desde una MinigameMetadata (duck-typed: si el
## object does not carry the fields, it degrades to empty text without breaking).
func announce_from_metadata(meta: Object) -> void:
	if meta == null:
		return
	var name_part: String = String(meta.display_name) if "display_name" in meta else ""
	var objective_part: String = String(meta.objective_text) if "objective_text" in meta else ""
	var flavor_part: String = String(meta.flavor_text) if "flavor_text" in meta else ""
	announce(name_part, objective_part, flavor_part)


## Current texts (for tests).
func name_text() -> String:
	return _name_label.text


func shown_objective() -> String:
	return _objective_label.text


func shown_flavor() -> String:
	return _flavor_label.text


func _on_timeout() -> void:
	visible = false
	announce_finished.emit()


func _punch() -> void:
	_name_label.scale = Vector2.ONE * 1.25
	_name_label.modulate = UIColors.PRIMARY
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_name_label, "scale", Vector2.ONE, 0.35)
	t.tween_property(_name_label, "modulate", UIColors.TEXT, 0.35)
