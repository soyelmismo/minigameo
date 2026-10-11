extends "res://addons/gut/test.gd"
## Fake clock for VoiceDirector / MusicDirector tests (msec).
class FakeClock:
	extends Object
	var now: float = 0.0
	func now_msec() -> float:
		return now

## Bus setup idempotency + layout contract (scaffold §10.2).
##
## Buses are engine-global state: the tests here verify the layout logic
## (bus_for_group, is_layout_bus) as pure data, plus that AudioDirector
## registers buses idempotently on a real (headless) AudioServer.

var _director: AudioDirector = null

func before_each() -> void:
	_director = AudioDirector.new()
	add_child_autofree(_director)

func after_each() -> void:
	_director = null

func test_layout_registers_scaffold_buses() -> void:
	# First registration on a fresh engine: 0 existing.
	var first: int = _director.setup_buses()
	assert_eq(first, 0, "fresh registration finds no existing layout buses")
	for entry: Dictionary in BusLayout.LAYOUT:
		var name: StringName = entry["name"] as StringName
		assert_ne(AudioServer.get_bus_index(name), -1, "bus '%s' registered" % name)

func test_setup_buses_is_idempotent() -> void:
	_director.setup_buses()
	var before: int = AudioServer.bus_count
	# Second call must add nothing and report all buses existing.
	var second: int = _director.setup_buses()
	assert_eq(second, BusLayout.LAYOUT.size(), "all layout buses already exist")
	assert_eq(AudioServer.bus_count, before, "no duplicate buses created")
	# A brand-new director instance must also be a no-op.
	var other := AudioDirector.new()
	add_child_autofree(other)
	assert_eq(other.setup_buses(), BusLayout.LAYOUT.size(), "idempotent across instances")

func test_group_routing() -> void:
	assert_eq(BusLayout.bus_for_group(&"player"), BusLayout.BUS_PLAYER)
	assert_eq(BusLayout.bus_for_group(&"world"), BusLayout.BUS_WORLD)
	assert_eq(BusLayout.bus_for_group(&"ui"), BusLayout.BUS_UI)
	assert_eq(BusLayout.bus_for_group(&"impact"), BusLayout.BUS_IMPACT)
	assert_eq(BusLayout.bus_for_group(&"voice"), BusLayout.BUS_VO)
	# Unknown groups fall back to SFX.
	assert_eq(BusLayout.bus_for_group(&"mystery"), BusLayout.BUS_SFX)

func test_is_layout_bus() -> void:
	assert_true(BusLayout.is_layout_bus(BusLayout.BUS_MASTER))
	assert_true(BusLayout.is_layout_bus(BusLayout.BUS_VO))
	assert_false(BusLayout.is_layout_bus(&"Nope"))

func test_master_bus_has_limiter() -> void:
	_director.setup_buses()
	var idx: int = AudioServer.get_bus_index(BusLayout.BUS_MASTER)
	assert_ne(idx, -1, "Master exists")
	var found: bool = false
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLimiter:
			found = true
	assert_true(found, "Master has a Limiter effect (scaffold §10.2)")

func test_music_and_vo_have_compressors() -> void:
	_director.setup_buses()
	for bus: StringName in [BusLayout.BUS_MUSIC, BusLayout.BUS_VO]:
		var idx: int = AudioServer.get_bus_index(bus)
		assert_ne(idx, -1, "%s exists" % bus)
		var found: bool = false
		for i in range(AudioServer.get_bus_effect_count(idx)):
			if AudioServer.get_bus_effect(idx, i) is AudioEffectCompressor:
				found = true
		assert_true(found, "%s has a Compressor (scaffold §10.2)" % bus)
