extends Label3D
## ScorePopup — world-space floating score text (scaffold §6.3).
##
## Pooled-friendly: arm(points, world_pos) shows a rise + fade, then hides
## itself. The pooler (ObjectPool) reuses instances; this node never
## queue_frees itself in hot paths (AGENTS.md §1.4).
##
## NOTE: the show-method cannot be called `show()`: Label3D inherits
## Node3D.show(), and overriding a native method is a parse error under this
## project's warnings-as-errors policy. The public entry point is `arm()`.

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
func arm(points: int, world_pos: Vector3) -> void:
	text = "+%d" % points
	_origin = world_pos + Vector3(0, RISE_HEIGHT * 0.55, 0)
	position = _origin
	_life = LIFETIME
	visible = true
	modulate.a = 1.0
	scale = Vector3.ONE * 0.6


## Drive the rise/fade animation with an explicit delta (pool-safe).
func advance(delta: float) -> void:
	if _life <= 0.0:
		return
	_life -= delta
	if _life <= 0.0:
		visible = false
		return
	var t: float = 1.0 - _life / LIFETIME
	position = _origin + Vector3(0, RISE_HEIGHT * t, 0)
	scale = Vector3.ONE * (0.6 + 0.5 * t)
	modulate.a = 1.0 - t


## True once the popup has finished its rise and is invisible again, so the
## pool can hand the instance straight back out without a timer.
func is_finished() -> bool:
	return _life <= 0.0


## Reset to the inert state a pooled instance must start in.
func reset() -> void:
	_life = 0.0
	_origin = Vector3.ZERO
	text = ""
	visible = false
	modulate.a = 1.0
	scale = Vector3.ONE
