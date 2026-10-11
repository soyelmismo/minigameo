class_name SpawnRecipe
extends Resource
## QUÉ aparece en la arena y cómo se comporta (scaffold.md §7.3.1).
##
## Interpretado por los arquetipos según la tabla §8.3. Un micro-juego nuevo
## con spawns ya cubiertos es un `.tres` — cero código.

@export var entity_scene: PackedScene = null  # prop del micro-juego (token, GPU...)
@export var count: int = 12
@export var count_scales_with_difficulty: bool = true
@export var spawn_radius: float = 18.0        # metros alrededor del jugador
@export var spawn_pattern: StringName = &"SCATTER"  # SCATTER | RING | GRID | LINE | WAVE
@export var motion: StringName = &"STATIC"    # STATIC | ORBIT | FLEE | CHASE | FALL
@export var speed: float = 4.0
@export var lifetime_s: float = -1.0          # -1 = hasta recogerse/impactar
@export var respawn: bool = false             # reaparición tras recogerse
@export var pool_group: StringName = &"mg_entity"


## Recuento efectivo tras aplicar la curva de dificultad del contexto.
## La dificultad 0..1 escala el conteo hasta +50% cuando así se declara.
func resolve_count(difficulty: float) -> int:
	if not count_scales_with_difficulty:
		return maxi(1, count)
	var scaled: int = int(round(count * (1.0 + clampf(difficulty, 0.0, 1.0) * 0.5)))
	return maxi(1, scaled)
