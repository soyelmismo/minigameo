extends GutTest
## StylePack / StylePostFX / ImpactFrame resource + director tests
## (scaffold §7.5, §7.6, §9, §10.1).

const PACK_DIR := "res://src/styles/packs/"
const PACK_IDS: Array[StringName] = [
	&"neon_drift", &"ink_noir", &"toon_pop", &"vhs_90", &"bit_crush",
	&"chrome_beam", &"candy_plastic", &"kaiju_sofvi", &"sprite_25d",
	&"paper_craft", &"gold_rush", &"watercolor",
]


func test_all_12_style_packs_load_with_sane_fields() -> void:
	assert_eq(PACK_IDS.size(), 12, "scaffold §9 defines exactly 12 packs")
	for pack_id: StringName in PACK_IDS:
		var pack := load(PACK_DIR + String(pack_id) + ".tres") as StylePack
		assert_not_null(pack, "pack '%s' must load" % pack_id)
		if pack == null:
			continue
		assert_ne(pack.id, &"", "%s: id set" % pack_id)
		assert_ne(pack.display_name, "", "%s: display_name set" % pack_id)
		assert_not_null(pack.postfx, "%s: postfx profile present" % pack_id)
		assert_true(
			pack.material_mode == &"SHADER_UNIFORM"
			or pack.material_mode == &"FULL_SWAP"
			or pack.material_mode == &"OVERLAY",
			"%s: valid material_mode" % pack_id
		)
		assert_true(pack.transition_s > 0.0, "%s: transition_s > 0" % pack_id)
		assert_true(
			pack.music_state in [&"CALM", &"TENSION", &"PEAK", &"TRIUMPH", &"FAIL", &""],
			"%s: valid music_state" % pack_id
		)


func test_style_postfx_lerp() -> void:
	var a := StylePostFX.new()
	a.bloom_intensity = 0.0
	a.saturation = 0.0
	var b := StylePostFX.new()
	b.bloom_intensity = 1.0
	b.saturation = 2.0
	var mid: StylePostFX = a.lerp_to(b, 0.5)
	assert_almost_eq(mid.bloom_intensity, 0.5, 0.001)
	assert_almost_eq(mid.saturation, 1.0, 0.001)
	var end: StylePostFX = a.lerp_to(b, 1.0)
	assert_almost_eq(end.bloom_intensity, 1.0, 0.001)


func test_style_director_degrades_headless() -> void:
	var dir: Node = load("res://src/styles/style_director.gd").new()
	add_child_autofree(dir)
	# No WorldEnvironment in the test scene: apply must not crash.
	dir.apply_pack_id(&"NEON_DRIFT")
	assert_eq(dir.current_pack().id, &"NEON_DRIFT", "pack applied even without env")
	dir.revert_to_base()
	assert_null(dir.current_pack(), "revert clears the active pack")
	assert_false(dir.is_styled())


func test_style_director_unknown_pack_warns_not_crashes() -> void:
	var dir: Node = load("res://src/styles/style_director.gd").new()
	add_child_autofree(dir)
	dir.apply_pack_id(&"DOES_NOT_EXIST")
	assert_null(dir.current_pack(), "unknown pack leaves no active style")


# --- ImpactFrame / ImpactDirector --------------------------------------------

func test_all_impact_presets_load() -> void:
	for weight in ["light", "medium", "heavy", "critical"]:
		var frame := load("res://src/juice/presets/impact_%s.tres" % weight) as ImpactFrame
		assert_not_null(frame, "impact_%s.tres must load" % weight)
		if frame == null:
			continue
		assert_true(frame.hitstop_s > 0.0, "%s: hitstop_s > 0" % weight)
		assert_true(frame.time_scale > 0.0 and frame.time_scale <= 1.0,
			"%s: time_scale in (0,1]" % weight)
		assert_true(frame.shake_amplitude >= 0.0 and frame.shake_amplitude <= 1.0,
			"%s: shake_amplitude in [0,1]" % weight)


func test_impact_weight_ordering() -> void:
	var light := ImpactFrame.preset(ImpactDirector.WEIGHT_LIGHT)
	var medium := ImpactFrame.preset(ImpactDirector.WEIGHT_MEDIUM)
	var heavy := ImpactFrame.preset(ImpactDirector.WEIGHT_HEAVY)
	var critical := ImpactFrame.preset(ImpactDirector.WEIGHT_CRITICAL)
	assert_true(light.hitstop_s < medium.hitstop_s, "LIGHT < MEDIUM hitstop")
	assert_true(medium.hitstop_s < heavy.hitstop_s, "MEDIUM < HEAVY hitstop")
	assert_true(heavy.hitstop_s < critical.hitstop_s, "HEAVY < CRITICAL hitstop")
	assert_true(light.shake_amplitude < critical.shake_amplitude, "shake scales with weight")


func test_impact_director_hitstop_restores_time() -> void:
	var dir: Node = load("res://src/juice/impact_director.gd").new()
	add_child_autofree(dir)
	Engine.time_scale = 1.0
	dir.impact_frame(ImpactFrame.preset(ImpactDirector.WEIGHT_HEAVY))
	assert_true(Engine.time_scale < 1.0, "hitstop slows the world")
	# Advance past the hitstop: time scale must restore.
	dir.advance(1.0)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "time scale restores after hitstop")
	Engine.time_scale = 1.0
