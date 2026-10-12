extends GutTest
## PlayerMotor + world instantiation tests (scaffold §6, §11, §13.4).

func _make_motor() -> PlayerMotor:
	var m := PlayerMotor.new()
	add_child_autofree(m)
	# Give it a config explicitly (no project autoloads in tests).
	m.config = PlayerMotorConfig.new()
	return m


func test_motor_accelerates_toward_target() -> void:
	var m := _make_motor()
	m.move(Vector3.BACK)  # +Z in Godot (BACK = +Z)
	m.advance(0.5)
	assert_gt(m.velocity.z, 0.0, "moving BACK gives +z velocity")
	assert_true(m.current_speed() > 1.0, "motor gains speed over half a second")
	assert_eq(m.move_state, PlayerMotor.State.RUN, "moving on ground is RUN")


func test_motor_friction_stops() -> void:
	var m := _make_motor()
	m.move(Vector3.BACK)
	m.advance(1.0)
	m.move(Vector3.ZERO)
	m.advance(1.5)
	assert_almost_eq(m.velocity.z, 0.0, 0.5, "friction brings the motor to rest")
	assert_eq(m.move_state, PlayerMotor.State.IDLE, "rest is IDLE")


func test_motor_sprint_is_faster() -> void:
	var walk := _make_motor()
	walk.move(Vector3.BACK, false)
	walk.advance(2.0)
	var run := _make_motor()
	run.move(Vector3.BACK, true)
	run.advance(2.0)
	assert_gt(run.current_speed(), walk.current_speed(), "sprint multiplier applies")


func test_motor_jump_leaves_ground() -> void:
	var m := _make_motor()
	m.jump()
	m.advance(0.05)
	assert_gt(m.velocity.y, 0.0, "jump gives upward velocity")
	assert_eq(m.move_state, PlayerMotor.State.AIR, "airborne is AIR")


func test_motor_airborne_state_after_jump() -> void:
	# Right after takeoff the motor is airborne; the headless floor
	# emulation re-grounds it only once vertical velocity settles.
	var m := _make_motor()
	m.jump()
	m.advance(0.02)
	assert_eq(m.move_state, PlayerMotor.State.AIR, "just after takeoff is AIR")
	assert_gt(m.velocity.y, 0.0, "still rising")


func test_motor_jump_buffer_works_before_landing() -> void:
	var m := _make_motor()
	m.jump()                 # pressed early
	m.move(Vector3.ZERO)
	m.advance(m.config.jump_buffer_s * 0.5)  # still within buffer window
	assert_gt(m.velocity.y, 0.0, "buffered jump fires on the ground frame")


func test_motor_lean_and_squash_exposed() -> void:
	var m := _make_motor()
	m.move(Vector3.RIGHT)
	m.advance(1.0)
	assert_true(absf(m.lean_angle()) > 1.0, "moving produces a lean angle")
	assert_almost_eq(m.squash_factor(), 0.0, 0.01, "squash settles back to 0")


func test_config_is_data_driven() -> void:
	var cfg := load("res://src/player/player_motor.tres") as PlayerMotorConfig
	assert_not_null(cfg, "player_motor.tres loads")
	if cfg == null:
		return
	assert_gt(cfg.move_speed, 0.0, "move_speed tuned in data")
	assert_gt(cfg.jump_velocity, 0.0, "jump_velocity tuned in data")
	assert_true(cfg.coyote_time_s > 0.0, "coyote time configured")
	assert_true(cfg.jump_buffer_s > 0.0, "jump buffer configured")


# --- World -------------------------------------------------------------------

func test_city_block_instantiates_with_spawns() -> void:
	var scene: PackedScene = load("res://src/world/city_block.tscn")
	assert_not_null(scene, "city_block.tscn loads")
	if scene == null:
		return
	var block: Node3D = scene.instantiate()
	add_child_autofree(block)
	assert_not_null(block.get_node_or_null("Ground"), "ground exists")
	assert_not_null(block.get_node_or_null("Buildings"), "buildings exist")
	assert_not_null(block.get_node_or_null("Props"), "props exist")
	assert_not_null(block.get_node_or_null("SpawnPoints"), "spawn points exist")
	var spawns: Array[Vector3] = block.spawn_positions()
	assert_true(spawns.size() >= 4, "block exposes spawn positions")



func test_player_scene_instantiates() -> void:
	var scene: PackedScene = load("res://src/player/player_avatar.tscn")
	assert_not_null(scene, "player_avatar.tscn loads")
	if scene == null:
		return
	var player: Node3D = scene.instantiate()
	add_child_autofree(player)
	var motor := player.get_node_or_null("PlayerMotor") as PlayerMotor
	assert_not_null(motor, "player scene contains the motor")
