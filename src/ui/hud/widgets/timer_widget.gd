extends Control
class_name TimerWidget
## TIMER widget (scaffold §13.1): countdown with a red pulse below the
## threshold, or accumulated mode (for HOLD_ZONE_T, §8.3).

const MODE_COUNTDOWN := &"COUNTDOWN"
const MODE_ACCUMULATE := &"ACCUMULATE"

@export var cfg: HUDConfig = null
@export var mode: StringName = MODE_COUNTDOWN

@onready var _time_label: Label = %TimeLabel
@onready var _icon: TextureRect = %Icon
@onready var _panel: Panel = %Panel

var _remaining_s: float = 0.0
var _accumulated_s: float = 0.0
var _pulse_active: bool = false


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_apply_outline(UIColors.semantic(&"AI"))


func _process(delta: float) -> void:
	if mode == MODE_ACCUMULATE:
		_accumulated_s += delta
		_time_label.text = _format(_accumulated_s)
		return
	if _remaining_s <= 0.0:
		return
	_remaining_s = maxf(0.0, _remaining_s - delta)
	_time_label.text = _format(_remaining_s)
	_update_pulse(delta)


## Configures the widget from the slot (icon + semantic color).
func configure(icon: Texture2D, color: Color) -> void:
	if _icon != null:
		if icon != null:
			_icon.texture = icon
		_icon.modulate = color
	if _panel != null:
		_apply_outline(color)


## Starts the countdown from `seconds`.
func set_duration(seconds: float) -> void:
	_remaining_s = maxf(0.0, seconds)
	mode = MODE_COUNTDOWN
	_time_label.text = _format(_remaining_s)


## Switches to accumulated mode (the time on screen goes up).
func set_accumulate_mode(enabled: bool) -> void:
	mode = MODE_ACCUMULATE if enabled else MODE_COUNTDOWN
	_accumulated_s = 0.0


## Current remaining time (for tests and for the HUD).
func time_left() -> float:
	if mode == MODE_ACCUMULATE:
		return _accumulated_s
	return _remaining_s


## Text of the clock (for tests).
func time_text() -> String:
	return _time_label.text


func _format(t: float) -> String:
	var tenths := int(t * 10.0)
	var secs := tenths / 10
	var deci := tenths % 10
	return "%d.%d" % [secs, deci]


func _update_pulse(delta: float) -> void:
	var should_pulse: bool = _remaining_s <= cfg.pulse_threshold_s and _remaining_s > 0.0
	if should_pulse and not _pulse_active:
		_pulse_active = true
	if not should_pulse and _pulse_active:
		_pulse_active = false
		_time_label.modulate = UIColors.TEXT
		_time_label.scale = Vector2.ONE
		return
	if _pulse_active:
		var s: float = 1.0 + sin(Time.get_ticks_msec() * 0.001 * cfg.pulse_speed) * 0.12
		_time_label.scale = Vector2.ONE * s
		_time_label.modulate = UIColors.DANGER


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
