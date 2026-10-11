extends Node
## MatchManager — the match state machine and clock (scaffold §5, §6.2).
##
## Flow: BOOT -> TITLE -> COUNTDOWN(3-2-1) -> FREE_ROAM -> ROULETTE ->
## MINIGAME -> STYLE_POP/SCORING -> FREE_ROAM ... until TIME_UP -> RESULTS.
## The 5-minute timer runs continuously (except countdown/results).
## Micro-games run INSIDE the match; the clock never stops for them.
##
## Headless-testable: no hard 3D dependencies. Drive transitions via
## direct calls from tests (advance(), request_roulette(), etc.).

const CONFIG_PATH := "res://src/core/config/game_config.tres"

enum State {
	BOOT,
	TITLE,
	COUNTDOWN,
	FREE_ROAM,
	ROULETTE,
	MINIGAME,
	STYLE_POP,
	TIME_UP,
	RESULTS,
}

var config: GameConfig
var _state: State = State.BOOT
var _time_left: float = 0.0
var _countdown_left: float = 0.0
var _state_elapsed: float = 0.0
var _pending_minigame_id: StringName = &""
var _last_tick_second: int = -1   # last whole second announced via match_tick


func _ready() -> void:
	config = load(CONFIG_PATH) as GameConfig
	if config == null:
		config = GameConfig.new()
		push_warning("MatchManager: config .tres missing, using defaults")
	_time_left = config.match_length_s
	_register_self()
	transition_to(State.TITLE)


func _register_self() -> void:
	var locator := _find_locator()
	if locator != null:
		locator.register(&"match", self)
		locator.register(&"config", config)


func _find_locator() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"/root/GameServices")


# --- Public API -------------------------------------------------------------

func current_state() -> State:
	return _state


## Seconds left in the 5-minute match.
func time_left() -> float:
	return _time_left


## True while the match clock is running (countdown and results excluded).
func clock_running() -> bool:
	return _state == State.FREE_ROAM or _state == State.ROULETTE \
		or _state == State.MINIGAME or _state == State.STYLE_POP


func transition_to(new_state: State) -> void:
	if _state == new_state:
		return
	_exit_state(_state)
	_state = new_state
	_state_elapsed = 0.0
	_enter_state(new_state)


## Frame driver (called by bootstrap or tests with an explicit delta).
func advance(delta: float) -> void:
	_state_elapsed += delta
	if clock_running():
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			transition_to(State.TIME_UP)
			EventBus.emit(&"match_time_up")
			return
		_announce_tick()
	match _state:
		State.COUNTDOWN:
			_countdown_left -= delta
			if _countdown_left <= 0.0:
				transition_to(State.FREE_ROAM)
		State.ROULETTE:
			if _state_elapsed >= config.roulette_spin_s:
				# RouletteController emits roulette_result which calls
				# start_minigame(); if it never arrives, fall back so the
				# match never deadlocks.
				start_minigame(_pending_minigame_id)
		State.STYLE_POP:
			if _state_elapsed >= 1.2:
				transition_to(State.FREE_ROAM)


## Start the match from TITLE (countdown -> freeroam).
func start_match() -> void:
	_time_left = config.match_length_s
	_last_tick_second = -1
	transition_to(State.COUNTDOWN)
	_countdown_left = config.countdown_s
	EventBus.emit(&"match_started")


## Announces the remaining time once per whole second (arcade countdown
## feel; the HUD and VO listen to `match_tick`). 1 Hz, never per frame.
func _announce_tick() -> void:
	var whole: int = int(ceilf(_time_left))
	if whole != _last_tick_second:
		_last_tick_second = whole
		EventBus.emit(&"match_tick", _time_left)


## Free roam picked up a power-up: enter the roulette.
func request_roulette() -> void:
	if _state == State.FREE_ROAM:
		transition_to(State.ROULETTE)
		EventBus.emit(&"roulette_started")


## Roulette result: begin the chosen micro-game (clamped to remaining time).
func start_minigame(minigame_id: StringName) -> void:
	_pending_minigame_id = minigame_id
	if _state != State.ROULETTE and _state != State.FREE_ROAM:
		return
	transition_to(State.MINIGAME)
	EventBus.emit(&"minigame_started", minigame_id)


## Micro-game finished: brief style-pop, then back to freeroam.
func finish_minigame(_result: Resource) -> void:
	if _state != State.MINIGAME:
		return
	transition_to(State.STYLE_POP)
	EventBus.emit(&"minigame_finished", _result)


## Return to title (results shown).
func end_match() -> void:
	transition_to(State.RESULTS)
	EventBus.emit(&"match_reset")


# --- Internals --------------------------------------------------------------

func _enter_state(new_state: State) -> void:
	match new_state:
		State.COUNTDOWN:
			_countdown_left = config.countdown_s
		State.TIME_UP:
			pass


func _exit_state(_old_state: State) -> void:
	pass
