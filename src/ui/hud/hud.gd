extends CanvasLayer
class_name GameHUD
## HUD maestro (scaffold §13.1). La capa de interfaz es DATA-DRIVEN:
## el objetivo del micro-juego se auto-construye desde `HUDRecipe`
## vía WidgetFactory; cero widgets ad-hoc por micro-juego (§1.8).
##
## Acoplamiento: CERO. Los sistemas se buscan duck-typed en
## /root (GameServices, EventBus, MatchManager...). Si no existen
## (tests headless, arranque temprano), el HUD degrada en silencio y
## expone los setters directos: set_objective / set_score / set_combo /
## set_match_time / show_callout.

signal play_again_requested()

@export var cfg: HUDConfig = null

@onready var _match_timer: Label = %MatchTimerLabel
@onready var _score_value: Label = %ScoreValue
@onready var _multiplier: MultiplierWidget = %MultiplierWidget
@onready var _objective_center: VBoxContainer = %ObjectiveCenter
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _flavor_label: Label = %FlavorLabel
@onready var _widget_slot: Control = %WidgetSlot
@onready var _callout: Label = %CalloutLabel
@onready var _compass: Control = %CompassLayer
@onready var _compass_arrows: Array[Control] = [
	%ArrowUp, %ArrowDown, %ArrowLeft, %ArrowRight,
]

var _objective_widget: Control = null
var _score_target: int = 0
var _score_displayed: float = 0.0
var _score_pop: float = 1.0
var _match_remaining: float = 300.0
var _pulse_active: bool = false
var _flavor_timer: SceneTreeTimer = null
var _callout_timer: SceneTreeTimer = null
var _event_bus: Object = null


func _ready() -> void:
	if cfg == null:
		cfg = load("res://src/ui/hud/hud_config.tres") as HUDConfig
	if cfg == null:
		cfg = HUDConfig.new()
	_connect_event_bus()
	_multiplier.set_value(1.0)
	_score_value.text = "0"
	_match_timer.text = "5:00"


# --- EventBus (duck-typed; ausente → sin suscripción, setters manuales) ---

func _connect_event_bus() -> void:
	_event_bus = _find(&"EventBus")
	if _event_bus == null:
		return
	for sig: String in ["minigame_started", "minigame_finished", "score_changed", "combo_changed", "match_time_up", "match_tick", "style_applied"]:
		if _event_bus.has_signal(sig):
			match sig:
				"minigame_started":
					_event_bus.minigame_started.connect(_on_minigame_started)
				"minigame_finished":
					_event_bus.minigame_finished.connect(_on_minigame_finished)
				"score_changed":
					_event_bus.score_changed.connect(_on_score_changed)
				"combo_changed":
					_event_bus.combo_changed.connect(_on_combo_changed)
				"match_time_up":
					_event_bus.match_time_up.connect(_on_match_time_up)
				"match_tick":
					_event_bus.match_tick.connect(_on_match_tick)
				"style_applied":
					_event_bus.style_applied.connect(_on_style_applied)


func _on_minigame_started(id: StringName) -> void:
	_apply_metadata_from_director(id)


func _on_minigame_finished(result: Object) -> void:
	clear_objective()
	show_callout(
		"Well. You tried. Did you though?"
		if result != null and not bool(result.success)
		else "FLAWLESS. I'm telling everyone."
	)


func _on_score_changed(total: int, _delta: int) -> void:
	set_score(total)


func _on_combo_changed(combo: int) -> void:
	set_combo(combo)


func _on_match_time_up() -> void:
	set_match_time(0.0)


func _on_match_tick(time_left: float) -> void:
	set_match_time(time_left)


func _on_style_applied(pack_id: StringName) -> void:
	_apply_hud_theme_for_style(pack_id)


# --- API pública (setters; usados por el bus, los tests y la integración) ---

## Construye el widget de objetivo desde el HUDRecipe y muestra el
## objetivo + flavor text (§13.1). Si recipe es null, limpia el objetivo.
func set_objective(recipe: HUDRecipe, objective: String = "", flavor: String = "") -> void:
	clear_objective()
	if recipe == null:
		return
	var widget := WidgetFactory.create(recipe)
	if widget == null:
		return
	_apply_widget_config(widget, recipe)
	_widget_slot.add_child(widget)
	_objective_widget = widget
	_objective_label.text = objective
	_objective_label.visible = objective != ""
	if recipe.show_flavor and flavor != "":
		_flavor_label.text = flavor
		_flavor_label.visible = true
		if _flavor_timer != null:
			_flavor_timer.time_left = 0.0
		_flavor_timer = get_tree().create_timer(cfg.flavor_duration_s)
		_flavor_timer.timeout.connect(_hide_flavor)
	if recipe.callout_on_start != &"":
		show_callout(String(recipe.callout_on_start))


## Oculta el widget de objetivo (vuelta a freeroam).
func clear_objective() -> void:
	if _flavor_timer != null:
		_flavor_timer = null
	_flavor_label.visible = false
	if _objective_widget != null:
		_objective_widget.queue_free()
		_objective_widget = null
	_objective_label.text = ""


## Score with an animated counter and pop (§13.2).
func set_score(value: int) -> void:
	_score_target = maxi(0, value)
	# Pop lands synchronously so the frame the score rises is already scaled.
	_score_pop = cfg.score_pop_scale
	_score_value.scale = Vector2.ONE * _score_pop


## Multiplicador del combo (widget ruidoso, §13.1).
func set_combo(combo: int) -> void:
	var mult: float = 1.0 + maxi(0, combo) * 0.5
	_multiplier.set_value(mult)


## Tiempo restante de partida. Pulso rojo bajo el umbral (§13.1).
func set_match_time(seconds: float) -> void:
	_match_remaining = maxf(0.0, seconds)
	var mins := int(_match_remaining) / 60
	var secs := int(_match_remaining) % 60
	_match_timer.text = "%d:%02d" % [mins, secs]
	var should_pulse: bool = _match_remaining <= cfg.match_pulse_threshold_s and _match_remaining > 0.0
	if should_pulse and not _pulse_active:
		_pulse_active = true
	if not should_pulse and _pulse_active:
		_pulse_active = false
		_match_timer.modulate = UIColors.TEXT
		_match_timer.scale = Vector2.ONE
	if _pulse_active:
		var s: float = 1.0 + sin(Time.get_ticks_msec() * 0.001 * cfg.pulse_speed) * 0.1
		_match_timer.scale = Vector2.ONE * s
		_match_timer.modulate = UIColors.DANGER


## Callout subtitulado (VO, §13.3: siempre visible además de la voz).
func show_callout(text: String) -> void:
	if text == "":
		return
	# Subtitles (§8): the callout is always the text twin of the VO line, so a
	# deaf player sees exactly what the announcer says. A player who turns
	# subtitles off still gets the audio; the visual signal stays the pulse.
	if not _subtitles_enabled():
		return
	_callout.text = text
	_callout.visible = true
	if _callout_timer != null:
		_callout_timer.time_left = 0.0
	_callout_timer = get_tree().create_timer(cfg.callout_duration_s / _text_speed())
	_callout_timer.timeout.connect(func() -> void: _callout.visible = false)


## Subtitles on/off and text speed come from SettingsManager (§8); both
## degrade to "on, normal" when the manager is absent (tests, early boot).
func _subtitles_enabled() -> bool:
	var settings: Object = GameServices.lookup(&"settings")
	if settings != null and settings.has_method("subtitles_enabled"):
		return bool(settings.subtitles_enabled())
	return true


func _text_speed() -> float:
	var settings: Object = GameServices.lookup(&"settings")
	if settings != null and settings.has_method("text_speed"):
		return clampf(float(settings.text_speed()), 0.25, 4.0)
	return 1.0


## Posiciones normalizadas (0..1 viewport) de power-ups fuera de pantalla.
## El mundo llama con las posiciones; las flechas se colocan en el borde.
func set_powerup_markers(points: PackedVector2Array) -> void:
	var size := get_viewport().get_visible_rect().size
	for i in mini(points.size(), _compass_arrows.size()):
		var p: Vector2 = points[i]
		var arrow: Control = _compass_arrows[i]
		arrow.visible = true
		arrow.position = Vector2(p.x * size.x, p.y * size.y)


## Aplica el hud_theme del style pack (§13.2: la UI muta con el escenario).
func apply_theme(theme: Theme) -> void:
	if theme == null:
		return
	# CanvasLayer no tiene `theme`: se aplica al Root (Control).
	%Root.theme = theme


## Theme activo del HUD (para tests).
func active_theme() -> Theme:
	return %Root.theme


## True when a subtitle is currently on screen.
func is_callout_visible() -> bool:
	return _callout != null and _callout.visible


## The subtitle text currently shown (empty when none).
func shown_callout() -> String:
	return _callout.text if _callout != null else ""


## True cuando el contador animado ha llegado al objetivo (para tests).
func score_counter_settled() -> bool:
	return int(_score_displayed) >= _score_target


# --- Lecturas para tests / integración ---

func shown_objective() -> String:
	return _objective_label.text


func current_objective_widget() -> Control:
	return _objective_widget


func score_text() -> String:
	return _score_value.text


func score_label_scale() -> float:
	return _score_value.scale.x


func multiplier_value() -> float:
	return _multiplier.value()


func match_time_text() -> String:
	return _match_timer.text


func match_pulsing() -> bool:
	return _pulse_active


func callout_visible() -> bool:
	return _callout.visible


func callout_text() -> String:
	return _callout.text


func arrow_visible(index: int) -> bool:
	if index < 0 or index >= _compass_arrows.size():
		return false
	return _compass_arrows[index].visible


# --- Internos ---

func _hide_flavor() -> void:
	_flavor_label.visible = false


func _tween_score(v: float) -> void:
	_score_displayed = v
	_score_value.text = str(int(v))


func _process(delta: float) -> void:
	# Animated score counter: exponential approach to the target (§13.2).
	_score_displayed = HudAnim.approach(
		_score_displayed, float(_score_target), cfg.counter_decay, delta
	)
	# Snap when the remaining gap is under one displayed unit: the counter must
	# land exactly on the final number, not hover one below it (int() floors).
	if absf(float(_score_target) - _score_displayed) < 1.0:
		_score_displayed = float(_score_target)
	var shown := int(_score_displayed)
	if _score_value.text != str(shown):
		_score_value.text = str(shown)
	# Score pop decays back to scale 1.
	_score_pop = HudAnim.approach(_score_pop, 1.0, cfg.pop_decay, delta)
	_score_value.scale = Vector2.ONE * _score_pop


func _apply_widget_config(widget: Control, recipe: HUDRecipe) -> void:
	if widget.has_method("configure"):
		widget.configure(recipe.icon, UIColors.semantic(recipe.color_hint))
	if widget.has_method("set_target") and _target_of(recipe) > 0:
		widget.set_target(_target_of(recipe))


## Target leído del ObjectiveRecipe si está presente (duck-typed).
func _target_of(recipe: HUDRecipe) -> int:
	if recipe.has_meta("objective_target"):
		var meta: Variant = recipe.get_meta("objective_target")
		return int(meta)
	return 0


## El HUD lee la metadata del micro-juego activo del director (duck-typed).
func _apply_metadata_from_director(id: StringName) -> void:
	var director := _find(&"MinigameDirector")
	if director == null or not director.has_method("get_metadata_for"):
		return
	var meta: Object = director.get_metadata_for(id)
	if meta == null:
		return
	var recipe: HUDRecipe = meta.hud_recipe
	var text: String = String(meta.objective_text)
	var flavor: String = String(meta.flavor_text)
	if meta.hud_recipe == null:
		clear_objective()
		show_callout(text)
		return
	set_objective(recipe, text, flavor)


func _apply_hud_theme_for_style(_pack_id: StringName) -> void:
	var style := _find(&"StyleDirector")
	if style == null or not style.has_method("get_hud_theme"):
		return
	var theme: Theme = style.get_hud_theme()
	apply_theme(theme)


## Busca un sistema duck-typed en /root (GameServices primero).
func _find(system_name: StringName) -> Object:
	var root := get_tree().root if is_inside_tree() else null
	if root == null:
		return null
	var services := root.get_node_or_null("/root/GameServices")
	if services != null and services.has_method("get"):
		var svc: Object = services.get(system_name)
		if svc != null:
			return svc
	return root.get_node_or_null("/root/" + String(system_name))
