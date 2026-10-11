extends Control
class_name SettingsPanel
## Panel de accesibilidad (scaffold §13.3, AGENTS.md §8):
## shake 0..1, flashes, indicadores de daltonismo, subtítulos, velocidad
## de texto. Persiste vía SettingsManager duck-typed (si existe).

signal closed()

@export var settings: AccessibilitySettings = null

@onready var _shake_slider: HSlider = %ShakeSlider
@onready var _flash_toggle: CheckButton = %FlashToggle
@onready var _colorblind_toggle: CheckButton = %ColorblindToggle
@onready var _subtitle_toggle: CheckButton = %SubtitleToggle
@onready var _text_speed: HSlider = %TextSpeedSlider


func _ready() -> void:
	if settings == null:
		settings = load("res://src/ui/screens/accessibility_settings.tres") as AccessibilitySettings
	if settings == null:
		settings = AccessibilitySettings.new()
	settings.load_from_settings_manager()
	PanelStyler.apply(%SettingsPanel, UIColors.AI, 24)
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
	%CloseButton.pressed.connect(_on_close)


func _on_close() -> void:
	settings.shake_intensity = _shake_slider.value
	settings.flashes_enabled = _flash_toggle.button_pressed
	settings.colorblind_indicators = _colorblind_toggle.button_pressed
	settings.subtitles_always_visible = _subtitle_toggle.button_pressed
	settings.text_speed = _text_speed.value
	settings.apply_to_settings_manager()
	closed.emit()


## Ajustes actuales (para tests).
func current_settings() -> AccessibilitySettings:
	return settings
