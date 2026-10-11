extends Node
## Main scene. Bootstraps the match flow:
## BOOT -> TITLE -> COUNTDOWN -> FREE_ROAM -> ... (scaffold.md §5).
## The MatchManager owns the state machine; this scene only hosts the
## 3D world, the player, the HUD and the screen-effects overlay.

@onready var world: Node3D = $World
@onready var player: Node3D = $World/Player
@onready var hud: CanvasLayer = $HUD
@onready var effects: CanvasLayer = $ScreenEffects


func _ready() -> void:
	# Systems register themselves in GameServices at autoload time.
	# This scene guarantees the layers exist for them.
	assert(world != null, "World layer missing in main.tscn")
	assert(player != null, "Player missing in main.tscn")
	assert(hud != null, "HUD layer missing in main.tscn")
	assert(effects != null, "ScreenEffects layer missing in main.tscn")
	# The player self-registers in GameServices as &"player"; the camera
	# rig is driven by CameraDirector (autoload). Nothing else to wire:
	# every system is an autoload resolved by path (§1.1).
