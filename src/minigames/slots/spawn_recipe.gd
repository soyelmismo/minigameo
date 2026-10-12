class_name SpawnRecipe
extends Resource
## WHAT appears in the arena and how it behaves (scaffold.md §7.3.1).
##
## Interpreted by the archetypes according to the table in §8.3. A new micro-game
## with spawns already covered is one `.tres` — zero code.

@export var entity_scene: PackedScene = null  # prop of the micro-game (token, GPU...)
@export var count: int = 12
@export var count_scales_with_difficulty: bool = true
@export var spawn_radius: float = 18.0        # metres around the player
@export var spawn_pattern: StringName = &"SCATTER"  # SCATTER | RING | GRID | LINE | WAVE
@export var motion: StringName = &"STATIC"    # STATIC | ORBIT | FLEE | CHASE | FALL
@export var speed: float = 4.0
@export var lifetime_s: float = -1.0          # -1 = until it is picked up / hit
@export var respawn: bool = false             # respawn after being picked up
@export var pool_group: StringName = &"mg_entity"
## Presentation of a spawned entity (§1.3 data, not code): the ONE generic
## `minigame_entity.tscn` reads these so a `.tres` decides how its pickup looks
## without a second scene or a per-microgame script (AGENTS.md §1.8).
@export var entity_size: float = 0.6
@export var entity_tint: Color = Color(0.35, 0.85, 1.0)
## Shape of the entity: SPHERE | BOX | DIAMOND | RING (MinigameEntity.Shape).
@export var entity_shape: StringName = &"SPHERE"


## Recuento efectivo tras aplicar la curva de dificultad del contexto.
## Difficulty 0..1 scales the count up to +50% when declared that way.
func resolve_count(difficulty: float) -> int:
	if not count_scales_with_difficulty:
		return maxi(1, count)
	var scaled: int = int(round(count * (1.0 + clampf(difficulty, 0.0, 1.0) * 0.5)))
	return maxi(1, scaled)
