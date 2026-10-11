extends GutTest
## End-to-end audio pipeline (scaffold §6.8/§6.9/§6.10, §10.2, and the audio
## brief): the parts of the chain that are NOT the music ladder.
##
## The music ladder's musical contract lives in test_music_ladder.gd. What is
## pinned here is everything the player would hear AROUND it:
##
##   - every asset the code refers to actually resolves (a missing wav is a
##     silent hole: the directors log once and skip, nothing else fails);
##   - the announcer ducks the music while it speaks and gives it back when
##     the line ends (the duck must LAND, not creep);
##   - an impact frame's bare AudioStream is routed from GameConfig data and
##     actually plays;
##   - the ambience bed is bound, playing, and sitting under the mix;
##   - the ladder POLICY climbs and falls the way the brief describes:
##     freeroam calm -> roulette riser -> micro-game euphoric -> FAIL ->
##     TRIUMPH, and the freeroam tiers never fight a running micro-game.
##
## Everything is measured on real assets and real instances: no mocked streams
## where a real file exists, so a missing import cannot pass silently.

const AUDIO_SCRIPT := "res://src/audio/audio_director.gd"
const MUSIC_SCRIPT := "res://src/audio/music_director.gd"
const VOICE_SCRIPT := "res://src/audio/voice_director.gd"
const VOICE_LINES_SCRIPT := "res://src/audio/voice_lines.gd"
const SFX_SCRIPT := "res://src/audio/sfx_player.gd"
const GAME_CONFIG := "res://src/core/config/game_config.tres"

const FRAME_S: float = 1.0 / 60.0


## --- helpers ---

func _music() -> Object:
	var music: Object = load(MUSIC_SCRIPT).new()
	add_child_autofree(music)
	return music


func _voice(music: Object) -> Object:
	var voice: Object = load(VOICE_SCRIPT).new()
	add_child_autofree(voice)
	voice.setup(load(VOICE_LINES_SCRIPT).new())
	voice.set("music_director", music)
	return voice


## An AudioDirector wired to a PRIVATE MusicDirector, so a ladder assertion
## never mutates the MusicDirector autoload the rest of the run shares.
func _wired() -> Object:
	var director: Object = load(AUDIO_SCRIPT).new()
	add_child_autofree(director)
	var music: Object = _music()
	director.set("music_director", music)
	return director


func _settle(music: Object) -> void:
	# Run the beat clock to the next bar boundary (where a pending switch
	# lands) and then through the crossfade, so every ramp has finished.
	for _i in range(600):
		music.advance(FRAME_S)
		if not music.has_pending_switch():
			break
	for _i in range(int(float(music.crossfade_s()) * 60.0) + 4):
		music.advance(FRAME_S)


func _fail_result() -> MinigameResult:
	return MinigameResult.make(false, 0, 0, 0, &"TIMEOUT")


## --- Assets: a missing file must not be able to pass unnoticed ---

func test_every_sfx_catalog_id_resolves_and_routes() -> void:
	var lib := SFXLibrary.new()
	assert_gt(lib.register_defaults(), 0, "the default catalog registers")
	var ids: Array = lib.ids()
	assert_gt(ids.size(), 0, "the catalog declares ids")
	var resolved: int = 0
	for entry: Variant in ids:
		var id: StringName = entry as StringName
		var stream: AudioStream = lib.get_stream(id)
		assert_not_null(stream, "'%s' resolves to audio" % String(id))
		if stream != null:
			resolved += 1
		# Bus / priority / cooldown are data, and the bus must be a real one.
		assert_true(BusLayout.is_layout_bus(lib.get_bus(id)),
			"'%s' routes to a layout bus" % String(id))
		assert_gte(lib.get_priority(id), 0, "'%s' declares a priority" % String(id))
		assert_gte(lib.get_cooldown_s(id), 0.0, "'%s' declares a cooldown" % String(id))
	assert_eq(resolved, ids.size(),
		"every catalog id loads real audio (%d of %d)" % [resolved, ids.size()])


func test_every_impact_tier_is_registered_as_impact_group_audio() -> void:
	var lib := SFXLibrary.new()
	lib.register_defaults()
	for id: StringName in [
		&"sfx_impact_light", &"sfx_impact_medium",
		&"sfx_impact_heavy", &"sfx_impact_critical",
	]:
		assert_true(lib.has(id), "the impact tier '%s' is in the catalog" % String(id))
		assert_not_null(lib.get_stream(id), "'%s' loads" % String(id))
		assert_eq(lib.get_group(id), &"impact", "'%s' is an impact group entry" % String(id))
		assert_eq(lib.get_bus(id), BusLayout.BUS_IMPACT, "'%s' routes to Impact" % String(id))


func test_every_announcer_line_has_real_audio() -> void:
	var voice: Object = load(VOICE_SCRIPT).new()
	var events: Array = VoiceLines.event_ids()
	assert_gt(events.size(), 0, "the catalog declares announcer events")
	var resolved: int = 0
	for entry: Variant in events:
		var id: StringName = entry as StringName
		var stream: AudioStream = voice._resolve_vo_stream(id)
		assert_not_null(stream, "the line for '%s' resolves to audio" % String(id))
		if stream != null:
			resolved += 1
	assert_eq(resolved, events.size(),
		"every event id has a rendered line (%d of %d)" % [resolved, events.size()])


func test_the_ambience_bed_is_bound_and_playing_under_the_mix() -> void:
	var director: Object = load(AUDIO_SCRIPT).new()
	add_child_autofree(director)
	var bed: AudioStreamPlayer = director.ambience_player
	assert_not_null(bed, "the bed exists")
	if bed == null:
		return
	assert_not_null(bed.stream, "the bed has audio")
	assert_true(bed.playing, "the bed is playing")
	assert_eq(String(bed.bus), String(BusLayout.BUS_AMBIENCE),
		"the bed is on the Ambience bus (the reverb send)")
	assert_lt(director.ambience_volume_db(), 0.0,
		"the bed sits under the music so it never masks it")


## --- Voice ducking: the announcer must never fight the music ---

func test_the_announcer_ducks_the_music_and_hands_it_back() -> void:
	var music: Object = _music()
	var voice: Object = _voice(music)
	var fade_s: float = float(voice.get("duck_fade_s"))
	assert_true(voice.speak(&"match_start"), "the announcer speaks")
	var landed: int = 0
	for _i in range(int(fade_s * 60.0) + 4):
		music.advance(FRAME_S)
		if is_equal_approx(float(music.duck_gain_db()), -10.0):
			landed += 1
	assert_almost_eq(float(music.duck_gain_db()), -10.0, 0.0001,
		"the duck lands exactly on -10 dB")
	assert_gt(landed, 0, "the duck arrived inside the declared fade (no creep)")
	# The line ends: the bed comes back by the same fade, to 0 dB exactly.
	voice.stop()
	for _i in range(int(fade_s * 60.0) + 4):
		music.advance(FRAME_S)
	assert_almost_eq(float(music.duck_gain_db()), 0.0, 0.0001,
		"the release lands at 0 dB, so the music is loud again after the line")


func test_the_duck_is_held_while_speaking_and_released_once() -> void:
	var music: Object = _music()
	var voice: Object = _voice(music)
	var fade_s: float = float(voice.get("duck_fade_s"))
	voice.speak(&"match_start")
	for _i in range(int(fade_s * 60.0) + 4):
		music.advance(FRAME_S)
	assert_true(voice.is_speaking(), "the line is on the air")
	# A fade-only duck holds: several seconds later the bed is still dipped.
	for _i in range(120):
		music.advance(FRAME_S)
	assert_almost_eq(float(music.duck_gain_db()), -10.0, 0.0001,
		"the duck holds until the line ends, it does not release early")


## --- Impact frames: a bare stream still has to be routed and played ---

func test_impact_routing_is_data_from_the_config() -> void:
	var player: Object = load(SFX_SCRIPT).new()
	add_child_autofree(player)
	var cfg: Resource = load(GAME_CONFIG)
	assert_not_null(cfg, "the game config resolves")
	if cfg == null:
		return
	assert_eq(String(player.impact_bus), String(cfg.get("impact_sfx_bus")),
		"the impact bus comes from the config, not from code")
	assert_eq(String(player.impact_group), String(cfg.get("impact_sfx_group")),
		"the impact group comes from the config")
	assert_eq(player.impact_priority, int(cfg.get("impact_sfx_priority")),
		"the impact priority comes from the config")
	assert_almost_eq(float(player.impact_volume_db), float(cfg.get("impact_sfx_volume_db")),
		0.001, "the impact level comes from the config")


func test_an_impact_plays_and_releases_its_voice() -> void:
	var player: Object = load(SFX_SCRIPT).new()
	player.library = SFXLibrary.new()
	player.max_voices = 4
	add_child_autofree(player)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.05
	var voice: AudioStreamPlayer = player.play_impact(stream)
	assert_not_null(voice, "the impact acquires a voice from the pool")
	if voice == null:
		return
	assert_true(voice.playing,
		"the impact stream is playing: a configured-but-never-started voice is silent")
	assert_eq(String(voice.bus), String(player.impact_bus),
		"the impact plays on the configured bus")
	assert_eq(player.playing_voices(), 1, "the impact occupies a voice")
	# Bookkeeping round-trip: the group that was incremented must be the one
	# that is decremented, or the impact group cap saturates forever.
	var group: StringName = player.impact_group
	assert_eq(int(player._group_counts.get(group, 0)), 1,
		"the resolved impact group counts the voice")
	player._on_voice_finished(voice, &"", group)
	assert_eq(int(player._group_counts.get(group, 0)), 0,
		"the counter comes back down when the voice finishes")


func test_impact_voices_come_from_the_shared_pool() -> void:
	# Stealing is the policy for a saturated pool (§10.2), and an impact is
	# high priority data: it must not be dropped when the pool is busy.
	var player: Object = load(SFX_SCRIPT).new()
	player.library = SFXLibrary.new()
	player.max_voices = 1
	add_child_autofree(player)
	var busy := AudioStreamGenerator.new()
	busy.mix_rate = 44100.0
	busy.buffer_length = 0.05
	player.set_group_cap(&"world", 0)
	var lib: SFXLibrary = player.library
	lib.register(&"pad", {"group": &"world", "priority": 5})
	lib.set_stream(&"pad", busy)
	assert_not_null(player.play(&"pad"), "the pool is occupied by a low priority voice")
	var hit := AudioStreamGenerator.new()
	hit.mix_rate = 44100.0
	hit.buffer_length = 0.05
	assert_not_null(player.play_impact(hit), "a higher priority impact still gets a voice")
	player.stop_all()


## --- The ladder POLICY, as the player climbs it ---

func test_freeroam_is_calm_and_grows_with_the_combo() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	assert_eq(String(music.current_state), "CALM", "freeroam is the calm state")
	assert_eq((music.layers_for_intensity(music.intensity) as Array).size(), 1,
		"the calm floor is the drums alone")
	# The combo raises the bed inside the CALM band...
	director._on_combo_changed(3)
	assert_eq((music.layers_for_intensity(music.intensity) as Array).size(), 2,
		"a combo of 3 brings the bass in (0.15 + 3*0.05 = 0.30)")
	# ...but never out of it: freeroam must not sound like a micro-game.
	director._on_combo_changed(50)
	assert_lt(float(music.intensity), 0.6,
		"the freeroam ceiling stays under the lead gate")
	assert_eq((music.layers_for_intensity(music.intensity) as Array).size(), 2,
		"the freeroam bed stays drums + bass even at a huge combo")


func test_the_roulette_rises_to_tension() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	director._on_roulette_started()
	assert_eq(String(music.current_state), "TENSION", "the wheel is a riser")
	assert_eq((music.layers_for_intensity(music.intensity) as Array).size(), 3,
		"tension is drums + bass + lead")


func test_the_last_thirty_seconds_escalate_once() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	director._on_match_tick(20.0)
	assert_eq(String(music.current_state), "TENSION", "the endgame escalates")
	# The escalation is one-shot: a later tick must not re-trigger or drop it.
	director._on_match_tick(10.0)
	assert_eq(String(music.current_state), "TENSION", "the ladder holds at tension")


func test_a_micro_game_owns_the_music_and_the_freeroam_tiers_do_not_fight_it() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	# MinigameDirector requests the micro-game's own music_state on the
	# MusicDirector autoload; the micro-game's metadata carries it.
	music.play_music_state(&"PEAK")
	director._on_minigame_started(&"token_rush")
	assert_true(bool(director.get("_minigame_music")), "the micro-game owns the music")
	# Combo and match ticks land while it runs: neither may pull the bed down.
	director._on_combo_changed(50)
	director._on_match_tick(5.0)
	assert_eq(String(music.current_state), "PEAK",
		"the freeroam tiers cannot fight a running micro-game")
	_settle(music)
	for layer: StringName in [&"drums", &"bass", &"lead", &"harmony", &"fx"]:
		assert_true(music.layer_is_audible(layer),
			"'%s' is audible at the euphoric ceiling" % String(layer))


func test_a_failed_micro_game_drops_to_fail_and_the_match_resolves() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	music.play_music_state(&"PEAK")
	director._on_minigame_started(&"token_rush")
	director._on_minigame_finished(_fail_result())
	assert_eq(String(music.current_state), "FAIL", "a failure drops to FAIL")
	assert_eq((music.layers_for_intensity(music.intensity) as Array).size(), 2,
		"FAIL is austere: drums + bass under the announcer")
	director._on_match_time_up()
	assert_eq(String(music.current_state), "TRIUMPH", "TIME_UP celebrates")
	assert_true(bool(music.layers_for_intensity(music.intensity).has(&"fx")),
		"TRIUMPH is the full stack")


func test_impacts_duck_the_music_by_weight() -> void:
	var director: Object = _wired()
	var music: Object = director.get("music_director")
	director._on_match_started()
	director._on_impact_requested(0)
	assert_almost_eq(float(music.duck_gain_db()), 0.0, 0.0001,
		"a light impact does not dip the bed")
	director._on_impact_requested(3)
	# The duck lands inside its own fade (0.2 s), BEFORE the 0.45 s hold
	# expires: sampling later catches the release instead of the arrival.
	for _i in range(15):
		music.advance(FRAME_S)
	assert_almost_eq(float(music.duck_gain_db()), -8.0, 0.0001,
		"the critical duck lands exactly, by weight")
	# A timed duck must also release itself once its hold is over.
	for _i in range(60):
		music.advance(FRAME_S)
	assert_almost_eq(float(music.duck_gain_db()), 0.0, 0.0001,
		"an impact duck releases on its own")


func test_the_impact_group_cap_is_registered_for_the_configured_group() -> void:
	var director: Object = _wired()
	var sfx: Object = director.get("sfx_player")
	if sfx == null:
		return
	var group: StringName = sfx.impact_group
	assert_gt(int(sfx._group_caps.get(group, 0)), 0,
		"the configured impact group is capped, so a burst cannot saturate the pool")
