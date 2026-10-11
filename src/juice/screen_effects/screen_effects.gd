extends CanvasLayer
## ScreenEffects — fullscreen flash/vignette/chromatic overlay (scaffold §6.7).
##
## A ColorRect driven by the PostFXDirector's overlay_state(). Reads the
## director duck-typed; invisible and inert when absent (headless).

@onready var _rect: ColorRect = $FlashRect

var _postfx: Object = null


func _ready() -> void:
	layer = 128
	if _rect != null:
		_rect.color = Color(1, 1, 1, 0)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_postfx()


func _find_postfx() -> void:
	_postfx = GameServices.lookup(&"postfx")


func _process(_delta: float) -> void:
	if _rect == null:
		return
	if _postfx == null:
		_find_postfx()
		return
	var state: Dictionary = _postfx.overlay_state()
	var alpha: float = float(state.get("flash", 0.0))
	var c: Color = state.get("flash_color", Color.WHITE)
	_rect.color = Color(c.r, c.g, c.b, alpha)
