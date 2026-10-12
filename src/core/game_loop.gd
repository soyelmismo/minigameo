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
	var match_mgr: Object = _resolve(&"match")
	if match_mgr != null and match_mgr.has_method("advance"):
		match_mgr.advance(delta)
	# The roulette advances while the match is in the ROULETTE state and emits
	# roulette_result(id); MatchManager listens and starts the micro-game
	# (§6.2/§6.6). Without this tick the roulette never resolves and the
	# micro-game would only ever start through the manager's fallback.
	var roulette: Object = _resolve(&"roulette")
	if roulette != null and roulette.has_method("update"):
		roulette.update(delta)
	var minigames: Object = _resolve(&"minigames")
	if minigames != null and minigames.has_method("update"):
		minigames.update(delta)
	var score: Object = _resolve(&"score")
	if score != null and score.has_method("advance"):
		score.advance(delta)
	var impact: Object = _resolve(&"impact")
	if impact != null and impact.has_method("advance"):
		impact.advance(delta)
	# PostFXDirector is deliberately NOT advanced here: it is an autoload and
	# runs its own _process -> advance(delta), and an autoload cannot opt out of
	# that. Advancing it here as well made every post-processing fade run at
	# double the intended rate (the postfx blend was consumed twice per frame).
	# If PostFX ever loses its _process, this is where it must come back.


func _unhandled_input(event: InputEvent) -> void:
	var minigames: Object = _resolve(&"minigames")
	if minigames != null and minigames.has_method("on_input"):
		minigames.on_input(event)


## Resolves a system by its canonical service name through GameServices.
##
## This used to do tree.root.get_node_or_null(name), i.e. it referenced the
## autoloads by node path — the exact pattern AGENTS.md §1.1 forbids, and the
## only place in src/ that still did it. Routing through the registry also
## means a substitution published under the canonical name is honoured here,
## and an unpublished service degrades to null instead of resolving to whatever
## happens to hang off /root with that name.
func _resolve(service_name: StringName) -> Object:
	return GameServices.lookup(service_name)
