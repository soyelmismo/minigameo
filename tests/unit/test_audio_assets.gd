extends "res://addons/gut/test.gd"
## Audio asset gate (AGENTS.md §1.5 / §11).
##
## The audio *system* (buses, MusicDirector, SFXPlayer, VoiceDirector) already
## exists and is tested elsewhere (test_audio_buses.gd, test_sfx_player.gd).
## This test guards the ASSETS that system plays: every synthesized file must
## exist, be non-empty on disk, import as an AudioStreamWAV, and carry the
## properties the runtime depends on:
##
##   - music stems + ambience  -> stereo, forward-looped (MusicDirector calls
##     play() on a layer and never stops it), 128 BPM bar math => 7.5 s / 4 s.
##   - SFX                     -> mono, loop disabled (one-shots).
##
## A missing or mis-configured asset would otherwise be a silent runtime
## regression: MusicDirector logs once and skips, so the game just loses its
## music without failing anything.
##
## Headless-safe: FileAccess + load() only, no audio playback or GPU work.
##
## Naming note: local variables avoid `name`/`path` because Node already
## declares those properties and the project treats shadowing as an error.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"

# The five vertical layers MusicDirector mixes, plus the pre-mixed fallback.
const MUSIC_STEMS: Array[String] = [
	"music_drums.wav",
	"music_bass.wav",
	"music_lead.wav",
	"music_harmony.wav",
	"music_fx.wav",
	"music_full.wav",
]

# Every SFX id the catalog/gameplay refers to. The eight the brief mandates
# first, then the four ImpactFrame tiers (src/juice/presets/) and the extras
# the match flow triggers (ui_hover, countdown_go, powerup_spawn, combo).
const SFX_FILES: Array[String] = [
	"sfx_pickup.wav",
	"sfx_jump.wav",
	"sfx_hit.wav",
	"sfx_fail.wav",
	"sfx_score.wav",
	"sfx_ui_click.wav",
	"sfx_roulette.wav",
	"sfx_countdown.wav",
	"sfx_impact_light.wav",
	"sfx_impact_medium.wav",
	"sfx_impact_heavy.wav",
	"sfx_impact_critical.wav",
	"sfx_ui_hover.wav",
	"sfx_countdown_go.wav",
	"sfx_powerup_spawn.wav",
	"sfx_combo.wav",
]

const AMBIENCE_FILES: Array[String] = [
	"amb_city_loop.wav",
]

# Brief: 4-8 s stems at 128 BPM. 4 bars of 4/4 @ 128 BPM = 7.5 s.
const MUSIC_LOOP_S: float = 7.5
# Brief: 2-4 s ambience loop.
const AMBIENCE_LOOP_S: float = 4.0
# Brief: SFX are one-shots between 0.1 s and 1.0 s.
const SFX_MIN_S: float = 0.1
const SFX_MAX_S: float = 1.0

# GameConfig.music_bpm — the stems must stay in step with the beat clock.
const EXPECTED_MIX_RATE: int = 44100


func test_every_asset_exists_and_is_not_empty() -> void:
	for file in _all_files():
		var full: String = _dir_for(file) + file
		assert_true(FileAccess.file_exists(full), "%s exists on disk" % file)
		var handle := FileAccess.open(full, FileAccess.READ)
		assert_not_null(handle, "%s is readable" % file)
		if handle == null:
			continue
		var size: int = handle.get_length()
		handle.close()
		assert_gt(size, 0, "%s is not empty (%d bytes)" % [file, size])


func test_every_asset_imports_as_audio_stream_wav() -> void:
	# load() goes through Godot's importer, so this also proves the .import
	# sidecar and the generated .sample are valid.
	for file in _all_files():
		var res: Resource = load(_dir_for(file) + file)
		assert_not_null(res, "%s imports" % file)
		if res == null:
			continue
		var stream := res as AudioStreamWAV
		assert_not_null(stream, "%s is an AudioStreamWAV (got %s)" % [file, res.get_class()])


func test_assets_use_the_expected_sample_rate() -> void:
	for file in _all_files():
		var stream: AudioStreamWAV = load(_dir_for(file) + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		assert_eq(stream.mix_rate, EXPECTED_MIX_RATE,
				"%s is %d Hz (matches the project's audio rate)" % [file, EXPECTED_MIX_RATE])


func test_music_stems_are_stereo_and_forward_looped() -> void:
	# MusicDirector._set_layer_audible() calls p.play() on a layer and never
	# stops it: a non-looping stem would go silent after 7.5 s of match time.
	for file in MUSIC_STEMS:
		var stream: AudioStreamWAV = load(MUSIC_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		assert_true(stream.stereo, "%s is stereo (brief: music is stereo)" % file)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD,
				"%s loops forward, so the layer never drops out" % file)


func test_all_stems_share_one_loop_length() -> void:
	# Interchangeability: layers are switched on 2-bar boundaries, so every
	# stem must cover exactly the same number of bars. A length mismatch is
	# phase drift the director cannot correct.
	var reference: float = -1.0
	for file in MUSIC_STEMS:
		var stream: AudioStreamWAV = load(MUSIC_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		var length: float = stream.get_length()
		if reference < 0.0:
			reference = length
		assert_almost_eq(length, reference, 0.001,
				"%s is %.3f s, the same loop length as every other stem" % [file, length])
	assert_almost_eq(reference, MUSIC_LOOP_S, 0.05,
			"the stems are %.3f s long (4 bars @ 128 BPM, brief asks for 4-8 s)" % reference)


func test_music_stems_carry_actual_samples() -> void:
	# A valid header with an empty buffer would import fine and play silence.
	for file in MUSIC_STEMS:
		var stream: AudioStreamWAV = load(MUSIC_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		var channels: int = 2 if stream.stereo else 1
		assert_gt(stream.data.size(), channels * 2 * int(MUSIC_LOOP_S * EXPECTED_MIX_RATE * 0.9),
				"%s has a full-length PCM buffer (%d bytes)" % [file, stream.data.size()])


func test_ambience_loops_and_is_long_enough() -> void:
	for file in AMBIENCE_FILES:
		var stream: AudioStreamWAV = load(AMBIENCE_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		assert_true(stream.stereo, "%s is stereo" % file)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % file)
		var length: float = stream.get_length()
		assert_true(length >= 2.0 and length <= 4.0,
				"%s is %.2f s (brief asks for 2-4 s)" % [file, length])


func test_sfx_are_mono_and_not_looping() -> void:
	# SFX are one-shots played through SFXPlayer's pool: mono keeps the voice
	# count affordable, and a looping SFX would never release its voice.
	for file in SFX_FILES:
		var stream: AudioStreamWAV = load(SFX_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		assert_false(stream.stereo, "%s is mono (brief: SFX are mono)" % file)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED,
				"%s does not loop" % file)


func test_sfx_are_inside_the_brief_duration_window() -> void:
	for file in SFX_FILES:
		var stream: AudioStreamWAV = load(SFX_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		var length: float = stream.get_length()
		assert_true(length >= SFX_MIN_S and length <= SFX_MAX_S,
				"%s is %.3f s (brief asks for %.1f-%.1f s)" % [file, length, SFX_MIN_S, SFX_MAX_S])


func test_sfx_carry_actual_samples() -> void:
	for file in SFX_FILES:
		var stream: AudioStreamWAV = load(SFX_DIR + file)
		if stream == null:
			assert_true(false, "%s loads" % file)
			continue
		assert_gt(stream.data.size(), 0, "%s has a PCM buffer" % file)


func test_the_briefs_minimum_asset_set_is_present() -> void:
	# Explicit regression guard for the deliverable: 6 stems + 8 SFX + 1 ambience.
	assert_gte(MUSIC_STEMS.size(), 6, "at least 6 music stems")
	assert_gte(SFX_FILES.size(), 8, "at least 8 SFX")
	assert_gte(AMBIENCE_FILES.size(), 1, "at least 1 ambience loop")


# --- helpers ---

func _dir_for(file: String) -> String:
	if file.begins_with("music_"):
		return MUSIC_DIR
	if file.begins_with("amb_"):
		return AMBIENCE_DIR
	return SFX_DIR


func _all_files() -> Array[String]:
	var out: Array[String] = []
	out.append_array(MUSIC_STEMS)
	out.append_array(AMBIENCE_FILES)
	out.append_array(SFX_FILES)
	return out
