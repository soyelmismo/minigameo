extends Control
class_name MultiplierWidget
## Widget MULTIPLIER (scaffold §13.1): "x3.5" grande y ruidoso;
## scale-punch al subir.

@export var cfg: HUDConfig = null

@onready var _value_label: Label = %ValueLabel
@onready var _panel: Panel = %Panel

var _value: float = 1.0
var _pop_scale: float = 1.0
var _tint: float = 0.0


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
	# Deterministic pop driven by _process (HudAnim); no SceneTreeTween, which
	# does not step in headless runs and hides its timing inside the SceneTree.
	# The punch is applied synchronously so the frame the value rises is already
	# scaled; only the return to rest is time-based.
	_pop_scale = cfg.pop_scale + 0.15
	_tint = 1.0
	_value_label.scale = Vector2.ONE * _pop_scale
	_value_label.modulate = UIColors.PRIMARY


func _process(delta: float) -> void:
	if HudAnim.settled(_pop_scale, 1.0) and HudAnim.settled(_tint, 0.0):
		return
	_pop_scale = HudAnim.approach(_pop_scale, 1.0, cfg.pop_decay, delta)
	_tint = HudAnim.approach(_tint, 0.0, cfg.pop_decay, delta)
	_value_label.scale = Vector2.ONE * _pop_scale
	_value_label.modulate = UIColors.TEXT.lerp(UIColors.PRIMARY, _tint)


func _apply_outline(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = UIColors.PANEL
	style.border_color = color
	_panel.add_theme_stylebox_override("panel", style)
