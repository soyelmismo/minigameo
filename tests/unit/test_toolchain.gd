extends "res://addons/gut/test.gd"
## Gate test: validates that the Godot toolchain + GUT harness work.
## (Autoloads are registered in project.godot by the Core agent in Fase 0.)

func test_toolchain_ready() -> void:
	assert_true(true, "GUT runs headless")

func test_engine_version() -> void:
	var v: String = Engine.get_version_info().string
	assert_true(v.begins_with("4.4"), "Expected Godot 4.4.x, got %s" % v)
