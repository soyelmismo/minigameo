extends GutTest
## MatchManager + ScoreDirector tests (scaffold §5 flow, §6.2, §6.3).

func _make_manager() -> Node:
	var mm: Node = load("res://src/match/match_manager.gd").new()
	add_child_autofree(mm)
	return mm


# --- MatchManager state machine ---------------------------------------------

func test_match_starts_at_title() -> void:
	var mm := _make_manager()
	assert_eq(mm.current_state(), mm.State.TITLE, "boot lands on TITLE")


func test_countdown_then_freeroam() -> void:
	var mm := _make_manager()
	mm.start_match()
	assert_eq(mm.current_state(), mm.State.COUNTDOWN)
	mm.advance(mm.config.countdown_s + 0.1)
	assert_eq(mm.current_state(), mm.State.FREE_ROAM, "countdown flows to FREE_ROAM")


func test_roulette_cycle() -> void:
	var mm := _make_manager()
	mm.start_match()
	mm.advance(mm.config.countdown_s + 0.1)
	mm.request_roulette()
	assert_eq(mm.current_state(), mm.State.ROULETTE)
	mm.start_minigame(&"token_rush")
	assert_eq(mm.current_state(), mm.State.MINIGAME)
	mm.finish_minigame(null)
	assert_eq(mm.current_state(), mm.State.STYLE_POP, "finish pops the style")
	mm.advance(1.5)
	assert_eq(mm.current_state(), mm.State.FREE_ROAM, "style pop returns to FREE_ROAM")


func test_match_timer_runs_and_expires() -> void:
	var mm := _make_manager()
	mm.start_match()
	mm.advance(mm.config.countdown_s + 0.1)
	assert_true(mm.clock_running(), "clock runs in FREE_ROAM")
	mm.advance(60.0)
	assert_almost_eq(mm.time_left(), mm.config.match_length_s - 60.0, 0.01)
	mm.advance(mm.config.match_length_s)
	assert_eq(mm.current_state(), mm.State.TIME_UP, "clock hitting 0 ends the match")
	assert_false(mm.clock_running(), "clock stops at TIME_UP")


func test_timer_frozen_during_countdown() -> void:
	var mm := _make_manager()
	mm.start_match()
	mm.advance(1.0)
	assert_almost_eq(mm.time_left(), mm.config.match_length_s, 0.01,
		"countdown must not consume match time")


func test_roulette_timeout_never_deadlocks() -> void:
	var mm := _make_manager()
	mm.start_match()
	mm.advance(mm.config.countdown_s + 0.1)
	mm.request_roulette()
	mm.advance(mm.config.roulette_spin_s + 0.5)
	assert_ne(mm.current_state(), mm.State.ROULETTE,
		"roulette must self-resolve even if no result arrives")


# --- ScoreDirector ------------------------------------------------------------

func _make_score() -> Node:
	var sd: Node = load("res://src/match/score/score_director.gd").new()
	add_child_autofree(sd)
	return sd


func test_score_starts_at_zero() -> void:
	var sd := _make_score()
	assert_eq(sd.total_score, 0)
	assert_eq(sd.current_rank(), &"D")


func test_combo_rises_multiplier() -> void:
	var sd := _make_score()
	sd.register_success()
	sd.register_success()
	assert_eq(sd.combo, 2)
	assert_almost_eq(sd.current_multiplier(), 1.5, 0.001,
		"two successes at combo_step 0.25 give x1.5")


func test_combo_capped() -> void:
	var sd := _make_score()
	for _i in 100:
		sd.register_success()
	assert_almost_eq(sd.current_multiplier(), sd.config.combo_max, 0.001)


func test_break_combo_resets_multiplier() -> void:
	var sd := _make_score()
	sd.register_success()
	sd.register_success()
	sd.break_combo()
	assert_eq(sd.combo, 0)
	assert_almost_eq(sd.current_multiplier(), 1.0, 0.001)


func test_score_minigame_includes_time_bonus() -> void:
	var sd := _make_score()
	var gain: int = sd.score_minigame(1000, 5.0)
	# base * multiplier(1.0) + 5s * 100 bonus
	assert_eq(gain, 1500)
	assert_eq(sd.total_score, 1500)


func test_score_multiplier_applied() -> void:
	var sd := _make_score()
	sd.register_success()  # multiplier 1.25
	var gain: int = sd.score_minigame(1000, 0.0)
	assert_eq(gain, 1250)


func test_combo_timeout_decays() -> void:
	var sd := _make_score()
	sd.register_success()
	sd.advance(sd.config.combo_timeout_s + 0.1)
	assert_eq(sd.combo, 0, "combo expires after the timeout window")


func test_rank_thresholds() -> void:
	var sd := _make_score()
	assert_eq(sd.rank_for_score(0), &"D")
	assert_eq(sd.rank_for_score(sd.config.rank_c), &"C")
	assert_eq(sd.rank_for_score(sd.config.rank_b), &"B")
	assert_eq(sd.rank_for_score(sd.config.rank_a), &"A")
	assert_eq(sd.rank_for_score(sd.config.rank_s), &"S")
	assert_eq(sd.rank_for_score(sd.config.rank_s_plus), &"S+")


func test_reset_clears_everything() -> void:
	var sd := _make_score()
	sd.add_points(9999)
	sd.register_success()
	sd.reset()
	assert_eq(sd.total_score, 0)
	assert_eq(sd.combo, 0)
	assert_eq(sd.current_rank(), &"D")
