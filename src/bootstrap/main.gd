extends Node
## Main scene — bootstraps the match flow (scaffold §5, §13.2).
##
## BOOT -> TITLE -> COUNTDOWN -> FREE_ROAM -> ... is owned by the
## MatchManager autoload. This scene only composes the layers:
##   World    (Node3D)      — CityBlock + Player + camera rig
##   HUD      (CanvasLayer) — auto-generated objective HUD (§13.1)
##   Effects  (CanvasLayer) — flash overlay, topmost layer (§6.7)
## and drives the menu screens (title/pause/results) as the match state
## changes. No gameplay lives here: systems are autoloads resolved through
## GameServices/EventBus, never referenced from this scene (§1.1).

## Avatar spawn placement. Lives in data, never as a magic number buried in
## logic (§1.3). The scene transform mirrors this default; the export is
## the single tunable source.
@export var player_spawn_position: Vector3 = Vector3(0.0, 1.0, 0.0)
## Hard ceiling on how many distinct micro-games a single match runs before
## the roulette refuses to spin. Tuning data, not a magic number (§1.3).
@export var max_minigames_per_match: int = 30

const TITLE_SCENE := "res://src/ui/screens/title_screen.tscn"
const PAUSE_SCENE := "res://src/ui/screens/pause_menu.tscn"
const RESULTS_SCENE := "res://src/ui/screens/results_screen.tscn"

@onready var world: Node3D = $World
@onready var player: Node3D = $World/Player
@onready var hud: CanvasLayer = $HUD
@onready var effects: CanvasLayer = $Effects

var _title: TitleScreen = null
var _pause: PauseMenu = null
var _results: ResultsScreen = null
## True once a match has started and before it ends: the pause key is live.
var _match_live: bool = false


func _ready() -> void:
	_place_player()
	_register_player()
	assert(world != null, "World layer missing in main.tscn")
	assert(player != null, "Player layer missing in main.tscn")
	assert(hud != null, "HUD layer missing in main.tscn")
	assert(effects != null, "Effects layer missing in main.tscn")
	_build_screens()
	_connect_bus()


## Park the avatar at the exported spawn point.
func _place_player() -> void:
	if player == null:
		return
	player.position = player_spawn_position


## Publish the player in the service locator so CameraDirector,
## PowerUpDirector and MinigameDirector resolve it without reaching into
## the scene tree. player.gd self-registers as well; re-registering the
## same instance is idempotent (last registration wins).
func _register_player() -> void:
	if player == null:
		return
	var locator: Object = GameServices.lookup(&"core")
	if locator != null and locator.has_method("register"):
		locator.register(&"player", player)


# --- Menu screen flow (§5: TITLE -> match -> RESULTS -> TITLE) ---

func _build_screens() -> void:
	_title = _add_screen(TITLE_SCENE) as TitleScreen
	_pause = _add_screen(PAUSE_SCENE) as PauseMenu
	_results = _add_screen(RESULTS_SCENE) as ResultsScreen
	if _title != null:
		_title.play_pressed.connect(_on_play_pressed)
	if _pause != null:
		_pause.quit_pressed.connect(_on_quit_pressed)
		_pause.resume_pressed.connect(_on_pause_resumed)
		_pause.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Escape / gamepad B is the pause key (§8: fully playable without the
	# mouse). Only live during a match: pausing on the title screen would
	# freeze the menu behind it.
	if not _match_live or _pause == null:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# The menu consumes Escape itself to resume; here we OPEN it.
	if _pause.visible:
		return
	_pause.open()
	get_viewport().set_input_as_handled()


func _on_pause_resumed() -> void:
	if _pause != null:
		_pause.visible = false


func _add_screen(path: String) -> Node:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("Main: screen missing at %s" % path)
		return null
	var node: Node = scene.instantiate()
	add_child(node)
	return node


func _connect_bus() -> void:
	var bus := _resolve(&"EventBus")
	if bus == null or not bus.has_signal("match_started"):
		return
	bus.match_started.connect(_on_match_started)
	bus.match_time_up.connect(_on_match_time_up)
	bus.match_reset.connect(_on_match_reset)


func _on_play_pressed() -> void:
	if _title != null:
		_title.visible = false


func _on_play_again_pressed() -> void:
	if _results != null:
		_results.visible = false
	if _title != null:
		_title.visible = true


func _on_quit_pressed() -> void:
	if _pause != null:
		_pause.visible = false
	if _results != null:
		_results.visible = true


func _on_match_started() -> void:
	_match_live = true
	if _title != null:
		_title.visible = false
	if _results != null:
		_results.visible = false


func _on_match_time_up() -> void:
	_match_live = false
	if _pause != null:
		_pause.visible = false
	if _results != null:
		_results.visible = true


func _on_match_reset() -> void:
	_match_live = false
	if _pause != null:
		_pause.visible = false
	if _results != null:
		_results.visible = false
	if _title != null:
		_title.visible = true


func _resolve(node_name: StringName) -> Object:
	var tree := get_tree()
	if tree == null:
		return null
	var node: Node = tree.root.get_node_or_null(String(node_name))
	return node as Object
