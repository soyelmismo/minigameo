extends Control
class_name PauseMenu
## Pause menu (scaffold §13.3): resume / settings / quit.
##
## Integration:
## - RESUME resumes the match (it lifts the pause of the tree and of MatchManager).
## - ACCESSIBILITY opens the `SettingsPanel` instanced here (sole owner of the
##   lifecycle of the panel, to avoid leaving orphan nodes when closing).
## - QUIT closes the match and returns to the title via `MatchManager.end_match()`.
##
## Navigable with keyboard AND gamepad: the three buttons are focusable and
## `ui_cancel` (Esc / B) resumes, just like RESUME.
##
## MatchManager does NOT have its own pause API: the pause lives in the SceneTree
## (`get_tree().paused`), so this menu is marked PROCESS_MODE_ALWAYS to
## keep processing input while the world is paused.

const SERVICES_PATH := &"/root/GameServices"
const MATCH_PATH := &"/root/MatchManager"
const SETTINGS_SCENE_PATH := "res://src/ui/screens/settings_panel.tscn"

signal resume_pressed()
signal settings_pressed()
signal quit_pressed()

@onready var _settings_button: Button = %SettingsButton
@onready var _panel: SettingsPanel = null

var _settings_scene: PackedScene = null


func _ready() -> void:
	# The menu must respond with the world paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	PanelStyler.apply(%PausePanel, UIColors.PRIMARY, 24)
	UIFocus.enable(self)
	%ResumeButton.pressed.connect(func() -> void: resume_pressed.emit())
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	%QuitButton.pressed.connect(func() -> void: quit_pressed.emit())
	_settings_scene = load(SETTINGS_SCENE_PATH) as PackedScene


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()


## Resumes the world and closes this menu.
func resume() -> void:
	_set_paused(false)
	hide()
	resume_pressed.emit()


## Pauses the world and takes the focus of the first button (RESUME).
func open() -> void:
	_set_paused(true)
	show()
	UIFocus.grab_first(self)


## Opens the settings panel. If the scene is missing, it degrades without breaking.
func open_settings() -> void:
	if _settings_scene == null:
		push_warning("PauseMenu: settings scene missing at %s" % SETTINGS_SCENE_PATH)
		settings_pressed.emit()
		return
	if _panel != null and is_instance_valid(_panel):
		_panel.show()
		UIFocus.grab_first(_panel)
		settings_pressed.emit()
		return
	_panel = _settings_scene.instantiate() as SettingsPanel
	add_child(_panel)
	_panel.closed.connect(_on_settings_closed)
	UIFocus.grab_first(_panel)
	settings_pressed.emit()


## Leaves the match back to the title.
func quit_to_title() -> void:
	_set_paused(false)
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("end_match"):
		match_mgr.end_match()
	quit_pressed.emit()


## The panel is removed from the tree when closing: not a single orphan node (§1.4).
func _on_settings_closed() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	UIFocus.grab_first(self)


## Connects the pause to the SceneTree and tells MatchManager about it if one day
## it exposes its own pause API (today it does not: it is queried, not assumed).
func _set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = paused
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("set_paused"):
		match_mgr.set_paused(paused)


## Resolves an autoload by GameServices or, failing that, by path.
func _resolve(path: StringName) -> Object:
	var root := get_tree().root
	var services: Object = root.get_node_or_null(String(SERVICES_PATH)) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(StringName(String(path).get_file()))
		if via_services != null:
			return via_services
	return root.get_node_or_null(String(path)) as Object
