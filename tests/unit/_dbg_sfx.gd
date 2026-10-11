extends SceneTree
func _init() -> void:
	var lib = SFXLibrary.new()
	lib.register(&"low", {"group": &"world", "priority": 1})
	lib.register(&"high", {"group": &"world", "priority": 50})
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.05
	lib.set_stream(&"low", gen)
	lib.set_stream(&"high", gen)
	var player = SFXPlayer.new()
	player.library = lib
	player.max_voices = 1
	root.add_child(player)
	var first = player.play(&"low")
	print("first.playing after play: ", first.playing)
	var second = player.play(&"high")
	print("second is null: ", second == null)
	print("first.playing after steal: ", first.playing)
	print("first == second: ", first == second)
	print("second.playing: ", second.playing)
	print("second.stream null: ", second.stream == null)
	quit()
