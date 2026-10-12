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

## World-space "+points" popups (scaffold §6.3). They go through an ObjectPool
## rather than queue_free: a scoring burst during a micro-game would otherwise
## allocate and free several Label3D nodes per second (§1.4, §7 budgets).
const POPUP_SCENE_PATH := "res://src/match/score/score_popup.tscn"
const POPUP_POOL_MAX := 24

var _popup_scene: PackedScene = null
var _popup_pool: ObjectPool = null
var _popups: Array[Node] = []


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"score") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("ScoreDirector", &"score", self)
	config = _load_config()


func _load_config() -> GameConfig:
	var cfg: Object = GameServices.lookup(&"config")
	if cfg is GameConfig:
		return cfg as GameConfig
	var loaded := load("res://src/core/config/game_config.tres") as GameConfig
	return loaded if loaded != null else GameConfig.new()


# --- Combo ------------------------------------------------------------------

## The multiplier step the HUD reads instead of carrying its own literal
## (§1.3: one source of truth, and it lives in the .tres).
func combo_step() -> float:
	return config.combo_step if config != null else 0.25


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
	spawn_score_popup(points)


## Shows a world-space "+points" near the player, reusing a pooled instance
## (AGENTS.md §1.4/§7: no queue_free in hot paths). The pool and its parent are
## resolved lazily, so a headless run without those nodes simply shows nothing
## instead of failing.
func spawn_score_popup(points: int) -> void:
	var scene: PackedScene = _popup_scene_or_null()
	var parent: Node = _resolve_popup_parent()
	if parent == null or scene == null:
		return
	if _popup_pool == null:
		_popup_pool = ObjectPool.new(scene, parent, POPUP_POOL_MAX, true)
	var popup: Node = _popup_pool.acquire()
	if popup == null or not popup.has_method("arm"):
		return
	popup.call("arm", points, _resolve_player_position())
	_popups.append(popup)


## Drives the popup rise/fade and releases the finished ones back to the pool.
func _advance_popups(delta: float) -> void:
	for i: int in range(_popups.size() - 1, -1, -1):
		var popup: Node = _popups[i]
		if not is_instance_valid(popup):
			_popups.remove_at(i)
			continue
		popup.call("advance", delta)
		if popup.has_method("is_finished") and bool(popup.call("is_finished")):
			if _popup_pool != null:
				_popup_pool.release(popup)
			_popups.remove_at(i)


## Score a finished micro-game: base + combo multiplier + time bonus.
func score_minigame(base: int, time_left_s: float) -> int:
	var bonus := int(maxf(time_left_s, 0.0) * float(config.time_bonus_per_s))
	var gain := int(round(float(base) * _multiplier)) + bonus
	add_points(gain)
	return gain


## A finished micro-game reported through the MinigameResult contract
## (scaffold §7.4). This is the adapter between the minigame's result and the
## director's own rules, so a micro-game never has to know how scoring works:
## it reports success/base/time bonus, the director decides the multiplier.
func add_minigame_result(result: MinigameResult) -> int:
	if result == null:
		return 0
	if result.success:
		register_success()
	else:
		break_combo()
	# The multiplier applies to the base only; the time bonus is already
	# derived from the archetype's ObjectiveRecipe and joins unscaled.
	var gain := int(round(float(maxi(0, result.base_score)) * _multiplier))
	gain += maxi(0, result.time_bonus)
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
	_advance_popups(delta)


# --- Score popups ----------

## The scene the popups are built from. Loaded lazily so a missing scene only
## disables the visual layer, never the scoring.
func _popup_scene_or_null() -> PackedScene:
	if _popup_scene == null:
		_popup_scene = load(POPUP_SCENE_PATH) as PackedScene
	return _popup_scene


## The node the popups hang from: the world root of the running scene, so a
## popup is positioned in the same space as the player.
func _resolve_popup_parent() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("World")


## Where a popup should appear: just above the player when one exists, otherwise
## the world origin.
func _resolve_player_position() -> Vector3:
	var player: Object = GameServices.lookup(&"player")
	if player is Node3D:
		return (player as Node3D).global_position
	return Vector3.ZERO
