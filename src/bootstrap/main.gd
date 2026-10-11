extends Node
## Main scene. Bootstraps the match flow:
## BOOT -> TITLE -> COUNTDOWN -> FREE_ROAM -> ... (scaffold.md §5).
## The MatchManager owns the state machine; this scene only hosts the
## 3D viewport (world), the UI layer and the CameraDirector rig.

@onready var world: Node3D = $World
@onready var ui: CanvasLayer = $UI

func _ready() -> void:
	# Systems register themselves in GameServices at autoload time.
	# This scene just guarantees the layers exist for them.
	assert(world != null, "World layer missing in main.tscn")
	assert(ui != null, "UI layer missing in main.tscn")
