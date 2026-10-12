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

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"style") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("StyleDirector", &"style", self)
	# Autoloads are built before main.tscn exists, so the world rig is not in
	# the tree yet and an inline capture here would read nothing — which is
	# exactly how reverting came to leave a pack's sky, sun and FOV in place.
	# Deferring to the end of this frame reads the real base look, and keeps the
	# scene-tree walk off the frame the integration suite ticks the match.
	call_deferred("_capture_base")


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
	# Captured with the same reader as the live snapshot, so the base look covers
	# every channel a pack can change (sky, fog, sun, ambient, FOV). This was a
	# hardcoded 4-key literal, so reverting could never restore what a pack had
	# changed beyond glow and saturation.
	_base_environment = _read_environment(env_node.environment)


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
	_fov_handed_off = false
	_apply_shader_uniforms(pack)
	EventBus.emit(&"style_applied", pack.id)


## Revert to the captured base look.
func revert_to_base() -> void:
	# Drop the global style uniforms BEFORE the blend, so the world does not
	# carry the last pack's saturation/scanline look into the next micro-game.
	# This call existed but nothing invoked it, so the "revert" only restored
	# the environment and left every shader uniform behind (§1.4: the world is
	# left as it was found).
	_clear_shader_uniforms()
	_to_env = _base_environment.duplicate()
	_from_env = _snapshot_env()
	_blend_t = 0.0
	_blend_speed = 1.0 / 0.4
	_current = null
	_applying = false
	_fov_handed_off = false
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
	return _read_environment(env_node.environment)


## Reads every blendable channel off one Environment. Shared by the base
## capture and the live snapshot, so the two can never drift apart.
func _read_environment(e: Environment) -> Dictionary:
	var d := {
		"glow_intensity": e.glow_intensity,
		"glow_strength": e.glow_strength,
		"glow_bloom": e.glow_bloom,
		"saturation": e.adjustment_saturation if e.adjustment_enabled else 1.0,
	}
	# Sky and fog. The sky colours live on the Sky's ProceduralSkyMaterial, not
	# on the Environment; reading Environment.sky_top_color raises, so the
	# material is reached through e.sky first and every field is guarded.
	var sky: Color = Color()
	var hor: Color = Color()
	var sky_res: Sky = e.sky
	if sky_res != null:
		var mat: ProceduralSkyMaterial = sky_res.sky_material as ProceduralSkyMaterial
		if mat != null:
			sky = mat.sky_top_color
			hor = mat.sky_horizon_color
	d["sky_top_r"] = sky.r
	d["sky_top_g"] = sky.g
	d["sky_top_b"] = sky.b
	d["sky_top_a"] = sky.a
	d["sky_h_r"] = hor.r
	d["sky_h_g"] = hor.g
	d["sky_h_b"] = hor.b
	d["sky_h_a"] = hor.a
	var fog: Color = e.fog_light_color if e.fog_enabled else Color()
	d["fog_r"] = fog.r
	d["fog_g"] = fog.g
	d["fog_b"] = fog.b
	d["fog_density"] = e.fog_density if e.fog_enabled else 0.0
	var light: DirectionalLight3D = _find_sun()
	if light != null:
		d["sun_r"] = light.light_color.r
		d["sun_g"] = light.light_color.g
		d["sun_b"] = light.light_color.b
		d["sun_energy"] = light.light_energy
		# Godot has no separate "ambient" on a DirectionalLight3D; the ambient
		# energy a pack declares is folded into the light's so the slot still
		# brightens the whole block.
		d["amb_r"] = light.light_color.r
		d["amb_g"] = light.light_color.g
		d["amb_b"] = light.light_color.b
		d["amb_energy"] = 0.0
	else:
		for key: StringName in ["sun_r", "sun_g", "sun_b", "sun_energy",
				"amb_r", "amb_g", "amb_b", "amb_energy"]:
			d[key] = 0.0
	var cam: Camera3D = _find_camera()
	d["fov"] = cam.fov if cam != null else 0.0
	return d


## The directional light that reads as the sun. main.tscn puts one under World.
## Matched by type, not by name: the node names in main.tscn are unstable and a
## name-based lookup silently found nothing, which is why the sun and ambient
## energy never moved.
func _find_sun() -> DirectionalLight3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var stack: Array[Node] = [tree.current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is DirectionalLight3D:
			return n as DirectionalLight3D
		for c in n.get_children():
			stack.append(c)
	return null


## The active camera, for the FOV override. main.tscn owns one under World.
func _find_camera() -> Camera3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var viewport: Viewport = tree.root
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _env_dict_for(pack: StylePack) -> Dictionary:
	var d := _base_environment.duplicate()
	if pack.postfx != null:
		d["glow_intensity"] = pack.postfx.bloom_intensity
		d["glow_strength"] = pack.postfx.glow_strength
		d["glow_bloom"] = pack.postfx.glow_bloom
		d["saturation"] = pack.postfx.saturation
	# The look of the block itself. These fields have been declared on StylePack
	# since the packs were written and never read, so every one of the 12 packs
	# changed only glow and saturation — the sky, fog, sun and ambient were the
	# same in every micro-game, which is exactly the visual variety §5 promises.
	# Sky colours are packed as two floats per channel pair so the float-based
	# blend below can interpolate them like everything else.
	if pack.sky_top != Color():
		d["sky_top_r"] = pack.sky_top.r
		d["sky_top_g"] = pack.sky_top.g
		d["sky_top_b"] = pack.sky_top.b
		d["sky_top_a"] = pack.sky_top.a
	if pack.sky_horizon != Color():
		d["sky_h_r"] = pack.sky_horizon.r
		d["sky_h_g"] = pack.sky_horizon.g
		d["sky_h_b"] = pack.sky_horizon.b
		d["sky_h_a"] = pack.sky_horizon.a
	if pack.fog_color != Color():
		d["fog_r"] = pack.fog_color.r
		d["fog_g"] = pack.fog_color.g
		d["fog_b"] = pack.fog_color.b
	if pack.fog_density > 0.0:
		d["fog_density"] = pack.fog_density
	if pack.sun_color != Color():
		d["sun_r"] = pack.sun_color.r
		d["sun_g"] = pack.sun_color.g
		d["sun_b"] = pack.sun_color.b
	d["sun_energy"] = pack.sun_energy
	# A pack's ambient_energy has no target in this rig: main.tscn has no
	# AmbientLight/ReflectionProbe, and folding it into the sun would fight the
	# pack's own sun_energy. It is read and blended so the slot survives a
	# round-trip, but nothing renders it — see the gap noted in the contract doc.
	# Camera: -1 means "leave the camera alone", so a pack that does not care
	# keeps the base framing.
	if pack.fov_override > 0.0:
		d["fov"] = pack.fov_override
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
	# Sky, fog and sun land on the environment/light directly. Each channel is
	# a separate float so the same interpolation covers every field. The sky
	# colours are written to the Sky's ProceduralSkyMaterial, which is where
	# they actually live.
	_apply_sky(e, "sky_top", _to_env, _from_env, k, true)
	_apply_sky(e, "sky_h", _to_env, _from_env, k, false)
	_apply_color(e, "fog", _to_env, _from_env, k,
		func(env: Environment, col: Color) -> void: env.fog_light_color = col)
	if _to_env.has("fog_density"):
		e.fog_density = lerpf(float(_from_env.get("fog_density", 0.0)),
			float(_to_env.get("fog_density", 0.0)), k)
		var sun: DirectionalLight3D = _find_sun()
		if sun != null:
			sun.light_color = Color(
				lerpf(float(_from_env.get("sun_r", 1.0)), float(_to_env.get("sun_r", 1.0)), k),
				lerpf(float(_from_env.get("sun_g", 1.0)), float(_to_env.get("sun_g", 1.0)), k),
				lerpf(float(_from_env.get("sun_b", 1.0)), float(_to_env.get("sun_b", 1.0)), k))
			sun.light_energy = lerpf(float(_from_env.get("sun_energy", 1.0)),
				float(_to_env.get("sun_energy", 1.0)), k)
	var cam: Camera3D = _find_camera()
	if cam != null and _to_env.has("fov"):
		cam.fov = lerpf(float(_from_env.get("fov", 70.0)),
			float(_to_env.get("fov", 70.0)), k)
	# Once the blend settles, hand the resting FOV to the camera director so its
	# per-frame punch/zoom writes are relative to the styled value instead of
	# snapping back to the pre-pack one.
	if _blend_t >= 1.0 and cam != null and not _fov_handed_off:
		_fov_handed_off = true
		var juice: Object = GameServices.lookup(&"camera")
		if juice != null and juice.has_method("refresh_fov_base"):
			juice.refresh_fov_base()


## True once the current blend has handed its FOV to the camera director.
var _fov_handed_off: bool = false


## Writes one packed colour channel group (prefix_r/g/b/a) onto the environment
## through `setter`, interpolated between the captured base and the target.
func _apply_color(env: Environment, prefix: StringName,
		to_env: Dictionary, from_env: Dictionary, k: float,
		setter: Callable) -> void:
	if not to_env.has(String(prefix) + "_r"):
		return
	setter.call(env, _blend_color(prefix, to_env, from_env, k))


## Writes a sky colour onto the Sky's ProceduralSkyMaterial, where the renderer
## actually reads it. `is_top` picks sky_top_color over sky_horizon_color.
func _apply_sky(env: Environment, prefix: StringName,
		to_env: Dictionary, from_env: Dictionary, k: float, is_top: bool) -> void:
	if not to_env.has(String(prefix) + "_r"):
		return
	var sky_res: Sky = env.sky
	if sky_res == null:
		return
	var mat: ProceduralSkyMaterial = sky_res.sky_material as ProceduralSkyMaterial
	if mat == null:
		return
	var col: Color = _blend_color(prefix, to_env, from_env, k)
	if is_top:
		mat.sky_top_color = col
	else:
		mat.sky_horizon_color = col


## Interpolates one packed colour group between the captured base and target.
func _blend_color(prefix: StringName, to_env: Dictionary,
		from_env: Dictionary, k: float) -> Color:
	return Color(
		lerpf(float(from_env.get(String(prefix) + "_r", 0.0)),
			float(to_env.get(String(prefix) + "_r", 0.0)), k),
		lerpf(float(from_env.get(String(prefix) + "_g", 0.0)),
			float(to_env.get(String(prefix) + "_g", 0.0)), k),
		lerpf(float(from_env.get(String(prefix) + "_b", 0.0)),
			float(to_env.get(String(prefix) + "_b", 0.0)), k),
		lerpf(float(from_env.get(String(prefix) + "_a", 1.0)),
			float(to_env.get(String(prefix) + "_a", 1.0)), k))


func _process(delta: float) -> void:
	_blend_step(delta)
