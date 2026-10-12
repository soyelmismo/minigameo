extends Control
class_name ProgressWidget
## PROGRESS widget (scaffold §13.1): bar with a valid-zone marker
## (STOP_IN_ZONE, RHYTHM, §8.3). The marker sweeps from 0..1.

@export var cfg: HUDConfig = null
## Center and width of the valid zone, both normalized 0..1.
@export var zone_center: float = 0.75
@export var zone_half_width: float = 0.08

@onready var _bar: ProgressBar = %Bar
@onready var _zone: Panel = %Zone
@onready var _marker: Panel = %Marker
@onready var _icon: TextureRect = %Icon
@onready var _panel: Panel = %Panel

var _position: float = 0.0
var _direction: float = 1.0
var _last_in_zone: bool = false


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_layout_zone()
	_apply_outline(UIColors.semantic(&"GOOD"))


func _process(delta: float) -> void:
	_position += _direction * cfg.sweep_speed * delta
	if _position >= 1.0:
		_position = 1.0
		_direction = -1.0
	elif _position <= 0.0:
		_position = 0.0
		_direction = 1.0
	_bar.value = _position
	var in_zone: bool = _in_zone(_position)
	if in_zone and not _last_in_zone:
		_marker.modulate = UIColors.GOOD
	_bar.modulate = UIColors.GOOD if in_zone else UIColors.AI
	_last_in_zone = in_zone


## Configures the widget from the slot (icon + semantic color).
func configure(icon: Texture2D, color: Color) -> void:
	if _icon != null:
		if icon != null:
			_icon.texture = icon
		_icon.modulate = color
	if _panel != null:
		_apply_outline(color)


## Adjusts the valid zone (from ObjectiveRecipe.tolerance, normalized).
func set_zone(center: float, half_width: float) -> void:
	zone_center = clampf(center, 0.0, 1.0)
	zone_half_width = clampf(half_width, 0.0, 0.5)
	_layout_zone()


## Current position of the marker (0..1, for tests).
func marker_position() -> float:
	return _position


## True if a normalized position falls inside the valid zone.
func zone_contains(pos: float) -> bool:
	return _in_zone(pos)


func _in_zone(pos: float) -> bool:
	return absf(pos - zone_center) <= zone_half_width


func _layout_zone() -> void:
	var anchor_min: float = maxf(0.0, zone_center - zone_half_width)
	var anchor_max: float = minf(1.0, zone_center + zone_half_width)
	_zone.anchor_left = anchor_min
	_zone.anchor_right = anchor_max


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
