class_name StylePostFX
extends Resource
## StylePostFX — post-processing profile for a StylePack (scaffold §7.5).
##
## The PostFXDirector lerps between profiles so style changes never pop.
## Every value here is arcade-legible: bloom, chroma, vignette, scanlines,
## saturation.

@export var bloom_intensity: float = 0.4
@export var chromatic: float = 0.0        # 0..1 RGB split amount
@export var vignette: float = 0.25        # 0..1 dark corners
@export var scanline: float = 0.0         # 0..1 CRT lines
@export var saturation: float = 1.0       # 0 = greyscale, 1 = normal
@export var desaturate: float = 0.0       # hitstop/impact desaturation
@export var glow_strength: float = 1.0    # multiplier on Godot glow
@export var glow_bloom: float = 0.15      # 0..1 haziness


## Lerp between two profiles. t in 0..1.
func lerp_to(other: StylePostFX, t: float) -> StylePostFX:
	var out := StylePostFX.new()
	var k: float = clampf(t, 0.0, 1.0)
	out.bloom_intensity = lerpf(bloom_intensity, other.bloom_intensity, k)
	out.chromatic = lerpf(chromatic, other.chromatic, k)
	out.vignette = lerpf(vignette, other.vignette, k)
	out.scanline = lerpf(scanline, other.scanline, k)
	out.saturation = lerpf(saturation, other.saturation, k)
	out.desaturate = lerpf(desaturate, other.desaturate, k)
	out.glow_strength = lerpf(glow_strength, other.glow_strength, k)
	out.glow_bloom = lerpf(glow_bloom, other.glow_bloom, k)
	return out
