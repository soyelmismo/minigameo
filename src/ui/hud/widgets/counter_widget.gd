extends Control
class_name CounterWidget
## COUNTER widget (scaffold §13.1): "N / target" + icon + pop on rise.
##
## It is parametrized by HUDRecipe (color_hint, icon); the HUD passes it the
## counters. Zero micro-game-specific logic.

@export var cfg: HUDConfig = null

@onready var _value_label: Label = %ValueLabel
@onready var _target_label: Label = %TargetLabel
@onready var _icon: TextureRect = %Icon
@onready var _panel: Panel = %Panel

var _pop_scale: float = 1.0
var _tint: float = 0.0


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_apply_outline(UIColors.semantic(&"PRIMARY"))
	_target_label.text = "/ 0"
	_value_label.text = "0"


## Configures the widget from the slot (icon + semantic color).
func configure(icon: Texture2D, color: Color) -> void:
	if _icon != null:
		if icon != null:
			_icon.texture = icon
		_icon.modulate = color
	if _panel != null:
		_apply_outline(color)


## Sets the objective (target) shown after the bar.
func set_target(target: int) -> void:
	_target_label.text = "/ %d" % target


## Sets the counter. Raising the counter triggers the pop (§13.2).
func set_value(value: int) -> void:
	var previous := int(_value_label.text)
	_value_label.text = str(value)
	if value > previous:
		pop()


## Text of the counter (for tests).
func value_text() -> String:
	return _value_label.text


## Current scale of the number (for the pop tests).
func value_scale() -> float:
	return _value_label.scale.x


## "N / target" label (for tests).
func target_text() -> String:
	return _target_label.text


## Triggers the number pop (scale + color) (§13.2).
func pop() -> void:
	# Deterministic pop driven by _process (HudAnim); no SceneTreeTween, which
	# does not step in headless runs and hides its timing inside the SceneTree.
	# The punch lands synchronously so the increment frame reads instantly.
	_pop_scale = cfg.pop_scale
	_tint = 1.0
	var s := Vector2.ONE * _pop_scale
	_icon.scale = s
	_value_label.scale = s
	_value_label.modulate = UIColors.PRIMARY


func _process(delta: float) -> void:
	if HudAnim.settled(_pop_scale, 1.0) and HudAnim.settled(_tint, 0.0):
		return
	_pop_scale = HudAnim.approach(_pop_scale, 1.0, cfg.pop_decay, delta)
	_tint = HudAnim.approach(_tint, 0.0, cfg.pop_decay, delta)
	var s := Vector2.ONE * _pop_scale
	_icon.scale = s
	_value_label.scale = s
	_value_label.modulate = UIColors.TEXT.lerp(UIColors.PRIMARY, _tint)


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
