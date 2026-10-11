extends Control
class_name PauseMenu
## Menú de pausa (scaffold §13.3): resume / ajustes / salir. La entrada
## de ajustes de accesibilidad abre el panel de settings.

signal resume_pressed()
signal settings_pressed()
signal quit_pressed()


func _ready() -> void:
	PanelStyler.apply(%PausePanel, UIColors.PRIMARY, 24)
	%ResumeButton.pressed.connect(func() -> void: resume_pressed.emit())
	%SettingsButton.pressed.connect(func() -> void: settings_pressed.emit())
	%QuitButton.pressed.connect(func() -> void: quit_pressed.emit())
