class_name ImpactFrame
extends Resource
## ImpactFrame — a preset for one impact event (scaffold §7.6, §10.1).
##
## The ImpactDirector reads a preset per event weight. ALL juice numbers
## live here as data; gameplay code only says "impact(weight)".
##
## Weights (scaffold §10.1):
##   LIGHT   - combo step          MEDIUM - minigame hit
##   HEAVY   - powerup / fail      CRITICAL - roulette result / match end

@export var hitstop_s: float = 0.06          # 40..120ms typical
@export var time_scale: float = 0.05         # time_scale during hitstop
@export var shake_amplitude: float = 0.3     # trauma 0..1
@export var shake_frequency: float = 24.0
@export var shake_duration_s: float = 0.4
@export var fov_punch: float = -6.0          # degrees (negative = punch in)
@export var chromatic_pulse: float = 0.5
@export var flash_color: Color = Color.WHITE
@export var flash_alpha: float = 0.3
@export var desaturate: float = 0.3
@export var impact_sfx: AudioStream = null


## Factory for the four canonical weights (scaffold §10.1 event table).
static func preset(weight: int) -> ImpactFrame:
	match weight:
		ImpactDirector.WEIGHT_LIGHT:
			var f := ImpactFrame.new()
			f.hitstop_s = 0.04
			f.shake_amplitude = 0.15
			f.fov_punch = -3.0
			f.flash_alpha = 0.0
			f.desaturate = 0.1
			return f
		ImpactDirector.WEIGHT_MEDIUM:
			var f := ImpactFrame.new()
			f.hitstop_s = 0.06
			f.shake_amplitude = 0.25
			f.fov_punch = -5.0
			f.flash_alpha = 0.2
			f.desaturate = 0.2
			return f
		ImpactDirector.WEIGHT_HEAVY:
			var f := ImpactFrame.new()
			f.hitstop_s = 0.09
			f.shake_amplitude = 0.35
			f.fov_punch = -8.0
			f.flash_alpha = 0.3
			f.desaturate = 0.3
			return f
		ImpactDirector.WEIGHT_CRITICAL:
			var f := ImpactFrame.new()
			f.hitstop_s = 0.12
			f.shake_amplitude = 0.5
			f.fov_punch = -10.0
			f.flash_alpha = 0.4
			f.desaturate = 0.4
			f.chromatic_pulse = 0.8
			return f
	return preset(ImpactDirector.WEIGHT_MEDIUM)
