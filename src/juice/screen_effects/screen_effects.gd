extends CanvasLayer
## ScreenEffects — fullscreen flash + grade overlay (scaffold §6.7).
##
## Two fullscreen nodes driven by PostFXDirector.overlay_state():
##   FlashRect — solid tint, the impact flash (accessibility-gated).
##   GradeRect — vignette / scanlines / chromatic / desaturate, one pass of
##               assets/shaders/postfx_overlay.gdshader.
## Both read the director duck-typed and stay invisible and inert when it is
## absent (headless tests, boot probes).

const OVERLAY_SHADER := preload("res://assets/shaders/postfx_overlay.gdshader")

@onready var _rect: ColorRect = $FlashRect

var _postfx: Object = null
var _grade: ColorRect = null
var _grade_mat: ShaderMaterial = null


func _ready() -> void:
	layer = 128
	if _rect != null:
		_rect.color = Color(1, 1, 1, 0)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_grade()
	_find_postfx()


## The grade overlay is built in code (not in the .tscn) so the whole effect
## stack lives next to the director that drives it.
func _build_grade() -> void:
	_grade = ColorRect.new()
	_grade.name = "GradeRect"
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.color = Color(0, 0, 0, 0)
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = OVERLAY_SHADER
	_grade.material = _grade_mat
	add_child(_grade)


func _find_postfx() -> void:
	# Resolve by path: the autoload global identifier is not available in
	# every compile context (--script probes), the node path always is.
	var tree := get_tree()
	if tree == null:
		return
	var services: Object = tree.root.get_node_or_null("/root/GameServices") as Object
	if services != null and services.has_method("lookup"):
		_postfx = services.lookup(&"postfx")


func _process(_delta: float) -> void:
	if _postfx == null:
		_find_postfx()
		return
	var state: Dictionary = _postfx.overlay_state()
	if _rect != null:
		var alpha: float = float(state.get("flash", 0.0))
		var c: Color = state.get("flash_color", Color.WHITE)
		_rect.color = Color(c.r, c.g, c.b, alpha)
	_apply_grade(state)


## Push the grade values into the shader uniforms (no allocation per frame).
func _apply_grade(state: Dictionary) -> void:
	if _grade_mat == null:
		return
	_grade_mat.set_shader_parameter("vignette", float(state.get("vignette", 0.0)))
	_grade_mat.set_shader_parameter("chromatic", float(state.get("chromatic", 0.0)))
	_grade_mat.set_shader_parameter("scanline", float(state.get("scanline", 0.0)))
	_grade_mat.set_shader_parameter("desaturate", float(state.get("desaturate", 0.0)))
