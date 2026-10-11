class_name ArchetypeZoneHold
extends MinigameArchetype
## Arquetipo 6 — ZONE_HOLD (scaffold.md §8.1 fila 6, §8.3 fila 6).
##
## Slots leídos:
##   SpawnRecipe    → 1 zona (no entidades); spawn_radius = radio de la zona
##   ObjectiveRecipe→ kind HOLD_ZONE_T, target = segundos acumulados en zona
##   HUDRecipe      → TIMER
##   InputMode      → RUN
##
## Mecánica: acumular `target` segundos dentro del radio de la zona. El
## temporizador solo avanza mientras el jugador esté dentro; salir lo pausa
## (no lo resetea, para no castigar el micro-desplazamiento).

const KIND_HOLD_ZONE_T := &"HOLD_ZONE_T"
const DEFAULT_ZONE_RADIUS := 6.0

var _accumulated: float = 0.0
var _target_s: float = 8.0
var _time_bonus_per_s: int = 100
var _zone_radius: float = DEFAULT_ZONE_RADIUS
var _in_zone: bool = false
var _zone_marker: Node3D = null


func setup(ctx: MinigameContext) -> void:
	super.setup(ctx)
	_accumulated = 0.0
	_in_zone = false
	if _meta != null and _meta.objective_recipe != null:
		_target_s = float(_meta.objective_recipe.target)
		_time_bonus_per_s = _meta.objective_recipe.time_bonus_per_s
	if _meta != null and _meta.spawn_recipe != null:
		_zone_radius = _meta.spawn_recipe.spawn_radius


func start() -> void:
	super.start()
	_spawn_zone()


## La zona es un marcador visual (Area3D cuando hay escena, si no un Node3D).
func _spawn_zone() -> void:
	var ctx := get_context()
	if ctx == null:
		return
	var marker := Node3D.new()
	marker.name = "ZoneMarker"
	marker.position = ctx.arena_center
	marker.add_to_group(&"mg_zone")
	if ctx.world_root != null:
		ctx.world_root.add_child(marker)
		_spawned.append(marker)
		_zone_marker = marker


func advance(delta: float) -> void:
	var ctx := get_context()
	if ctx == null or ctx.player == null or not is_instance_valid(ctx.player):
		return
	var player_pos: Vector3 = (ctx.player as Node3D).global_position
	var zone_pos: Vector3 = _zone_marker.global_position if _zone_marker != null else ctx.arena_center
	var dist: float = player_pos.distance_to(zone_pos)
	var was_in: bool = _in_zone
	_in_zone = dist <= _zone_radius
	if _in_zone:
		_accumulated += delta
		set_progress(_accumulated / maxf(0.001, _target_s))
		emit_event(&"zone_hold", {"accumulated": _accumulated, "target": _target_s})
		if _accumulated >= _target_s:
			finish_success(_time_bonus_per_s)
			return
	if _in_zone != was_in:
		emit_event(&"zone_edge", {"in_zone": _in_zone})


func teardown() -> void:
	super.teardown()
	_accumulated = 0.0
	_zone_marker = null
	_in_zone = false


func get_accumulated() -> float:
	return _accumulated


func is_in_zone() -> bool:
	return _in_zone
