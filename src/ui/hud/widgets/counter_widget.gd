extends Control
class_name CounterWidget
## Widget COUNTER (scaffold §13.1): "N / target" + icono + pop al subir.
##
## Se parametriza por HUDRecipe (color_hint, icon); el HUD le pasa los
## contadores. Cero lógica específica de micro-juego.

@export var cfg: HUDConfig = null

@onready var _value_label: Label = %ValueLabel
@onready var _target_label: Label = %TargetLabel
@onready var _icon: TextureRect = %Icon
@onready var _panel: Panel = %Panel

var _pop_tween: Tween = null


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_apply_outline(UIColors.semantic(&"PRIMARY"))
	_target_label.text = "/ 0"
	_value_label.text = "0"


## Configura el widget desde el slot (icon + color semántico).
func configure(icon: Texture2D, color: Color) -> void:
	if _icon != null:
		if icon != null:
			_icon.texture = icon
		_icon.modulate = color
	if _panel != null:
		_apply_outline(color)


## Establece el objetivo (target) mostrado tras la barra.
func set_target(target: int) -> void:
	_target_label.text = "/ %d" % target


## Establece el contador. Subir el contador dispara el pop (§13.2).
func set_value(value: int) -> void:
	var previous := int(_value_label.text)
	_value_label.text = str(value)
	if value > previous:
		pop()


## Texto del contador (para tests).
func value_text() -> String:
	return _value_label.text


## Escala actual del número (para tests del pop).
func value_scale() -> float:
	return _value_label.scale.x


## Etiqueta "N / target" (para tests).
func target_text() -> String:
	return _target_label.text


## Dispara el pop (escala + color) del número (§13.2).
func pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_icon.scale = Vector2.ONE * cfg.pop_scale
	_value_label.scale = Vector2.ONE * cfg.pop_scale
	_value_label.modulate = UIColors.PRIMARY
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(_icon, "scale", Vector2.ONE, cfg.pop_duration_s)
	_pop_tween.tween_property(_value_label, "scale", Vector2.ONE, cfg.pop_duration_s)
	_pop_tween.tween_property(_value_label, "modulate", UIColors.TEXT, cfg.pop_duration_s)


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
