class_name UIFocus
extends RefCounted
## Navigation accessibility (AGENTS.md §8, scaffold §13.3).
##
## Every screen must be traversable with keyboard AND gamepad. Godot resolves
## the focus neighbours implicitly by the order of the containers, so
## it is enough to mark every interactive control as focusable
## (`focus_mode = FOCUS_ALL`): flechas / D-pad mueven el foco y `ui_accept`
## (Enter, A/X) activa. Sin esto los HSlider y CheckButton son inalcanzables
## with a gamepad even when there are buttons.
##
## Pure helper (RefCounted) so the screens apply it in `_ready`
## and the tests can verify it without a GPU.

## Control types that must enter the focus cycle. Labels and
## Panels are decorative: focusing them dirties the navigation.
const FOCUSABLE_CLASSES: Array[StringName] = [
	&"Button",
	&"CheckButton",
	&"HSlider",
	&"VSlider",
	&"OptionButton",
	&"SpinBox",
	&"LineEdit",
]


## Marks as focusable every interactive control in the subtree.
## Idempotent: calling it twice changes nothing.
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


## True if the control class participates in the navigation.
static func is_focusable_kind(control: Control) -> bool:
	for kind: StringName in FOCUSABLE_CLASSES:
		if control.is_class(String(kind)):
			return true
	return false


## Every focusable control in the subtree, in tree order.
static func collect(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in _walk(root):
		if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL:
			out.append(node as Control)
	return out


## Moves the focus to the first focusable control. It returns the focused node
## (null if the screen has none: it degrades without breaking).
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
