extends Control
class_name SequenceWidget
## SEQUENCE widget (scaffold §13.1): steps in order. Tick on a hit,
## shake on a miss. Used by GATES_IN_ORDER / MEMORY_REPLAY / CHAIN_N.

@export var cfg: HUDConfig = null

@onready var _steps: HBoxContainer = %Steps
@onready var _icon: TextureRect = %Icon
@onready var _panel: Panel = %Panel

const _DONE_COLOR := UIColors.GOOD
const _PENDING_COLOR := UIColors.TEXT_DIM
const _ACTIVE_COLOR := UIColors.PRIMARY

var _current: int = 0
var _total: int = 0
var _shake_tween: Tween = null


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_apply_outline(UIColors.semantic(&"PRIMARY"))


## Configures the widget from the slot (icon + semantic color).
func configure(icon: Texture2D, color: Color) -> void:
	if _icon != null:
		if icon != null:
			_icon.texture = icon
		_icon.modulate = color
	if _panel != null:
		_apply_outline(color)


## Sets the number of steps of the sequence.
func set_step_count(count: int) -> void:
	_total = maxi(0, count)
	_current = 0
	for child in _steps.get_children():
		child.queue_free()
	for i in _total:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(36, 36)
		var style := StyleBoxFlat.new()
		style.bg_color = UIColors.PANEL
		style.border_color = _PENDING_COLOR
		style.set_corner_radius_all(8)
		p.add_theme_stylebox_override("panel", style)
		_steps.add_child(p)
	_refresh_steps()

## Marks the current step as hit (tick + advance).
func hit_step() -> void:
	if _current < _total:
		_current += 1
	_refresh_steps()
	_pop()


## Miss: shake of the widget and reset of the sequence.
func miss_step() -> void:
	_shake()
	for i in _total:
		var step: Panel = _steps.get_child(i)
		if step != null:
			_stylebox_of(step).border_color = _PENDING_COLOR
	_current = 0
	_refresh_steps()


## Index of the active step (for tests).
func current_step() -> int:
	return _current


## Total number of steps (for tests).
func total_steps() -> int:
	return _total


func _refresh_steps() -> void:
	for i in _total:
		var step: Panel = _steps.get_child(i)
		if step == null:
			continue
		var col: Color = _DONE_COLOR if i < _current else _PENDING_COLOR
		if i == _current:
			col = _ACTIVE_COLOR
		(_stylebox_of(step)).border_color = col


func _pop() -> void:
	var last_done: Panel = _steps.get_child(_current - 1) if _current > 0 else null
	if last_done == null:
		return
	last_done.scale = Vector2.ONE * 1.4
	var t := create_tween()
	t.tween_property(last_done, "scale", Vector2.ONE, cfg.pop_duration_s)


func _stylebox_of(step: Panel) -> StyleBoxFlat:
	var sb: StyleBoxFlat = step.get_theme_stylebox("panel")
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		step.add_theme_stylebox_override("panel", sb)
	return sb


func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var amp: float = cfg.shake_amplitude_px
	for i in 6:
		var off: float = amp if i % 2 == 0 else -amp
		_shake_tween.tween_property(_panel, "position:x", off, cfg.shake_duration_s / 6.0)
	_shake_tween.tween_property(_panel, "position:x", 0.0, cfg.shake_duration_s / 6.0)


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
