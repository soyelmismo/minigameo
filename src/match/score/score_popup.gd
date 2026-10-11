extends Label3D
## ScorePopup — world-space floating score text (scaffold §6.3).
##
## Pooled-friendly: show(points, world_pos) animates a rise + fade, then
## hides itself. The pooler (ObjectPool) reuses instances; this node never
## queue_frees itself in hot paths (AGENTS.md §1.4).

const RISE_HEIGHT := 2.2
const LIFETIME := 0.9

var _life: float = 0.0
var _origin: Vector3 = Vector3.ZERO


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	pixel_size = 0.012
	outline_size = 8
	font_size = 72
	visible = false


## Arm the popup at a world position with a points value.
func show(points: int, world_pos: Vector3) -> void:
	text = "+%d" % points
	_origin = world_pos + Vector3(0, 1.2, 0)
	position = _origin
	_life = LIFETIME
	visible = true
	modulate.a = 1.0
	scale = Vector3.ONE * 0.6


## Drive the rise/fade animation with an explicit delta (pool-safe).
func animate(delta: float) -> void:
	if _life <= 0.0:
		return
	_life -= delta
	var t: float = 1.0 - clampf(_life / LIFETIME, 0.0, 1.0)
	position = _origin + Vector3(0, RISE_HEIGHT * t, 0)
	modulate.a = 1.0 - t
	scale = Vector3.ONE * (0.6 + 0.5 * t)
	if _life <= 0.0:
		visible = false
