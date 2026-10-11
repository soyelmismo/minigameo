extends Control
class_name PauseMenu
## Menú de pausa (scaffold §13.3): resume / ajustes / salir.
##
## Integración:
## - RESUME reanuda la partida (quita la pausa del árbol y de MatchManager).
## - ACCESSIBILITY abre el `SettingsPanel` instanciado aquí (única dueña del
##   ciclo de vida del panel, para no dejar nodos huérfanos al cerrar).
## - QUIT cierra la partida y vuelve a título vía `MatchManager.end_match()`.
##
## Navegable con teclado Y mando: los tres botones son enfocables y
## `ui_cancel` (Esc / B) reanuda, igual que RESUME.
##
## MatchManager NO tiene API de pausa propia: la pausa vive en el SceneTree
## (`get_tree().paused`), así que este menú se marca PROCESS_MODE_ALWAYS para
## seguir procesando entrada mientras el mundo está en pausa.

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
	# El menú debe responder con el mundo en pausa.
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


## Reanuda el mundo y cierra este menú.
func resume() -> void:
	_set_paused(false)
	hide()
	resume_pressed.emit()


## Pausa el mundo y toma el foco del primer botón (RESUME).
func open() -> void:
	_set_paused(true)
	show()
	UIFocus.grab_first(self)


## Abre el panel de ajustes. Si la escena falta, degrada sin romper.
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


## Sale de la partida de vuelta a título.
func quit_to_title() -> void:
	_set_paused(false)
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("end_match"):
		match_mgr.end_match()
	quit_pressed.emit()


## El panel se quita del árbol al cerrar: ni un nodo huérfano (§1.4).
func _on_settings_closed() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	UIFocus.grab_first(self)


## Conecta la pausa al SceneTree y se lo comunica a MatchManager si algún día
## expone su propia API de pausa (hoy no la tiene: se consulta, no se asume).
func _set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = paused
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("set_paused"):
		match_mgr.set_paused(paused)


## Resuelve un autoload por GameServices o, en su defecto, por path.
func _resolve(path: StringName) -> Object:
	var root := get_tree().root
	var services: Object = root.get_node_or_null(String(SERVICES_PATH)) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(StringName(String(path).get_file()))
		if via_services != null:
			return via_services
	return root.get_node_or_null(String(path)) as Object
