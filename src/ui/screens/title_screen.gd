extends Control
class_name TitleScreen
## Pantalla de título (scaffold §13.2): logo grande, PLAY, hint de controles,
## mejor score.
##
## Integración (§13.2):
## - PLAY arranca la partida vía `MatchManager.start_match()`.
## - El récord sale de `SaveSystem.best_score` (propiedad, NO un método).
## - La música pasa a CALM al llegar a título.
##
## Los autoloads NO tienen class_name global: se resuelven por path
## (`/root/X`) o vía `GameServices.lookup()`, y toda llamada va protegida con
## `has_method` para que la pantalla siga instanciando headless sin ellos.

const SERVICES_PATH := &"/root/GameServices"
const MATCH_PATH := &"/root/MatchManager"
const SAVE_PATH := &"/root/SaveSystem"
const MUSIC_PATH := &"/root/MusicDirector"

## Estado musical de título (MusicDirector.STATE_CALM, scaffold §10.2).
const MUSIC_CALM: StringName = &"CALM"

signal play_pressed()

@onready var _best_label: Label = %BestLabel
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	PanelStyler.apply(%LogoPanel, UIColors.PRIMARY, 24)
	PanelStyler.apply(%HintPanel, UIColors.AI)
	UIFocus.enable(self)
	_play_button.pressed.connect(_on_play)
	_best_label.text = "BEST: %s" % _format_best(best_score())
	# El título siempre suena en calma; si no hay música, se degrada en silencio.
	_play_calm_music()


## PLAY: arranca la partida y avisa a quien escuche la señal.
func _on_play() -> void:
	var match_mgr: Object = _resolve(MATCH_PATH)
	if match_mgr != null and match_mgr.has_method("start_match"):
		match_mgr.start_match()
	play_pressed.emit()


## Récord guardado, o 0 si no hay SaveSystem (degradación silenciosa).
func best_score() -> int:
	var save: Object = _resolve(SAVE_PATH)
	if save == null:
		return 0
	var stored: Variant = save.get(&"best_score")
	if stored == null:
		return 0
	return int(stored)


## Línea del récord (para tests).
func best_text() -> String:
	return _best_label.text


## Texto del logo (para tests).
func title_text() -> String:
	return %TitleLabel.text


## Pide a MusicDirector el estado CALM de título.
func _play_calm_music() -> void:
	var music: Object = _resolve(MUSIC_PATH)
	if music != null and music.has_method("play_music_state"):
		music.play_music_state(MUSIC_CALM)


## Resuelve un autoload: primero por GameServices, y si no, por path.
## Degrada a null sin ruido cuando el sistema no está presente.
func _resolve(path: StringName) -> Object:
	var root := get_tree().root
	var services: Object = root.get_node_or_null(String(SERVICES_PATH)) as Object
	if services != null and services.has_method("lookup"):
		var via_services: Object = services.lookup(StringName(String(path).get_file()))
		if via_services != null:
			return via_services
	return root.get_node_or_null(String(path)) as Object


## Separa los millares: 1234567 -> "1,234,567".
func _format_best(v: int) -> String:
	var s := str(int(absi(v)))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
