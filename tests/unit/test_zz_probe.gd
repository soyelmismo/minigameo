extends GutTest

func test_probe_runtime() -> void:
	var d: Object = load("res://src/audio/audio_director.gd").new()
	add_child_autofree(d)
	print("PROBE buses_ready=", d.buses_ready())
	print("PROBE ambience_player=", d.ambience_player)
	if d.ambience_player != null:
		print("PROBE amb_name=", d.ambience_player.name)
		print("PROBE amb_bus=", d.ambience_player.bus)
		print("PROBE amb_vol=", d.ambience_volume_db())
		print("PROBE amb_stream=", d.ambience_player.stream)
		print("PROBE amb_playing=", d.ambience_player.playing)
	var v: Object = load("res://src/audio/voice_director.gd").new()
	add_child_autofree(v)
	v.setup(load("res://src/audio/voice_lines.gd").new())
	print("PROBE voice_speak=", v.speak(&"match_start"))
	print("PROBE voice_player=", v._voice_player)
	if v._voice_player != null:
		print("PROBE voice_name=", v._voice_player.name)
		print("PROBE voice_bus=", v._voice_player.bus)
		print("PROBE voice_stream=", v._voice_player.stream)
