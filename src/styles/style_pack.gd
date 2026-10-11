class_name StylePack
extends Resource
## StylePack — a temporary visual transformation of the world (scaffold §7.5).
##
## One of the 12 looks of scaffold §9. The StyleDirector applies it with a
## smooth blend and auto-reverts when the micro-game ends. All tuning here
## is data: the director never hardcodes a palette.

@export var id: StringName = &""

@export var display_name: String = ""

# --- World atmosphere ---
@export var sky_top: Color = Color(0.25, 0.45, 0.9)
@export var sky_horizon: Color = Color(0.8, 0.85, 0.95)
@export var fog_color: Color = Color(0.7, 0.75, 0.85)
@export var fog_density: float = 0.0

# --- Lighting ---
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.2
@export var ambient_color: Color = Color(0.55, 0.6, 0.7)
@export var ambient_energy: float = 0.6

# --- Look strategy ---
# FULL_SWAP: distinct materials/models. SHADER_UNIFORM: global uniforms the
# world shader reads (preferred - cheap, no pop). OVERLAY: material_overlay.
@export var material_mode: StringName = &"SHADER_UNIFORM"
@export var character_material: Material = null
@export var environment_material: Material = null

# --- PostFX + camera ---
@export var postfx: StylePostFX = null
@export var fov_override: float = -1.0        # -1 = no override
@export var camera_offset: Vector3 = Vector3.ZERO

# --- Feedback ---
@export var music_state: StringName = &""
@export var hud_theme: Theme = null
@export var transition_s: float = 0.4
@export var revert_to_base_on_end: bool = true

# --- Shader uniform payload (SHADER_UNIFORM mode) ---
# Keys are the u_style_* uniform names the world shader declares.
@export var style_uniforms: Dictionary = {}
