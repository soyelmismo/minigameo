class_name PostFXDirector
extends Node
## PostFXDirector — WorldEnvironment + fullscreen effects (scaffold §6.7).
##
## Manages the WorldEnvironment (glow, color, fog, tonemap) per StylePostFX
## with smooth lerping between profiles, and draws fullscreen flash/vignette/
## chromatic/scanline overlays. Degrades gracefully headless.

var _env: WorldEnvironment = null
var _base_profile: StylePostFX = null
var _current: StylePostFX = null
var _target: StylePostFX = null
var _blend_t: float = 1.0
var _blend_speed: float = 1.0

# Fullscreen overlay state (drawn by the screen_effects nodes).
var _overlay_flash: float = 0.0
var _overlay_chromatic: float = 0.0
var _overlay_vignette: float = 0.25


func _ready() -> void:
	_find_env()
	_base_profile = _default_profile()
	_current = _base_profile
	_target = _base_profile
	var locator: Object = GameServices.lookup(&"core")
	if locator != null and locator.has_method("register"):
		locator.register(&"postfx", self)


func _find_env() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		return
	_env = scene.find_child("WorldEnvironment", true, false) as WorldEnvironment


func _default_profile() -> StylePostFX:
	var p := StylePostFX.new()
	p.bloom_intensity = 0.4
	p.glow_strength = 1.0
	p.glow_bloom = 0.15
	p.saturation = 1.0
	p.vignette = 0.25
	return p


## Set the active postfx profile; the director lerps to it over `duration`.
func set_profile(profile: StylePostFX, duration: float = 0.4) -> void:
	if profile == null:
		profile = _base_profile
	_target = profile
	_blend_t = 0.0
	_blend_speed = 1.0 / maxf(duration, 0.01)


## Flash the screen (color + alpha) for `duration` seconds.
func flash(color: Color, alpha: float, duration: float = 0.2) -> void:
	_overlay_flash = alpha
	_flash_color = color
	_flash_left = duration
	_flash_dur = maxf(duration, 0.01)


var _flash_color: Color = Color.WHITE
var _flash_left: float = 0.0
var _flash_dur: float = 0.2


## Drive the blend + overlays with an explicit delta (testable).
func advance(delta: float) -> void:
	if _blend_t < 1.0:
		_blend_t = minf(_blend_t + _blend_speed * delta, 1.0)
		_current = _current.lerp_to(_target, _blend_speed * delta)
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


## The overlay parameters for the fullscreen effect nodes to read.
func overlay_state() -> Dictionary:
	return {
		"flash": _overlay_flash,
		"flash_color": _flash_color,
		"chromatic": _overlay_chromatic,
		"vignette": _overlay_vignette,
	}


## Set persistent chromatic amount (style packs, impacts).
func set_chromatic(amount: float) -> void:
	_overlay_chromatic = clampf(amount, 0.0, 1.0)


func set_vignette(amount: float) -> void:
	_overlay_vignette = clampf(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	advance(delta)
