extends GutTest

## Winnability contract (scaffold §8.2, AGENTS.md §1.3).
##
## Data errors made several micro-games impossible without a single script
## error, because every number reads as plausible in a `.tres`:
##
##  - RHYTHM read SpawnRecipe.speed as BPM (60/speed seconds per beat). The
##    catalog said 2.5 and 3.0, which is 0.42 and 0.5 BPM: 24s and 20s per beat
##    against 22s durations, so at most one beat ever fired while the target
##    asked for 18 and 20 hits. The micro-game could not be won.
##  - CHASE paired `motion = CHASE` with `kind = CHASE_CATCH`, which moves the
##    target toward the player, so the "runaway driver you can never catch" was
##    caught in under a second — the micro-game was unwinnable in the other
##    direction (instantly over).
##
## This test is the gate that catches the class: every catalog entry must have a
## duration long enough, a target that fits in it, and a motion that does not
## invert its own objective.

const CATALOG_DIR := "res://src/minigames/catalog"

## The minimum duration the brief allows (scaffold §8.2: 10-30 s).
const MIN_DURATION_S := 10.0
const MAX_DURATION_S := 30.0


func _load_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(CATALOG_DIR)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var meta: Resource = load(CATALOG_DIR + "/" + file_name)
		if meta == null:
			continue
		out.append({
			"meta": meta,
			"file": file_name,
		})
	return out


func test_every_duration_is_inside_the_brief_window() -> void:
	var bad: Array[String] = []
	for entry: Dictionary in _load_catalog():
		var meta: Object = entry["meta"]
		var d: float = float(meta.duration_s)
		if d < MIN_DURATION_S or d > MAX_DURATION_S:
			bad.append("%s: %.1fs" % [String(meta.id), d])
	assert_true(bad.is_empty(),
		"durations outside the 10-30s window: %s" % str(bad))


func test_rhythm_speed_is_a_real_bpm_not_a_multiplier() -> void:
	# The exact shape of the bug above. A value below 20 is not a BPM for any
	# playable beat interval: it means the author wrote a multiplier.
	var bad: Array[String] = []
	for entry: Dictionary in _load_catalog():
		var meta: Object = entry["meta"]
		if String(meta.archetype) != "RHYTHM":
			continue
		var recipe: Object = meta.spawn_recipe
		if recipe == null:
			continue
		var bpm: float = float(recipe.speed)
		if bpm < 20.0:
			bad.append("%s: speed = %s (read as BPM)" % [String(meta.id), str(bpm)])
		# And the derived beat interval must leave room for several beats.
		var beat_every: float = 60.0 / maxf(1.0, bpm)
		var beats: float = float(meta.duration_s) / beat_every
		if beats < 4.0:
			bad.append("%s: only %.1f beats in %.1fs" % [String(meta.id), beats, float(meta.duration_s)])
	assert_true(bad.is_empty(),
		"RHYTHM entries are not playable: %s" % str(bad))


func test_chase_motion_does_not_invert_the_objective() -> void:
	# CHASE moves the target toward the player, so pairing it with CHASE_CATCH
	# ends the micro-game instantly. CATCH_TYPE does not use the target motion
	# (it hovers), so it is the safe pairing.
	var bad: Array[String] = []
	for entry: Dictionary in _load_catalog():
		var meta: Object = entry["meta"]
		if String(meta.archetype) != "CHASE":
			continue
		var motion: String = String(meta.spawn_recipe.motion)
		var kind: String = String(meta.objective_recipe.kind)
		if motion == "CHASE" and kind == "CHASE_CATCH":
			bad.append("%s: motion CHASE with kind CHASE_CATCH" % String(meta.id))
	assert_true(bad.is_empty(),
		"CHASE entries catch instantly: %s" % str(bad))


func test_every_target_fits_inside_the_duration() -> void:
	# A target above what the duration and a plausible hit rate can reach is an
	# unwinnable micro-game. The generic rhythm bound is ~5 hits/s (a 120 BPM
	# beat plus slack); other archetypes use the same conservative rate.
	const hits_per_s := 4.0
	var bad: Array[String] = []
	for entry: Dictionary in _load_catalog():
		var meta: Object = entry["meta"]
		var recipe: Object = meta.objective_recipe
		if recipe == null:
			continue
		var target: float = float(recipe.target)
		var reachable: float = float(meta.duration_s) * hits_per_s
		if target > reachable:
			bad.append("%s: target %d > %d reachable" % [String(meta.id), int(target), int(reachable)])
	assert_true(bad.is_empty(),
		"targets the duration cannot reach: %s" % str(bad))


func test_every_entry_has_player_facing_copy_in_english() -> void:
	# §1.9: a micro-game must read on its own, and the content is English.
	var bad: Array[String] = []
	for entry: Dictionary in _load_catalog():
		var meta: Object = entry["meta"]
		var objective: String = String(meta.objective_text).strip_edges()
		var flavor: String = String(meta.flavor_text).strip_edges()
		var fails: Array = meta.fail_lines
		if objective.is_empty():
			bad.append("%s: empty objective_text" % String(meta.id))
		if flavor.is_empty():
			bad.append("%s: empty flavor_text" % String(meta.id))
		if fails.size() < 2:
			bad.append("%s: %d fail_lines (need >= 2)" % [String(meta.id), fails.size()])
	assert_true(bad.is_empty(), "content defects: %s" % str(bad))
