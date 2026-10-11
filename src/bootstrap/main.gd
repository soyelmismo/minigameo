extends Node
## Main scene — bootstraps the match flow (scaffold §5).
##
## BOOT -> TITLE -> COUNTDOWN -> FREE_ROAM -> ... is owned by the
## MatchManager autoload. This scene only composes the layers:
##   World    (Node3D)      — CityBlock + Player + camera rig
##   HUD      (CanvasLayer) — auto-generated objective HUD (§13.1)
##   Effects  (CanvasLayer) — flash overlay, topmost layer (§6.7)
## and publishes the player in GameServices so every other system resolves
## it duck-typed (AGENTS.md §1.1: no direct references to other autoloads).

## Avatar spawn placement. Lives in data, never as a magic number buried in
## logic (AGENTS.md §1.3). The scene transform mirrors this default; the
## export is the single tunable source.
@export var player_spawn_position: Vector3 = Vector3(0.0, 1.0, 0.0)

@onready var world: Node3D = $World
@onready var player: Node3D = $World/Player
@onready var hud: CanvasLayer = $HUD
@onready var effects: CanvasLayer = $Effects


func _ready() -> void:
	_place_player()
	_register_player()
	assert(world != null, "World layer missing in main.tscn")
	assert(player != null, "Player layer missing in main.tscn")
	assert(hud != null, "HUD layer missing in main.tscn")
	assert(effects != null, "Effects layer missing in main.tscn")
	# No gameplay here: systems are autoloads resolved through
	# GameServices/EventBus, never referenced from this scene (§1.1).


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
