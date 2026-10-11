extends Node
## GameLoopDriver — single per-frame tick for all match systems (§6).
##
## The MatchManager clock, ScoreDirector combo decay, ImpactDirector
## hitstop/slow-mo, PostFXDirector fades and the MinigameDirector update
## are all advanced HERE, once per frame, in a fixed order. Autoloads run
## their own _process for camera/music/style; the systems that must be
## deterministic (match clock, minigame runtime) are driven explicitly.
##
## Order matters (§1.1): clock first, then gameplay, then juice.

func _physics_process(delta: float) -> void:
	var match_mgr: Object = _resolve(&"MatchManager")
	if match_mgr != null and match_mgr.has_method("advance"):
		match_mgr.advance(delta)
	# The roulette advances while the match is in the ROULETTE state and emits
	# roulette_result(id); MatchManager listens and starts the micro-game
	# (§6.2/§6.6). Without this tick the roulette never resolves and the
	# micro-game would only ever start through the manager's fallback.
	var roulette: Object = _resolve(&"RouletteController")
	if roulette != null and roulette.has_method("update"):
		roulette.update(delta)
	var minigames: Object = _resolve(&"MinigameDirector")
	if minigames != null and minigames.has_method("update"):
		minigames.update(delta)
	var score: Object = _resolve(&"ScoreDirector")
	if score != null and score.has_method("advance"):
		score.advance(delta)
	var impact: Object = _resolve(&"ImpactDirector")
	if impact != null and impact.has_method("advance"):
		impact.advance(delta)
	var postfx: Object = _resolve(&"PostFXDirector")
	if postfx != null and postfx.has_method("advance"):
		postfx.advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	var minigames: Object = _resolve(&"MinigameDirector")
	if minigames != null and minigames.has_method("on_input"):
		minigames.on_input(event)


func _resolve(node_name: StringName) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var node: Node = tree.root.get_node_or_null(String(node_name))
	return node as Object
