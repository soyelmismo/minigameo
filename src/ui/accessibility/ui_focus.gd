class_name UIFocus
extends RefCounted
## Accesibilidad de navegación (AGENTS.md §8, scaffold §13.3).
##
## Toda pantalla debe poder recorrerse con teclado Y mando. Godot resuelve
## los vecinos de foco implícitamente por el orden de los contenedores, así
## que basta con marcar cada control interactivo como enfocable
## (`focus_mode = FOCUS_ALL`): flechas / D-pad mueven el foco y `ui_accept`
## (Enter, A/X) activa. Sin esto los HSlider y CheckButton son inalcanzables
## con mando aunque haya botones.
##
## Helper puro (RefCounted) para que las pantallas lo apliquen en `_ready`
## y los tests puedan verificarlo sin GPU.

## Tipos de control que deben entrar en la cadencia de foco. Los Label y
## Panel son decorativos: enfocarlos ensucia la navegación.
const FOCUSABLE_CLASSES: Array[StringName] = [
	&"Button",
	&"CheckButton",
	&"HSlider",
	&"VSlider",
	&"OptionButton",
	&"SpinBox",
	&"LineEdit",
]


## Marca como enfocables todos los controles interactivos del subárbol.
## Idempotente: llamarlo dos veces no cambia nada.
static func enable(root: Node) -> int:
	var marked: int = 0
	for node: Node in _walk(root):
		if not (node is Control):
			continue
		var control := node as Control
		if not is_focusable_kind(control):
			continue
		control.focus_mode = Control.FOCUS_ALL
		marked += 1
	return marked


## True si la clase del control participa en la navegación.
static func is_focusable_kind(control: Control) -> bool:
	for kind: StringName in FOCUSABLE_CLASSES:
		if control.is_class(String(kind)):
			return true
	return false


## Todos los controles enfocables del subárbol, en orden de árbol.
static func collect(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in _walk(root):
		if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL:
			out.append(node as Control)
	return out


## Lleva el foco al primer control enfocable. Devuelve el nodo enfocado
## (null si la pantalla no tiene ninguno: se degrada sin romper).
static func grab_first(root: Node) -> Control:
	var candidates: Array[Control] = collect(root)
	if candidates.is_empty():
		return null
	var first := candidates[0]
	first.grab_focus()
	return first


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out
