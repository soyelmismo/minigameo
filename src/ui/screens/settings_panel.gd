extends Control
class_name SettingsPanel
## Panel de accesibilidad (scaffold §13.3, AGENTS.md §8):
## shake 0..1, flashes, indicadores de daltonismo, subtítulos, velocidad de
## texto. Persiste vía SettingsManager (que guarda en `user://` a través de
## SaveSystem), así que sobrevive a un reinicio.
##
## Navegable con teclado Y mando: sliders y toggles son enfocables, y
## `ui_cancel` (Esc / B) cierra el panel igual que BACK.

signal closed()

@export var settings: AccessibilitySettings = null

const SETTINGS_RESOURCE_PATH := "res://src/ui/screens/accessibility_settings.tres"

@onready var _shake_slider: HSlider = %ShakeSlider
@onready var _flash_toggle: CheckButton = %FlashToggle
@onready var _colorblind_toggle: CheckButton = %ColorblindToggle
@onready var _subtitle_toggle: CheckButton = %SubtitleToggle
@onready var _text_speed: HSlider = %TextSpeedSlider
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	if settings == null:
		settings = load(SETTINGS_RESOURCE_PATH) as AccessibilitySettings
	if settings == null:
		settings = AccessibilitySettings.new()
	settings.load_from_settings_manager()
	PanelStyler.apply(%SettingsPanel, UIColors.AI, 24)
	UIFocus.enable(self)
	_apply_to_widgets()
	_close_button.pressed.connect(_on_close)


## Abre el panel y toma el foco del primer control enfocable.
func open() -> void:
	settings.load_from_settings_manager()
	_apply_to_widgets()
	show()
	UIFocus.grab_first(self)


## Refleja el modelo en los widgets.
func _apply_to_widgets() -> void:
	_shake_slider.min_value = 0.0
	_shake_slider.max_value = 1.0
	_shake_slider.step = 0.05
	_shake_slider.value = settings.shake_intensity
	_flash_toggle.button_pressed = settings.flashes_enabled
	_colorblind_toggle.button_pressed = settings.colorblind_indicators
	_subtitle_toggle.button_pressed = settings.subtitles_always_visible
	_text_speed.min_value = 0.5
	_text_speed.max_value = 2.0
	_text_speed.step = 0.1
	_text_speed.value = settings.text_speed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


## BACK / Esc: recoge los widgets, persiste y avisa al dueño.
func _on_close() -> void:
	_collect_from_widgets()
	settings.apply_to_settings_manager()
	hide()
	closed.emit()


## Refleja los widgets en el modelo (clampeados a los rangos de §13.3).
func _collect_from_widgets() -> void:
	settings.shake_intensity = clampf(_shake_slider.value, 0.0, 1.0)
	settings.flashes_enabled = _flash_toggle.button_pressed
	settings.colorblind_indicators = _colorblind_toggle.button_pressed
	settings.subtitles_always_visible = _subtitle_toggle.button_pressed
	settings.text_speed = clampf(_text_speed.value, 0.5, 2.0)


## Ajustes actuales (para tests).
func current_settings() -> AccessibilitySettings:
	return settings


## Valor vigente de shake tras recoger los widgets (para tests).
func shake_value() -> float:
	_collect_from_widgets()
	return settings.shake_intensity


## Valor vigente de la velocidad de texto (para tests).
func text_speed_value() -> float:
	_collect_from_widgets()
	return settings.text_speed
