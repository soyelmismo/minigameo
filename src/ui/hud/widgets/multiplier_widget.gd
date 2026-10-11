extends Control
class_name MultiplierWidget
## Widget MULTIPLIER (scaffold §13.1): "x3.5" grande y ruidoso;
## scale-punch al subir.

@export var cfg: HUDConfig = null

@onready var _value_label: Label = %ValueLabel
@onready var _panel: Panel = %Panel

var _value: float = 1.0
var _pop_tween: Tween = null


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_apply_outline(UIColors.PRIMARY)
	_value_label.text = "x1.0"


## Establece el multiplicador. Subir dispara el scale-punch (§13.2).
func set_value(new_value: float) -> void:
	var rose: bool = new_value > _value
	_value = new_value
	_value_label.text = "x%.1f" % new_value
	if rose:
		_punch()


## Multiplicador actual (para tests).
func value() -> float:
	return _value


## Texto del multiplicador (para tests).
func value_text() -> String:
	return _value_label.text


## Escala actual del número (para tests del punch).
func label_scale() -> float:
	return _value_label.scale.x


func _punch() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_value_label.scale = Vector2.ONE * (cfg.pop_scale + 0.15)
	_value_label.modulate = UIColors.PRIMARY
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(_value_label, "scale", Vector2.ONE, cfg.pop_duration_s)
	_pop_tween.tween_property(_value_label, "modulate", UIColors.TEXT, cfg.pop_duration_s)


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
