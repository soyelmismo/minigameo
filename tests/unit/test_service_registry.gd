extends GutTest

## Service registry contract (scaffold §6, AGENTS.md §1.1).
##
## Every director that the rest of the game resolves by canonical name MUST
## self-register under that name at autoload time. The bug this test pins:
## `ImpactDirector` resolved `&"camera"` and `&"sfx"` through
## `GameServices.lookup()`, but no system ever called `GameServices.register()`,
## so both lookups returned null and camera shake plus impact SFX were silently
## dead at runtime — the juice the game is built around did not happen.

## Autoload node name -> canonical service key, per project.godot [autoload].
const SERVICES := {
	"GameServices": &"core",
	"MatchManager": &"match",
	"ScoreDirector": &"score",
	"StyleDirector": &"style",
	"ImpactDirector": &"impact",
	"CameraDirector": &"camera",
	"PostFXDirector": &"postfx",
	"AudioDirector": &"audio",
	"MusicDirector": &"music",
	"VoiceDirector": &"voice",
	"SFXPlayer": &"sfx",
	"PowerUpDirector": &"powerups",
	"RouletteController": &"roulette",
	"MinigameDirector": &"minigames",
	"SaveSystem": &"save",
	"SettingsManager": &"settings",
}


func _registry() -> Node:
	return get_tree().root.get_node_or_null("/root/GameServices")


func test_every_catalogued_autoload_resolves_by_canonical_name() -> void:
	var registry: = _registry()
	assert_not_null(registry, "GameServices autoload must exist")
	var unresolved: Array[String] = []
	for node_name: String in SERVICES:
		var key: StringName = SERVICES[node_name]
		if registry.resolve(key) == null:
			unresolved.append("%s (expected &\"%s\")" % [node_name, key])
	assert_true(
		unresolved.is_empty(),
		"Unregistered services (their consumers get null): %s" % str(unresolved)
	)


func test_impact_director_resolves_camera_not_null() -> void:
	# The exact lookup ImpactDirector performs when a frame fires. Before the
	# fix this was null, so shake/fov_punch never ran.
	var cam: Variant = _registry().resolve(&"camera")
	assert_not_null(cam, "ImpactDirector must resolve &\"camera\" to shake the view")
	assert_true(
		cam.has_method("shake") and cam.has_method("fov_punch"),
		"&\"camera\" must expose shake()/fov_punch() so impacts can drive it"
	)


func test_impact_director_resolves_sfx_not_null() -> void:
	var sfx: Variant = _registry().resolve(&"sfx")
	assert_not_null(sfx, "ImpactDirector must resolve &\"sfx\" to play impact audio")
	assert_true(
		sfx.has_method("play_impact"),
		"&\"sfx\" must expose play_impact() so impacts can drive it"
	)


func test_no_key_aliases_two_different_systems() -> void:
	# Two different keys must never resolve to the same instance, or a consumer
	# asks for one system and silently drives another.
	var registry: = _registry()
	var seen: Dictionary = {}
	var aliased: Array[String] = []
	for node_name: String in SERVICES:
		var key: StringName = SERVICES[node_name]
		var instance: Variant = registry.resolve(key)
		if instance == null:
			continue
		var id: int = instance.get_instance_id()
		if seen.has(id):
			aliased.append(
				"&\"%s\" and &\"%s\" resolve to the same node" % [seen[id], key]
			)
		else:
			seen[id] = String(key)
	assert_true(aliased.is_empty(), "Aliased registrations: %s" % str(aliased))


func test_lookup_degrades_gracefully_for_unknown_service() -> void:
	# A typo must not crash the game mid-match; it degrades to null instead.
	assert_null(
		_registry().resolve(&"this_service_does_not_exist"),
		"an unknown service must resolve to null, not raise"
	)


func test_register_unregister_round_trip() -> void:
	var registry: = _registry()
	var probe: = Node.new()
	registry.register(&"probe_service", probe)
	assert_not_null(registry.resolve(&"probe_service"), "probe must resolve")
	registry.unregister(&"probe_service")
	assert_null(registry.resolve(&"probe_service"), "probe must drop after unregister")
	probe.free()


func test_freed_instance_is_never_handed_back() -> void:
	# A consumer must never receive a dangling reference: resolve() drops a
	# registration whose instance has been freed.
	var registry: = _registry()
	var probe: = Node.new()
	registry.register(&"probe_service", probe)
	probe.free()
	assert_false(is_instance_valid(probe), "probe was freed")
	assert_null(
		registry.resolve(&"probe_service"),
		"a freed instance must resolve to null, not crash on use"
	)


func test_register_refuses_null() -> void:
	# Registering null would poison the map and make resolve() lie.
	var registry: = _registry()
	registry.register(&"probe_null", null)
	assert_false(
		registry.has_service(&"probe_null"),
		"a null registration must be refused"
	)
