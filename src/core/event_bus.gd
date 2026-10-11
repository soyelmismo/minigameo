extends Node
## EventBus — global signal bus (scaffold §6.1).
##
## Typed signals with StringName event ids. Systems emit and listen here to
## stay decoupled. NEVER use for frame-by-frame gameplay where order matters
## (that is a direct call); only for event decoupling.
##
## Canonical event list (scaffold §6.1):
##   powerup_collected(minigame_id)
##   roulette_started / roulette_result(id)
##   minigame_started(id) / minigame_finished(result)
##   style_applied(pack_id) / style_reverted()
##   score_changed(total, delta) / combo_changed(combo)
##   impact_requested(weight)
##   match_time_up() / match_started() / match_reset()
##   player_state_changed(state)
##   voice_requested(event_id)

signal powerup_collected(minigame_id: StringName)
signal roulette_started()
signal roulette_result(id: StringName)
signal minigame_started(id: StringName)
## Full-screen announcement beat: carries the metadata so the UI can show the
## name, objective and flavour text before the round starts (§13.2).
signal minigame_announced(meta: Resource)
signal minigame_finished(result: MinigameResult)
signal style_applied(pack_id: StringName)
signal style_reverted()
signal score_changed(total: int, delta: int)
signal combo_changed(combo: int)
signal impact_requested(weight: int)
signal match_time_up()
signal match_started()
signal match_reset()
signal match_tick(time_left: float)
signal player_state_changed(state: StringName)
signal voice_requested(event_id: StringName)


## The canonical event id -> signal name map. Emit helpers below route
## through it so callers pass StringName ids (scaffold §6.1) instead of
## holding a reference to this node.
static func signal_name_for(event: StringName) -> String:
	match event:
		&"powerup_collected": return "powerup_collected"
		&"roulette_started": return "roulette_started"
		&"roulette_result": return "roulette_result"
		&"minigame_started": return "minigame_started"
		&"minigame_finished": return "minigame_finished"
		&"style_applied": return "style_applied"
		&"style_reverted": return "style_reverted"
		&"score_changed": return "score_changed"
		&"combo_changed": return "combo_changed"
		&"impact_requested": return "impact_requested"
		&"match_time_up": return "match_time_up"
		&"match_tick": return "match_tick"
		&"match_started": return "match_started"
		&"match_reset": return "match_reset"
		&"player_state_changed": return "player_state_changed"
		&"voice_requested": return "voice_requested"
	return ""


## Emit by event id with zero or one argument (the shapes the canonical
## list uses). Degrades silently when the bus is absent (tests, early boot).
func emit_event(event: StringName, arg0: Variant = null, arg1: Variant = null) -> void:
	_emit_on(_resolve_bus(), event, arg0, arg1)


func _resolve_bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"/root/EventBus")


## Static entry point for systems that must not hold a bus reference:
## resolves the EventBus autoload if present and emits through it.
static func emit(event: StringName, arg0: Variant = null, arg1: Variant = null) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_emit_on(tree.root.get_node_or_null(^"/root/EventBus"), event, arg0, arg1)


static func _emit_on(bus: Node, event: StringName, arg0: Variant, arg1: Variant) -> void:
	if bus == null:
		return
	var method := signal_name_for(event)
	if method == "":
		push_warning("EventBus: unknown event id '%s'" % event)
		return
	if arg1 != null:
		bus.emit_signal(method, arg0, arg1)
	elif arg0 != null:
		bus.emit_signal(method, arg0)
	else:
		bus.emit_signal(method)
