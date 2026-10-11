extends GutTest

## CameraDirector contract (scaffold §6.6).
##
## The bug this test pins: the follow offset defaulted to Vector3.ZERO and nothing
## ever called set_offset() (nor did main.tscn), so the camera sat exactly on the
## player's vertical axis. Every look_at() then had a direction parallel to
## Vector3.UP, for which Godot cannot build an orthonormal basis — it warned once
## per frame ("Target and up vectors are colinear… unwanted rotation around local
## Z axis"; 2463 of them in a 25 second windowed run) and returned a basis that
## rolls unpredictably. The game ran perfectly and looked broken.
##
## Two defences, both pinned here: a non-zero default offset, and an aim guard in
## the director itself so it never issues a colinear look_at even if a caller
## zeroes the offset.

const CAMERA_SCRIPT := "res://src/juice/camera_director.gd"


func _make_director(offset: Vector3) -> Object:
	var script: GDScript = load(CAMERA_SCRIPT) as GDScript
	var director: Object = script.new()
	add_child_autofree(director)
	var camera := Camera3D.new()
	camera.name = "ProbeCamera"
	add_child(camera)
	director.set_camera(camera)
	var player := Node3D.new()
	player.name = "ProbePlayer"
	add_child(player)
	director.set_target(player)
	if offset != Vector3.INF:
		director.set_offset(offset)
	return director


func test_default_offset_is_not_on_the_players_vertical_axis() -> void:
	# A zero offset is the root cause: with it the camera shares the player's X/Z.
	var director: Object = _make_director(Vector3.INF)
	var offset: Vector3 = director.get("_offset")
	assert_gt(offset.length(), 0.1, "the default offset separates camera from player")
	assert_gt(offset.length(), 0.1,
		"the default offset is non-zero")
	assert_gt(offset.y, 0.1, "the default offset puts the camera above the player")
	assert_gt(offset.z, 0.1, "the default offset puts the camera behind the player")


func test_camera_basis_stays_orthonormal_every_frame() -> void:
	# The observable symptom: a degenerate basis is not orthonormal, and the
	# resulting roll is the "unwanted rotation around local Z" the warning names.
	var director: Object = _make_director(Vector3.ZERO)   # worst case: no offset
	var player: Node3D = _target_of(director)
	for frame: int in range(120):
		player.global_position = Vector3(
			sin(frame * 0.1) * 6.0, 0.0, cos(frame * 0.1) * 6.0
		)
		director.update_camera(1.0 / 60.0)
		var basis: Basis = _camera_of(director).global_transform.basis
		assert_true(basis.is_finite(), "frame %d: basis is finite" % frame)
		# An orthonormal basis has three mutually perpendicular unit axes.
		assert_almost_eq(basis.x.length(), 1.0, 0.01,
			"frame %d: the right axis is a unit vector" % frame)
		assert_almost_eq(basis.y.length(), 1.0, 0.01,
			"frame %d: the up axis is a unit vector" % frame)
		assert_almost_eq(basis.z.length(), 1.0, 0.01,
			"frame %d: the forward axis is a unit vector" % frame)
		assert_almost_eq(basis.x.dot(basis.y), 0.0, 0.01,
			"frame %d: right is perpendicular to up" % frame)
		assert_almost_eq(basis.x.dot(basis.z), 0.0, 0.01,
			"frame %d: right is perpendicular to forward" % frame)


func test_aim_guard_never_issues_a_colinear_look_at() -> void:
	# Even with a deliberately hostile setup (camera directly under the target),
	# the aim direction must keep a real horizontal component.
	var director: Object = _make_director(Vector3.ZERO)
	var camera: Camera3D = _camera_of(director)
	var player: Node3D = _target_of(director)
	player.global_position = Vector3.ZERO
	camera.global_position = Vector3(0.0, 0.0, 0.0)   # stacked under the target
	# force a big trauma so shake is active during the guard check
	director.shake(1.0, 40.0, 0.5)
	director.update_camera(1.0 / 60.0)
	var basis: Basis = camera.global_transform.basis
	assert_true(basis.is_finite(), "the basis survives a stacked camera")
	assert_gt(absf(_flatten(director, basis.x).length()), 0.0,
		"the right axis is not purely vertical (no degenerate basis)")


func test_follow_produces_a_real_thirdperson_framing() -> void:
	# The player-facing half of the fix: the camera must actually sit behind and
	# above, not inside the avatar.
	var director: Object = _make_director(Vector3.INF)
	var player: Node3D = _target_of(director)
	player.global_position = Vector3.ZERO
	for _i in range(240):
		director.update_camera(1.0 / 60.0)
	var camera: Camera3D = _camera_of(director)
	var spacing: Vector3 = camera.global_position - player.global_position
	assert_gt(spacing.length(), 3.0,
		"the camera keeps distance from the player (got %.2f m)" % spacing.length())
	assert_gt(spacing.y, 1.0, "the camera sits above the player")


func _camera_of(director: Object) -> Camera3D:
	return director.get("_camera") as Camera3D


func _target_of(director: Object) -> Node3D:
	return director.get("_target") as Node3D


func _flatten(director: Object, v: Vector3) -> Vector3:
	# The director's own _flatten is private; the projection is its contract.
	return Vector3(v.x, 0.0, v.z)
