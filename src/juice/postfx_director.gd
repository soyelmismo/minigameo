extends Node
## PostFXDirector — fullscreen post overlays + glow/saturation blending
## (scaffold §6.7, graphics brief "Postprocessing").
##
## Owns the OVERLAY stack (flash / vignette / chromatic / scanlines /
## desaturate) drawn by the ScreenEffects layer, and mirrors the glow and
## saturation of the active StylePostFX profile into the WorldEnvironment.
##
## Profiles are pure data: StylePostFX resources inside the style packs, with
## the base profile captured from the live WorldEnvironment at boot — so a
## revert lands exactly on assets/shaders/base_env.tres and every number
## stays in the .tres, never in code (§1.3).
##
## The director listens to EventBus style_applied/style_reverted, which is
## how a style pack's vignette/scanline/chroma actually reach the screen
## (the values existed in the packs but nothing consumed them before).
##
## Degrades gracefully headless: no environment, no EventBus, no
## screen-effects node → every call is a no-op, never a crash.

## Fallback blend when a pack carries no transition_s (seconds).
const PROFILE_SETTLE := 0.4

var _env: WorldEnvironment = null
var _base_profile: StylePostFX = null
var _current: StylePostFX = null
var _target: StylePostFX = null
var _blend_t: float = 1.0
var _blend_speed: float = 1.0

# Fullscreen overlay state (read by the screen_effects nodes).
var _overlay_flash: float = 0.0
var _overlay_chromatic: float = 0.0
var _overlay_vignette: float = 0.25
var _overlay_scanline: float = 0.0
var _overlay_desaturate: float = 0.0

# Impulse amounts set explicitly by gameplay (impacts, micro-games). They
# add to the profile values so an explicit call is never smoothed away.
var _impulse_chromatic: float = 0.0
var _impulse_vignette: float = 0.0
var _impulse_scanline: float = 0.0

var _flash_color: Color = Color.WHITE
var _flash_left: float = 0.0
var _flash_dur: float = 0.2


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"postfx") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("PostFXDirector", &"postfx", self)
	_find_env()
	# Base profile = whatever base_env.tres actually contains (captured, not
	# hardcoded), so reverting a style restores the authored base look.
	_base_profile = _capture_profile_from_env()
	_current = _base_profile
	_target = _base_profile
	_overlay_vignette = _current.vignette
	_connect_bus()


func _find_env() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		return
	_env = scene.find_child("WorldEnvironment", true, false) as WorldEnvironment


## Snapshot the authored base look from the live environment.
func _capture_profile_from_env() -> StylePostFX:
	var p := StylePostFX.new()
	if _env != null and _env.environment != null:
		var e := _env.environment
		p.bloom_intensity = e.glow_intensity
		p.glow_strength = e.glow_strength
		p.glow_bloom = e.glow_bloom
		p.saturation = e.adjustment_saturation if e.adjustment_enabled else 1.0
	return p


# --- EventBus wiring: style packs drive the overlays ----------

func _connect_bus() -> void:
	var bus := _autoload(&"EventBus")
	if bus == null or not bus.has_signal("style_applied"):
		return
	bus.style_applied.connect(_on_style_applied)
	bus.style_reverted.connect(_on_style_reverted)


func _autoload(node_name: StringName) -> Object:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null(String(node_name)) as Object


## A pack is live: blend the overlay stack to its postfx profile.
func _on_style_applied(_pack_id: StringName) -> void:
	var style := _autoload(&"StyleDirector")
	if style == null or not style.has_method("current_pack"):
		return
	var pack: StylePack = style.current_pack() as StylePack
	if pack == null or pack.postfx == null:
		return
	set_profile(pack.postfx, pack.transition_s)


## Style over: back to the captured base profile.
func _on_style_reverted() -> void:
	set_profile(_base_profile, PROFILE_SETTLE)


# --- Public API ----------

## Set the active postfx profile; the director lerps to it over `duration`.
func set_profile(profile: StylePostFX, duration: float = 0.4) -> void:
	if profile == null:
		profile = _base_profile
	_target = profile
	_blend_t = 0.0
	_blend_speed = 1.0 / maxf(duration, 0.01)


## Flash the screen (color + alpha) for `duration` seconds.
func flash(color: Color, alpha: float, duration: float = 0.2) -> void:
	# Accessibility (§8): flashes can be switched off entirely; the game keeps
	# every other impact cue (shake, hitstop, audio, HUD) when they are.
	if not _flashes_enabled():
		return
	_overlay_flash = alpha
	_flash_color = color
	_flash_left = duration
	_flash_dur = maxf(duration, 0.01)


## True unless SettingsManager says flashes are disabled.
func _flashes_enabled() -> bool:
	var settings: Object = GameServices.lookup(&"settings")
	if settings != null and settings.has_method("flashes_enabled"):
		return bool(settings.flashes_enabled())
	return true


## Set a persistent chromatic amount (style packs, impacts).
func set_chromatic(amount: float) -> void:
	_impulse_chromatic = clampf(amount, 0.0, 1.0)


## Set a persistent vignette amount.
func set_vignette(amount: float) -> void:
	_impulse_vignette = clampf(amount, 0.0, 1.0)


## Set a persistent scanline amount.
func set_scanline(amount: float) -> void:
	_impulse_scanline = clampf(amount, 0.0, 1.0)


## Drive the blend + overlays with an explicit delta (testable).
func advance(delta: float) -> void:
	if _blend_t < 1.0:
		_blend_t = minf(_blend_t + _blend_speed * delta, 1.0)
		_current = _current.lerp_to(_target, _blend_speed * delta)
	# Overlays ease toward the profile so a style change never pops.
	var k: float = clampf(_blend_speed * delta * 2.0, 0.0, 1.0)
	_overlay_vignette = lerpf(_overlay_vignette, _current.vignette, k)
	_overlay_chromatic = lerpf(_overlay_chromatic, _current.chromatic, k)
	_overlay_scanline = lerpf(_overlay_scanline, _current.scanline, k)
	_overlay_desaturate = lerpf(_overlay_desaturate, _current.desaturate, k)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_overlay_flash = 0.0
	_apply_to_environment()


func _apply_to_environment() -> void:
	if _env == null or _env.environment == null or _current == null:
		return
	var e := _env.environment
	e.glow_intensity = _current.bloom_intensity
	e.glow_strength = _current.glow_strength
	e.glow_bloom = _current.glow_bloom
	if e.adjustment_enabled:
		e.adjustment_saturation = _current.saturation


## The overlay parameters for the fullscreen effect nodes to read. Profile
## values plus explicit impulses, clamped to the valid range.
func overlay_state() -> Dictionary:
	return {
		"flash": _overlay_flash,
		"flash_color": _flash_color,
		"chromatic": clampf(_overlay_chromatic + _impulse_chromatic, 0.0, 1.0),
		"vignette": clampf(_overlay_vignette + _impulse_vignette, 0.0, 1.0),
		"scanline": clampf(_overlay_scanline + _impulse_scanline, 0.0, 1.0),
		"desaturate": clampf(_overlay_desaturate, 0.0, 1.0),
	}


func _process(delta: float) -> void:
	advance(delta)
