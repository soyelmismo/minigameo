extends Node
## ScoreDirector — score, combo multiplier, time bonus, ranks (scaffold §6.3).
##
## Score language of the arcade: base points + combo multiplier + leftover
## time bonus. Ranks D < C < B < A < S < S+ with thresholds from GameConfig
## (data, not code). Emits score_changed / combo_changed via EventBus.

var config: GameConfig
var total_score: int = 0
var combo: int = 0
var _combo_timer: float = 0.0
var _multiplier: float = 1.0


func _ready() -> void:
	config = _load_config()
	_register_self()


func _load_config() -> GameConfig:
	var cfg: Object = GameServices.lookup(&"config")
	if cfg is GameConfig:
		return cfg as GameConfig
	var loaded := load("res://src/core/config/game_config.tres") as GameConfig
	return loaded if loaded != null else GameConfig.new()


func _register_self() -> void:
	var locator: Object = GameServices.lookup(&"core")
	if locator != null and locator.has_method("register"):
		locator.register(&"score", self)

# --- Combo ------------------------------------------------------------------

## A success: bumps the combo and multiplier. Call on every win/hit.
func register_success() -> void:
	combo += 1
	_combo_timer = config.combo_timeout_s
	_multiplier = minf(1.0 + float(combo) * config.combo_step, config.combo_max)
	EventBus.emit(&"combo_changed", combo)


## A failure/timeout: resets the combo (but never the total score).
func break_combo() -> void:
	if combo != 0:
		combo = 0
		_multiplier = 1.0
		EventBus.emit(&"combo_changed", combo)


func current_multiplier() -> float:
	return _multiplier


# --- Score ------------------------------------------------------------------

## Add raw points (already multiplied by the caller's context if needed).
func add_points(points: int) -> void:
	if points <= 0:
		return
	total_score += points
	EventBus.emit(&"score_changed", total_score, points)


## Score a finished micro-game: base + combo multiplier + time bonus.
func score_minigame(base: int, time_left_s: float) -> int:
	var bonus := int(maxf(time_left_s, 0.0) * float(config.time_bonus_per_s))
	var gain := int(round(float(base) * _multiplier)) + bonus
	add_points(gain)
	return gain


func reset() -> void:
	total_score = 0
	combo = 0
	_multiplier = 1.0
	_combo_timer = 0.0


# --- Ranks ------------------------------------------------------------------

## Rank for the current total: D C B A S S+.
func current_rank() -> StringName:
	return rank_for_score(total_score)


func rank_for_score(score: int) -> StringName:
	if score >= config.rank_s_plus:
		return &"S+"
	if score >= config.rank_s:
		return &"S"
	if score >= config.rank_a:
		return &"A"
	if score >= config.rank_b:
		return &"B"
	if score >= config.rank_c:
		return &"C"
	return &"D"


# --- Frame ------------------------------------------------------------------

## Combo decay: the multiplier only lives while successes keep chaining.
func advance(delta: float) -> void:
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			break_combo()
