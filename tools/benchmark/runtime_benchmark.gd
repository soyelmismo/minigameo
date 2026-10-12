extends Node
## Runtime probe: starts a real match through the real UI path and measures the
## §15 render budget while micro-games actually run. Wired into main.tscn by the
## orchestrator, then removed again — it is a measurement tool, not gameplay.
##
## Usage: godot --rendering-driver opengl3 --resolution 1920x1080 \
##            [--fullscreen] [--vsync] res://src/bootstrap/main.tscn
## The probe always exits on its own (watchdog + quit), never hangs open.

## Hard wall-clock guard. Whatever happens inside the measurement loop, this
## process must never linger: a stalled frame would otherwise leave Godot
## running forever.
const MAX_RUNTIME_S := 120.0
const SAMPLE_FRAMES := 900
const ROUNDS := 6
## 16.7 ms is the 60 FPS frame budget from scaffold §15.
const FRAME_BUDGET_MS := 16.7
## How long to wait for the anti-repetition cooldown before giving up on a round.
const COOLDOWN_WAIT_S := 12.0

var _mm: Node
var _director: Node

var _rounds := 0
var _played := 0
var _peak_draw := 0
var _peak_prims := 0
var _peak_entities := 0
var _frames := 0
var _over_budget := 0
var _worst_ms := 0.0
## Frames the renderer actually drew, counted by the engine: the true FPS.
var _drawn := 0
## Wall-clock elapsed for the sampled window: TIME_PROCESS is not a usable frame
## time under vsync (the pacing wait lands in the process step), so real FPS is
## frames divided by elapsed wall time instead.
var _elapsed_s := 0.0


func _ready() -> void:
	# Engine flags (--fullscreen) are stripped from get_cmdline_args(), and
	# --user args are stripped from get_cmdline_user_args(); merge both so the
	# probe sees the flag whichever way it was invoked.
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var fullscreen := "--fullscreen" in args
	var vsync := "--vsync" in args
	# Set the mode explicitly in BOTH directions. Godot's default is
	# VSYNC_ENABLED, so a run meant to measure uncapped capacity silently runs
	# vsync-locked at 60 fps unless it is turned off here.
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("PROBE_MODE         = %s vsync=%s resolution=%dx%d" % [
		"fullscreen" if fullscreen else "windowed",
		"on" if vsync else "off",
		DisplayServer.window_get_size().x,
		DisplayServer.window_get_size().y,
	])
	print("PROBE_ENGINE_CAP   = max_fps=%d physics_ticks=%d vsync_mode=%d" % [
		Engine.max_fps,
		int(Engine.get_physics_ticks_per_second()),
		DisplayServer.window_get_vsync_mode(),
	])
	_watchdog()
	_begin()


func _begin() -> void:
	_mm = get_tree().root.get_node_or_null("/root/MatchManager")
	_director = get_tree().root.get_node_or_null("/root/MinigameDirector")
	if _mm == null or _director == null:
		print("PROBE_ABORT        = missing MatchManager/MinGameDirector autoload")
		_quit_soon(2)
		return
	# Start through the real UI path: emitting the button's pressed() signal runs
	# TitleScreen._on_play(), exactly as a player click would.
	await _await_title_screen()
	var play: Button = _find_play_button()
	if play == null:
		print("PROBE_ABORT        = no PlayButton in the scene")
		_quit_soon(2)
		return
	play.pressed.emit()
	print("PROBE_MATCH        = started via PlayButton.pressed")
	# Let the countdown finish so the first round comes out of free roam.
	await get_tree().create_timer(3.6).timeout
	_run_rounds()


func _run_rounds() -> void:
	while _rounds < ROUNDS:
		await _play_round()
	_report()
	_quit_soon(0)


## Drives one micro-game through the production entry point and lets it live
## long enough for its entities to be on screen while frames are measured.
func _play_round() -> void:
	_rounds += 1
	if not await _await_cooldown():
		print("PROBE_ROUND        = %d SKIPPED (cooldown never cleared)" % _rounds)
		return
	_mm.request_roulette()
	# Roulette spin (2.5 s) plus micro-game bring-up.
	await get_tree().create_timer(3.0).timeout
	if not _director.is_active():
		print("PROBE_ROUND        = %d SKIPPED (director refused)" % _rounds)
		return
	_played += 1
	var spawned: int = get_tree().get_nodes_in_group(&"mg_entity").size()
	_peak_entities = maxi(_peak_entities, spawned)
	print("PROBE_ROUND        = %d id=%s alive=%d" % [
		_rounds, String(_director.get_active_id()), spawned,
	])
	# Let the micro-game play out while the sampler runs.
	await _sample_window(400)
	# Finish it so the state machine returns to free roam.
	_director.get_active().finished.emit(MinigameResult.make(true, 100, 0, 1))


## Waits for the anti-repetition cooldown so request_roulette() is accepted.
func _await_cooldown() -> bool:
	var waited := 0.0
	while waited < COOLDOWN_WAIT_S:
		if _director.has_method("get_cooldown_left") \
				and float(_director.get_cooldown_left()) <= 0.0:
			return true
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return false


## Samples a window of production frames, accumulating the peak render load and
## the worst frame time across the whole probe.
##
## FPS comes from Engine.get_frames_drawn() / wall time, NOT from counting
## awaited process_frame signals: that signal is tied to the process tick
## (60 Hz by default), so counting it caps the measured FPS at 60 even when the
## renderer is running far faster. Awaiting is still the right way to sample the
## per-frame render counters (draw calls, primitives).
func _sample_window(frames: int) -> void:
	var t0 := Time.get_ticks_usec()
	var f0 := Engine.get_frames_drawn()
	for _i in frames:
		await get_tree().process_frame
		var ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		_frames += 1
		_worst_ms = maxf(_worst_ms, ms)
		if ms > FRAME_BUDGET_MS:
			_over_budget += 1
		_peak_draw = maxi(_peak_draw, int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_peak_prims = maxi(_peak_prims, int(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_drawn += Engine.get_frames_drawn() - f0
	_elapsed_s += float(Time.get_ticks_usec() - t0) / 1000000.0


func _report() -> void:
	var fps := 0.0 if _elapsed_s <= 0.0 else float(_drawn) / _elapsed_s
	var frame_ms := 0.0 if _drawn == 0 else _elapsed_s * 1000.0 / float(_drawn)
	print("PROBE_STRESS_ROUNDS= %d micro-games played of %d requested" % [_played, _rounds])
	print("PROBE_PEAK_ENTITIES= %d" % _peak_entities)
	print("PROBE_FRAMES        = %d sampled, %d frames drawn in %.1f s" % [
		_frames, _drawn, _elapsed_s,
	])
	print("PROBE_AVG_FPS       = %.1f (%.2f ms/frame average)" % [fps, frame_ms])
	print("PROBE_PEAK_DRAW     = %d (budget < 400)" % _peak_draw)
	print("PROBE_PEAK_PRIMS    = %d (budget < 250000)" % _peak_prims)
	print("PROBE_FRAME_MS_WORST= %.2f (%.1f = 60 fps, TIME_PROCESS)" % [
		_worst_ms, FRAME_BUDGET_MS,
	])
	print("PROBE_MATCH_STATE   = %s" % _match_state())


func _match_state() -> String:
	var names := ["BOOT", "TITLE", "COUNTDOWN", "FREE_ROAM", "ROULETTE",
		"MINIGAME", "STYLE_POP", "TIME_UP", "RESULTS"]
	var idx := int(_mm.current_state())
	if idx < 0 or idx >= names.size():
		return "?"
	return names[idx]


func _find_play_button() -> Button:
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and String(n.name) == "PlayButton":
			return n as Button
		for c in n.get_children():
			stack.append(c)
	return null


## Waits for the title screen to be built. This probe is a child of main.tscn,
## and Godot calls children's _ready() before the parent's, so main.gd has not
## run _build_screens() yet when this probe starts.
func _await_title_screen() -> void:
	for _i in 60:
		if _find_play_button() != null:
			return
		await get_tree().process_frame


## Quits on the next frame so the final prints are flushed before exit.
func _quit_soon(code: int) -> void:
	get_tree().root.set_meta("probe_done", true)
	await get_tree().process_frame
	get_tree().quit(code)


## Wall-clock watchdog: the probe always exits, even if the measurement loop
## blocks. Without this a stalled frame leaves Godot running forever.
func _watchdog() -> void:
	var deadline_us: int = Time.get_ticks_usec() + int(MAX_RUNTIME_S * 1000000.0)
	while Time.get_ticks_usec() < deadline_us:
		await get_tree().create_timer(2.0).timeout
		if get_tree().root.has_meta("probe_done"):
			return
	print("PROBE_WATCHDOG      = hard exit after %.0f s without a clean quit"
		% MAX_RUNTIME_S)
	get_tree().quit(2)
