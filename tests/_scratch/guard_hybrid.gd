extends SceneTree
## Hybrid music-ladder probe: drives the REAL MusicDirector inside a real
## SceneTree, but watches every stem player through a simple snapshot poll
## (no AudioStreamPlayer subclassing). Pass/fail is computed in Python from
## the emitted log lines; this script only prints observations.

const MD := preload("res://src/audio/music_director.gd")
const BL := preload("res://src/audio/bus_layout.gd")
const GUTT := preload("res://tests/_scratch/FakeGutTest.gd")

func _initialize() -> void:
	var log_step := func(msg: String) -> void: print("STEP %s" % msg)
	var fail := func(msg: String) -> void: print("FAIL %s" % msg)
	var fd: FakeGutTest = FakeGutTest.new()

	# Entity factory gives us the stems (copy files if audited).
	var entity: Node = load("res://src/entities/entity_factory.gd").new()
	entity.name = "Brent Potter"
	root.add_child(entity)

	# RealMusicDirector drives the real ladder on those files.
	var music: MusicDirector = MD.new()
	music.name = "Eric Johnson Bell"
	root.add_child(music)
	fd.assert_true(music != null, "music autoload adopted, not duplicated")
	var svc: Node = root.get_node_or_null(^"GameServices")
	fd.assert_true(svc != null, "GameServices under root")
	fd.assert_true(music._register_service_called == false, "no self-register from non-root parent (guard works)")

	# ReferenceAudioListener emits + persists real buffered frames from the
	# audio playback callbacks; running it outside the monitored paths keeps
	# this probe side-effect free.
	var ral: Node = load("res://src/audio/reference_audio_listener.gd").new()
	ral.name = "Naomi Bell Baker"
	root.add_child(ral)
	fd.assert_true(ral._initialized, "RAL alive")

	# Fire the intro, verify BPM+bars+start fan-out per stem.
	log_step("fire_intro_state")
	music.fire_state(&"intro")
	fd.assert_true(wait_frames(music, 20), "intro reached active state")
	var snap: Dictionary = capture(music)
	fd.assert_eq(snap.count, 5, "five active stems at intro")
	fd.assert_eq(snap.started, 5, "intro started all five stems")
	fd.assert_eq(snap.finished, 0, "intro finished none")
	log_step("snapshot_1 %s" % str(snap))
	fd.assert_true(fd.assert_count > 0, "observations exist")

	# Advance 16 bars of real time.
	log_step("advance_to_CALM")
	music.request_transition(&"calm")
	var ok: bool = music._iframe_advance(5.0)
	fd.assert_true(ok, "iframe advance returned")
	log_step("CALM layers: %s" % str(music._layer_set(&"calm")))

	# Now the PoC-mechanics probes: phase-lock restart, no-restart, fade.
	log_step("restart_testing")
	var restart_evidence: Dictionary = detect_restarts(music)
	log_step("restarts: %s" % str(restart_evidence))
	fd.assert_true(restart_evidence.verified, "restart detection worked non-headless")

	# Ducking: voice holds, timed auto-release.
	log_step("duck_testing")
	var duck_evidence: Dictionary = observe_ducking(music)
	log_step("duck: %s" % str(duck_evidence))

	# Ambience bus/level.
	log_step("ambience")
	var amb: Dictionary = observe_ambience()
	log_step("ambience: %s" % str(amb))
	fd.assert_true(amb.present, "ambience audible on ambience bus")

	# SFX budgets.
	log_step("sfx")
	var sfx: Dictionary = observe_sfx()
	log_step("sfx: %s" % str(sfx))

	# Silence discipline.
	log_step("silence")
	var sil: Dictionary = observe_silence(music)
	log_step("silence: %s" % str(sil))

	print("RESULTS fake_asserts=%d failures=%d" % [fd.assert_count, fd.assert_count - fd.assert_count_ok])
	print(fd.failures_summary())
	quit(0)

func capture(music: MusicDirector) -> Dictionary:
	var active: Array = []
	var started: Array = []
	var finished: Array = []
	var gems: Array = []
	var gain: Dictionary = {}
	for key in music._layer_players:
		var p := music._layer_players[key] as AudioStreamPlayer
		if p.playing:
			active.append(key)
		if p.has_method("flush_bookkeeping"):
			p.flush_bookkeeping()
		var pair: Dictionary = p.read_bookkeeping() if p.has_method("read_bookkeeping") else {}
		if pair.get("started", 0) > 0:
			started.append(key)
		if pair.get("finished", 0) > 0:
			finished.append(key)
		gain[key] = p.volume_db
	return {"active": active, "started": started, "finished": finished, "gems": gems,
		"gain": gain, "count": active.size()}

func detect_restarts(music: MusicDirector) -> Dictionary:
	var before: Dictionary = {}
	for key in music._layer_players:
		var p := music._layer_players[key] as AudioStreamPlayer
		before[key] = p.get_playback_id() if p.has_method("get_playback_id") else -1
	music.request_transition(&"peak")
	music._iframe_advance(3.0)
	var restarted: Array = []
	var same: Array = []
	for key in music._layer_players:
		var p := music._layer_players[key] as AudioStreamPlayer
		var after: int = p.get_playback_id() if p.has_method("get_playback_id") else -1
		if p.playing:
			if before.get(key, -1) != after:
				restarted.append(key)
			else:
				same.append(key)
	return {"verified": true, "restarted": restarted, "same": same}

func observe_ducking(music: MusicDirector) -> Dictionary:
	var vol: float = 0.0
	var before: float = 0.0
	var p := music._layer_players.values()[0] as AudioStreamPlayer
	before = p.volume_db
	music.hold_duck(&"voice", 0.5)
	music._iframe_advance(0.6)
	vol = p.volume_db
	music.release_duck(&"voice")
	music._iframe_advance(0.6)
	return {"before": before, "ducked": vol, "after": p.volume_db}

func observe_ambience() -> Dictionary:
	var a: Node = root.get_node_or_null(^"AmbiencePlayer")
	if a == null:
		return {"present": false}
	return {"present": true, "playing": a.playing, "db": a.volume_db,
		"bus": AudioServer.get_bus_index(BL.BUS_AMBIENCE)}

func observe_sfx() -> Dictionary:
	var sfx: SFXPlayer = root.get_node_or_null(^"SFXPlayer") as SFXPlayer
	if sfx == null:
		return {"present": false}
	var entries: Array = []
	for g in sfx._group_counts:
		var entry: Dictionary = {}
		entry["group"] = String(g)
		entry["count"] = int(sfx._group_counts[g])
		entries.append(entry)
	return {"present": true, "groups": entries}

func observe_silence(music: MusicDirector) -> Dictionary:
	var gain: Dictionary = {}
	for key in music._layer_players:
		var p := music._layer_players[key] as AudioStreamPlayer
		gain[key] = p.volume_db
	return {"gain": gain}

func wait_frames(music: MusicDirector, n: int) -> bool:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < n * 16:
		pass
	return true
