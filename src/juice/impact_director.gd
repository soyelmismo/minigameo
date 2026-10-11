extends Node
## ImpactDirector — the single juice API (scaffold §6.5, §10.1).
##
## Gameplay NEVER inserts hitstop/shake/flash directly. It calls
## impact(weight) or impact_frame(preset) and this director executes the
## whole package: hitstop (Engine.time_scale), camera shake, FOV punch,
## flash, chromatic pulse, desaturate. All numbers come from presets.

const WEIGHT_LIGHT := 0
const WEIGHT_MEDIUM := 1
const WEIGHT_HEAVY := 2
const WEIGHT_CRITICAL := 3

const PRESET_DIR := "res://src/juice/presets/"

var _active: ImpactFrame = null
var _hitstop_left: float = 0.0
var _flash_left: float = 0.0
var _flash_peak: float = 0.0
var _flash_color: Color = Color.WHITE
var _time_scale_restore: float = 1.0
var _restore_left: float = 0.0
## Wall-clock deadline of the active hitstop. Engine.time_scale is GLOBAL
## state: if the driving GameLoop is paused (pause menu, a test freezing the
## driver, a teardown), an advance() call may never come back. The director
## therefore owns its own deadline and always returns the world to normal.
var _hitstop_deadline_msec: int = 0


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"impact") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("ImpactDirector", &"impact", self)
	# The restore must survive a paused driver (pause menu, tests freezing the
	# GameLoop); gameplay stays paused, only the juice clock self-completes.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and _hitstop_left > 0.0:
		# Teardown hygiene (§1.4): never leave the world in slow motion.
		_restore_time_scale()


func _process(_delta: float) -> void:
	# Safety net: restore the world even if nothing called advance() in time.
	if _hitstop_left > 0.0 and Time.get_ticks_msec() >= _hitstop_deadline_msec:
		_restore_time_scale()


# --- Public API --------------------------------------------------------------

## Fire an impact by canonical weight. Resolves the matching .tres preset.
func impact(weight: int) -> void:
	var preset := load(PRESET_DIR + _preset_name(weight) + ".tres") as ImpactFrame
	if preset == null:
		preset = ImpactFrame.preset(weight)
	impact_frame(preset)


## Fire a fully-specified impact preset.
func impact_frame(frame: ImpactFrame) -> void:
	if frame == null:
		return
	_active = frame
	# Hitstop: freeze the world briefly.
	_hitstop_left = frame.hitstop_s
	_time_scale_restore = Engine.time_scale
	Engine.time_scale = maxf(frame.time_scale, 0.01)
	_restore_left = frame.hitstop_s
	# A grace window so a slow normal advance() is not preempted by the
	# wall-clock net, while a stalled driver still recovers.
	_hitstop_deadline_msec = Time.get_ticks_msec() + int(frame.hitstop_s * 500.0)
	# Camera shake + FOV punch.
	var cam: Object = GameServices.lookup(&"camera")
	if cam is CameraDirector:
		var c := cam as CameraDirector
		c.shake(frame.shake_amplitude, frame.shake_frequency, frame.shake_duration_s)
		c.fov_punch(frame.fov_punch, frame.shake_duration_s * 0.5)
	# Flash.
	_flash_left = frame.shake_duration_s
	_flash_peak = frame.flash_alpha
	_flash_color = frame.flash_color
	# Audio layer.
	var audio: Object = GameServices.lookup(&"sfx")
	if audio != null and audio.has_method("play_impact") and frame.impact_sfx != null:
		audio.play_impact(frame.impact_sfx)
	# NOTE: `impact_requested` used to be emitted here after the impact had
	# already been executed, which made it a dead event (nothing subscribes to
	# it) and, worse, an inverted one: the signal looked like a REQUEST that
	# this very director was supposed to answer, so the natural wiring —
	# gameplay emits, juice listens — would have re-entered this function.
	# Gameplay calls impact()/impact_frame() directly (§6.5); the bus stays for
	# the events that are genuinely observed (style_applied, score_changed...).


func _preset_name(weight: int) -> String:
	match weight:
		WEIGHT_LIGHT: return "impact_light"
		WEIGHT_MEDIUM: return "impact_medium"
		WEIGHT_HEAVY: return "impact_heavy"
		WEIGHT_CRITICAL: return "impact_critical"
	return "impact_medium"


# --- Frame ------------------------------------------------------------------

## Restore time scale after hitstop and decay the flash.
func advance(delta: float) -> void:
	if _restore_left > 0.0:
		_restore_left -= delta
		if _restore_left <= 0.0:
			_restore_time_scale()
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_peak = 0.0


## Returns Engine.time_scale to its pre-hitstop value and clears the state.
## Idempotent: safe to call from advance(), from the wall-clock safety net in
## _process() and from teardown, whichever happens first.
func _restore_time_scale() -> void:
	if _hitstop_left <= 0.0 and _restore_left <= 0.0:
		return
	_hitstop_left = 0.0
	_restore_left = 0.0
	_hitstop_deadline_msec = 0
	Engine.time_scale = _time_scale_restore
	_active = null


## Current flash alpha for the PostFXDirector to draw (0..1).
func current_flash() -> Dictionary:
	return {"color": _flash_color, "alpha": _flash_peak}


## True while the world is frozen (hitstop active).
func in_hitstop() -> bool:
	return _hitstop_left > 0.0
