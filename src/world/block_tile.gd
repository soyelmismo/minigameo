extends Node3D
## BlockTile — one reusable piece of the city block (scaffold §11).
##
## Sidewalk + road + curb with distinct materials. city_block.tscn tiles
## several of these into the playable 120m x 120m block. Greyblock quality
## that still reads intentionally: clear material separation, lane markings.

@export var tile_size: float = 40.0
@export var sidewalk_height: float = 0.15


func _ready() -> void:
	pass
