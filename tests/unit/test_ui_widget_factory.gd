extends "res://addons/gut/test.gd"
## Tests de la fábrica de widgets y de la biblioteca de 5 widgets (§13.1).
##
## Gate 1: cada `HUDRecipe.primary_widget` soportado mapea a una escena
## no nula e instanciable. Gate 2: cada widget hace su trabajo cuando
## se le habla por su API pública.

func test_every_kind_maps_to_scene() -> void:
	var kinds: Array[StringName] = WidgetFactory.supported_kinds()
	assert_gt(kinds.size(), 0, "the factory must declare supported kinds")
	for kind: StringName in kinds:
		var scene: PackedScene = WidgetFactory.scene_for(kind)
		assert_not_null(scene, "kind %s must map to a scene" % kind)


func test_create_returns_control_for_each_kind() -> void:
	for kind: StringName in WidgetFactory.supported_kinds():
		var recipe := HUDRecipe.new()
		recipe.primary_widget = kind
		var widget: Control = WidgetFactory.create(recipe)
		assert_not_null(widget, "kind %s must instantiate" % kind)
		assert_true(widget is Control, "widget must be a Control")
		widget.free()


func test_unknown_kind_degrades_to_counter() -> void:
	var recipe := HUDRecipe.new()
	recipe.primary_widget = &"NOT_A_WIDGET"
	var widget: Control = WidgetFactory.create(recipe)
	assert_not_null(widget, "unknown kind must degrade, not crash")
	assert_true(widget is CounterWidget, "unknown kind degrades to COUNTER")
	widget.free()


func test_null_recipe_degrades_to_counter() -> void:
	var widget: Control = WidgetFactory.create(null)
	assert_not_null(widget, "null recipe must degrade, not crash")
	widget.free()


func test_counter_widget_counts_and_pops() -> void:
	var w := _tree(_make_counter())
	w.set_target(12)
	assert_eq(w.target_text(), "/ 12", "target label formats as '/ N'")
	w.set_value(3)
	assert_eq(w.value_text(), "3", "value label shows the counter")
	w.set_value(7)
	assert_gt(w.value_scale(), 1.0, "increment triggers the pop")
	await _await_settled(func() -> float: return w.value_scale())
	assert_almost_eq(w.value_scale(), 1.0, 0.01, "pop settles back to scale 1")


func test_timer_widget_countdown_and_mode() -> void:
	var w := _tree(_make_timer())
	w.set_duration(6.0)
	assert_almost_eq(w.time_left(), 6.0, 0.001, "countdown starts at duration")
	assert_eq(w.time_text(), "6.0", "timer formats tenths of a second")
	w.set_accumulate_mode(true)
	assert_eq(w.mode, TimerWidget.MODE_ACCUMULATE, "accumulate mode engages")
	w.set_accumulate_mode(false)
	assert_eq(w.mode, TimerWidget.MODE_COUNTDOWN, "leaving accumulate restores countdown")
	assert_almost_eq(w.time_left(), 6.0, 0.001, "countdown resumes from where it paused")


func test_progress_widget_zone_marker() -> void:
	var w := _tree(_make_progress())
	w.set_zone(0.75, 0.1)
	assert_true(w.zone_contains(0.75), "zone centre is inside the zone")
	assert_false(w.zone_contains(0.10), "far position is outside the zone")
	assert_true(
		w.marker_position() >= 0.0 and w.marker_position() <= 1.0,
		"marker sweeps 0..1"
	)


func test_sequence_widget_tick_and_shake() -> void:
	var w := _tree(_make_sequence())
	w.set_step_count(4)
	assert_eq(w.total_steps(), 4, "sequence declares its steps")
	assert_eq(w.current_step(), 0, "sequence starts at zero")
	w.hit_step()
	assert_eq(w.current_step(), 1, "hit advances one step")
	w.hit_step()
	assert_eq(w.current_step(), 2, "hit advances again")
	w.miss_step()
	assert_eq(w.current_step(), 0, "miss resets the sequence")


func test_multiplier_widget_punch_on_rise() -> void:
	var w := _tree(_make_multiplier())
	w.set_value(1.0)
	assert_almost_eq(w.value(), 1.0, 0.001, "multiplier stores its value")
	w.set_value(3.5)
	assert_almost_eq(w.value(), 3.5, 0.001, "multiplier rises")
	assert_eq(w.value_text(), "x3.5", "multiplier label formats xN.N")
	assert_gt(w.label_scale(), 1.0, "rise triggers the scale-punch")
	await _await_settled(func() -> float: return w.label_scale())
	assert_almost_eq(w.label_scale(), 1.0, 0.01, "punch settles back")


func _tree(node: Node) -> Node:
	add_child_autofree(node)
	return node


## Espera a que un pop/punch vuelva a escala 1. Robusto al framerate:
## avanza frames hasta que el tween termina (o hasta un tope).
func _await_settled(scale_getter: Callable) -> void:
	var frames := 0
	while float(scale_getter.call()) > 1.001 and frames < 600:
		await get_tree().process_frame
		frames += 1


func _settle() -> void:
	for _i in 20:
		await get_tree().process_frame


func _make_counter() -> CounterWidget:
	return (load("res://src/ui/hud/widgets/counter_widget.tscn") as PackedScene).instantiate() as CounterWidget


func _make_timer() -> TimerWidget:
	return (load("res://src/ui/hud/widgets/timer_widget.tscn") as PackedScene).instantiate() as TimerWidget


func _make_progress() -> ProgressWidget:
	return (load("res://src/ui/hud/widgets/progress_widget.tscn") as PackedScene).instantiate() as ProgressWidget


func _make_sequence() -> SequenceWidget:
	return (load("res://src/ui/hud/widgets/sequence_widget.tscn") as PackedScene).instantiate() as SequenceWidget


func _make_multiplier() -> MultiplierWidget:
	return (load("res://src/ui/hud/widgets/multiplier_widget.tscn") as PackedScene).instantiate() as MultiplierWidget
