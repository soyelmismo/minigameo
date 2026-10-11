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


func _ready() -> void:
	var locator: Object = GameServices.lookup(&"core")
	if locator != null and locator.has_method("register"):
		locator.register(&"impact", self)


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
	EventBus.emit(&"impact_requested", _weight_of(frame))


func _weight_of(frame: ImpactFrame) -> int:
	if frame == _loaded_presets.get(WEIGHT_CRITICAL, null):
		return WEIGHT_CRITICAL
	return WEIGHT_MEDIUM


var _loaded_presets: Dictionary = {}


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
			Engine.time_scale = _time_scale_restore
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_peak = 0.0


## Current flash alpha for the PostFXDirector to draw (0..1).
func current_flash() -> Dictionary:
	return {"color": _flash_color, "alpha": _flash_peak}


## True while the world is frozen (hitstop active).
func in_hitstop() -> bool:
	return _hitstop_left > 0.0
