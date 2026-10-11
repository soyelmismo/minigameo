extends Node
## StyleDirector — applies StylePacks to the world (scaffold §6.4, §9).
##
## A micro-game's style pack temporarily transforms the look: sky, fog,
## lighting, materials (SHADER_UNIFORM by default), postfx, FOV, HUD theme.
## Smoothly blends in over `transition_s`, auto-reverts to the base look
## when the micro-game ends. Degrades gracefully headless.

const PACK_DIR := "res://src/styles/packs/"

var _base_environment: Dictionary = {}
var _current: StylePack = null
var _applying: bool = false
var _blend_t: float = 1.0
var _blend_speed: float = 1.0
var _from_env: Dictionary = {}
var _to_env: Dictionary = {}


func _ready() -> void:
	var locator: Object = GameServices.lookup(&"core")
	if locator != null and locator.has_method("register"):
		locator.register(&"style", self)
	_capture_base()


func _capture_base() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		return
	var env_node := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	var e := env_node.environment
	_base_environment = {
		"glow_intensity": e.glow_intensity,
		"glow_strength": e.glow_strength,
		"glow_bloom": e.glow_bloom,
		"saturation": e.adjustment_saturation if e.adjustment_enabled else 1.0,
	}


# --- Public API --------------------------------------------------------------

## Apply a style pack by id (loads from PACK_DIR). Empty id = base look.
func apply_pack_id(pack_id: StringName) -> void:
	if pack_id == &"":
		revert_to_base()
		return
	var pack := load(PACK_DIR + String(pack_id).to_lower() + ".tres") as StylePack
	if pack == null:
		push_warning("StyleDirector: pack '%s' not found" % pack_id)
		return
	apply_pack(pack)


## Apply a StylePack resource with a smooth blend.
func apply_pack(pack: StylePack) -> void:
	if pack == null:
		return
	_from_env = _snapshot_env()
	_to_env = _env_dict_for(pack)
	_blend_t = 0.0
	_blend_speed = 1.0 / maxf(pack.transition_s, 0.01)
	_current = pack
	_applying = true
	_apply_shader_uniforms(pack)
	EventBus.emit(&"style_applied", pack.id)


## Revert to the captured base look.
func revert_to_base() -> void:
	_to_env = _base_environment.duplicate()
	_from_env = _snapshot_env()
	_blend_t = 0.0
	_blend_speed = 1.0 / 0.4
	_current = null
	_applying = false
	EventBus.emit(&"style_reverted")


func current_pack() -> StylePack:
	return _current


func is_styled() -> bool:
	return _applying


# --- Internals --------------------------------------------------------------

func _snapshot_env() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var scene: Node = tree.current_scene
	if scene == null:
		return {}
	var env_node := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return {}
	var e := env_node.environment
	return {
		"glow_intensity": e.glow_intensity,
		"glow_strength": e.glow_strength,
		"glow_bloom": e.glow_bloom,
		"saturation": e.adjustment_saturation if e.adjustment_enabled else 1.0,
	}


func _env_dict_for(pack: StylePack) -> Dictionary:
	var d := _base_environment.duplicate()
	if pack.postfx != null:
		d["glow_intensity"] = pack.postfx.bloom_intensity
		d["glow_strength"] = pack.postfx.glow_strength
		d["glow_bloom"] = pack.postfx.glow_bloom
		d["saturation"] = pack.postfx.saturation
	return d


## SHADER_UNIFORM strategy: set global shader params the world shader reads.
func _apply_shader_uniforms(pack: StylePack) -> void:
	if pack.material_mode != &"SHADER_UNIFORM":
		return
	for key: StringName in pack.style_uniforms:
		RenderingServer.global_shader_parameter_set(
			String(key), pack.style_uniforms[key]
		)


## Clear the global style uniforms (revert path).
func _clear_shader_uniforms() -> void:
	for uniform_name in ["u_style_top", "u_style_fog", "u_style_saturation", "u_style_scanline"]:
		RenderingServer.global_shader_parameter_set(uniform_name, null)


func _blend_step(delta: float) -> void:
	if _blend_t >= 1.0:
		return
	_blend_t = minf(_blend_t + _blend_speed * delta, 1.0)
	var k: float = _blend_t
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var env_node := tree.current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	var e := env_node.environment
	for key: StringName in _to_env:
		var a: float = float(_from_env.get(key, 0.0))
		var b: float = float(_to_env.get(key, 0.0))
		var v: float = lerpf(a, b, k)
		match key:
			&"glow_intensity": e.glow_intensity = v
			&"glow_strength": e.glow_strength = v
			&"glow_bloom": e.glow_bloom = v
			&"saturation":
				if e.adjustment_enabled:
					e.adjustment_saturation = v


func _process(delta: float) -> void:
	_blend_step(delta)
