extends Control
class_name TitleScreen
## Pantalla de título (scaffold §13.2): logo grande, PLAY, hint de
## controles, mejor score. El récord sale de SaveSystem duck-typed
## (/root/SaveSystem o GameServices); si no existe, variable local.

signal play_pressed()

@onready var _best_label: Label = %BestLabel
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	PanelStyler.apply(%LogoPanel, UIColors.PRIMARY, 24)
	PanelStyler.apply(%HintPanel, UIColors.AI)
	_play_button.pressed.connect(_on_play)
	_best_label.text = "BEST: %s" % _format_best(_load_best())


func _on_play() -> void:
	play_pressed.emit()


## Récord guardado, o 0 si no hay SaveSystem (degradación silenciosa).
func _load_best() -> int:
	var save := _find(&"SaveSystem")
	if save != null and save.has_method("get_best_score"):
		return int(save.get_best_score())
	return 0


func _find(name: StringName) -> Object:
	var root := get_tree().root
	var services := root.get_node_or_null("/root/GameServices")
	if services != null and services.has_method("get"):
		var svc: Object = services.get(name)
		if svc != null:
			return svc
	return root.get_node_or_null("/root/" + String(name))


func _format_best(v: int) -> String:
	var s := str(v)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
