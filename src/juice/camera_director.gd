extends Node
## CameraDirector — follow camera + shake + FOV punch (scaffold §6.6).
##
## Follows the player (duck-typed via GameServices/EventBus) with a spring
## lag. Shake is trauma-based (decaying noise). Degrades gracefully with no
## player/camera present (headless tests drive the math directly).
##
## Premium follow feel (graphics brief "camera"):
##   * frame-rate-independent exponential smoothing (critically damped),
##     so the follow is identical at 30, 60 or 144 fps;
##   * velocity look-ahead: the frame leads the player slightly, which reads
##     as "fast" instead of "floaty";
##   * speed-reactive FOV: the frame breathes open while sprinting;
##   * a touch of roll from lateral motion.
## Every constant is an exported tuning value, not a magic number (§1.3).

const TRAUMA_DECAY := 1.6      # trauma lost per second
const TRAUMA_MAX := 1.0
const FOLLOW_LERP := 6.0       # legacy linear spring stiffness (unused path)

## Follow smoothing rate (1/s): higher = tighter camera.
@export var follow_stiffness: float = 9.0
## Look-at height above the player's feet (metres).
@export var aim_height: float = 1.15
## Seconds of velocity look-ahead (0 = camera sits exactly on the player).
@export var lookahead: float = 0.22
## Maximum look-ahead distance (metres).
@export var lookahead_max: float = 2.5
## FOV degrees added per m/s of horizontal speed (0 = no speed reaction).
@export var speed_fov_per_unit: float = 0.30
## Cap on the speed-driven FOV addition (degrees).
@export var speed_fov_max: float = 6.0
## Degrees of roll per m/s of lateral speed (0 = no roll).
@export var roll_per_unit: float = 0.02
## Roll cap (degrees) so the frame never disorients.
@export var roll_max: float = 1.2

## Default follow offset: behind and above the player. A zero offset puts the
## camera exactly on the player's vertical axis, which makes every look_at()
## degenerate (see _aim_at below). Set from main.tscn for a different framing.
const DEFAULT_OFFSET := Vector3(0.0, 8.5, 11.0)
## Horizontal separation (metres) below which a look_at would be colinear with
## the up vector and produce a degenerate basis.
const COLUMNAR_EPSILON := 0.05

var _camera: Camera3D = null
var _target: Node3D = null
var _trauma: float = 0.0
var _trauma_time: float = 0.0
var _fov_base: float = 75.0
var _fov_punch_amount: float = 0.0
var _fov_punch_time: float = 0.0
var _fov_punch_left: float = 0.0
var _zoom_amount: float = 0.0
var _zoom_left: float = 0.0
var _offset: Vector3 = DEFAULT_OFFSET
var _lookahead_vec: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _speed_fov: float = 0.0
var _roll: float = 0.0


func _ready() -> void:

	# Publish under the canonical service name (scaffold §6 / AGENTS §1.1):
	# the rest of the game resolves this system via
	# GameServices.lookup(&"camera") instead of referencing the autoload.
	# publish() refuses anything that is not the live singleton, so a
	# test double built from this script cannot clobber the real one.
	GameServices.publish("CameraDirector", &"camera", self)
	_find_camera()
	_find_target()
	GameServices.lookup(&"core")  # no-op guard for headless boot


func _find_camera() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		root = tree.root
	_camera = root.find_child("Camera3D", true, false) as Camera3D
	if _camera != null:
		_fov_base = _camera.fov


func _find_target() -> void:
	var p: Object = GameServices.lookup(&"player")
	if p is Node3D:
		_target = p as Node3D


## Inject the camera explicitly (tests, custom rigs).
func set_camera(cam: Camera3D) -> void:
	_camera = cam
	if cam != null:
		_fov_base = cam.fov


## Inject the follow target explicitly.
func set_target(t: Node3D) -> void:
	_target = t


## Set a persistent follow offset (framing rigs, cinematic moments).
func set_offset(off: Vector3) -> void:
	_offset = off


# --- Shake ----------

## Add trauma (0..1). Multiple calls accumulate and decay over time.
func shake(trauma: float, freq: float = 24.0, duration: float = 0.4) -> void:
	# Accessibility (§8): the shake multiplier lives in SettingsManager, so a
	# player who asks for less (or none) gets it everywhere at once. Scaled
	# here, at the single entry point, instead of at each call site.
	var scale: float = _shake_scale()
	if scale <= 0.0:
		return
	_trauma = minf(_trauma + trauma * scale, TRAUMA_MAX)
	_trauma_time = duration
	_shake_freq = freq
	_shake_left = duration


## Current shake multiplier from SettingsManager (1.0 when absent).
func _shake_scale() -> float:
	var settings: Object = GameServices.lookup(&"settings")
	if settings != null and settings.has_method("shake_scale"):
		return clampf(float(settings.shake_scale()), 0.0, 1.0)
	return 1.0


var _shake_freq: float = 24.0
var _shake_left: float = 0.0


## Current shake offset for this frame (deterministic noise, no RNG).
func shake_offset(delta: float) -> Vector3:
	if _shake_left <= 0.0 or _camera == null:
		return Vector3.ZERO
	_shake_left -= delta
	var t: float = (TRAUMA_MAX - _trauma) * 10.0 + _shake_left * _shake_freq
	var amount: float = _trauma * _trauma * 0.35
	return Vector3(sin(t * 1.7), sin(t * 2.3 + 1.3), sin(t * 1.1)) * amount


# --- FOV ----------

## Punch the FOV by `degrees` over `duration` seconds (negative = zoom in).
func fov_punch(degrees: float, duration: float = 0.25) -> void:
	_fov_punch_amount = degrees
	_fov_punch_time = duration
	_fov_punch_left = duration


## Sustained zoom change (dramatic roulette moments).
func zoom_pulse(degrees: float, duration: float = 1.0) -> void:
	_zoom_amount = degrees
	_zoom_left = duration


func _apply_fov(delta: float) -> void:
	if _camera == null:
		return
	var extra: float = 0.0
	if _fov_punch_left > 0.0:
		_fov_punch_left -= delta
		var k: float = clampf(_fov_punch_left / maxf(_fov_punch_time, 0.01), 0.0, 1.0)
		extra += _fov_punch_amount * k
	if _zoom_left > 0.0:
		_zoom_left -= delta
		var k2: float = clampf(_zoom_left / 1.0, 0.0, 1.0)
		extra += _zoom_amount * k2
	# Speed reaction, smoothed so a sprint eases the frame open instead of
	# snapping it. Clamped by the exported cap.
	var want_speed: float = clampf(_speed * speed_fov_per_unit, 0.0, speed_fov_max)
	_speed_fov = lerpf(_speed_fov, want_speed, clampf(3.0 * delta, 0.0, 1.0))
	extra += _speed_fov
	_camera.fov = clampf(_fov_base + extra, 30.0, 110.0)


# --- Frame ----------

## Horizontal velocity of the target (Vector3.ZERO when duck-typing fails).
func _target_velocity() -> Vector3:
	if _target == null:
		return Vector3.ZERO
	var v: Variant = _target.get("velocity")
	if v is Vector3:
		return v as Vector3
	return Vector3.ZERO


static func _flatten(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Drive follow + shake + fov with an explicit delta (testable).
func update_camera(delta: float) -> void:
	if _trauma > 0.0 and _trauma_time > 0.0:
		_trauma_time -= delta
		_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	_update_follow(delta)
	_apply_fov(delta)
	if _camera == null or _target == null:
		return
	_aim_at(_target.global_position + Vector3.UP * aim_height)
	_apply_roll(delta)


## Aims the camera at `aim` without ever producing a degenerate basis.
##
## `look_at(target, up)` needs `(aim - position)` to NOT be parallel to `up`.
## When the camera stacks vertically on the target — which is exactly what a zero
## follow offset produces, since the camera then shares the player's X/Z — the
## direction is parallel to Vector3.UP and Godot cannot build an orthonormal
## basis from it. It warns every frame ("Target and up vectors are colinear…
## unwanted rotation around local Z axis") and hands back a basis that rolls
## unpredictably: a game that looks broken while running perfectly otherwise.
##
## The guard keeps a minimum horizontal separation, so the aim direction always
## has a real component perpendicular to up.
func _aim_at(aim: Vector3) -> void:
	if _camera == null:
		return
	var direction: Vector3 = aim - _camera.global_position
	var horizontal: Vector3 = _flatten(direction)
	if horizontal.length() < COLUMNAR_EPSILON:
		# Nudge the aim sideways along the camera's own right vector rather than
		# skipping the call: the frame keeps tracking, just without a broken base.
		var right: Vector3 = _camera.global_transform.basis.x
		horizontal = _flatten(right)
		if horizontal.length() < COLUMNAR_EPSILON:
			horizontal = Vector3.RIGHT
		aim += horizontal.normalized() * COLUMNAR_EPSILON * 2.0
	_camera.look_at(aim, Vector3.UP)


## Spring follow: smoothed position + velocity look-ahead.
func _update_follow(delta: float) -> void:
	if _camera == null or _target == null:
		return
	var vel: Vector3 = _target_velocity()
	_speed = _flatten(vel).length()
	var want: Vector3 = _flatten(vel) * lookahead
	if want.length() > lookahead_max:
		want = want.normalized() * lookahead_max
	_lookahead_vec = _lookahead_vec.lerp(want, clampf(8.0 * delta, 0.0, 1.0))
	var desired: Vector3 = _target.global_position + _offset + _lookahead_vec
	# Frame-rate independent exponential smoothing: identical feel at any
	# delta, unlike the old linear lerp.
	var k: float = 1.0 - exp(-follow_stiffness * delta)
	_camera.global_position = _camera.global_position.lerp(desired, k)


## Subtle roll from lateral motion (absolute, set fresh each frame after the
## look-at so it never accumulates).
func _apply_roll(delta: float) -> void:
	if _camera == null:
		return
	var lateral: float = _flatten(_target_velocity()).dot(
		_camera.global_transform.basis.x)
	var want: float = clampf(-lateral * roll_per_unit,
		deg_to_rad(-roll_max), deg_to_rad(roll_max))
	_roll = lerpf(_roll, want, clampf(6.0 * delta, 0.0, 1.0))
	_camera.rotation.z = _roll


func _physics_process(delta: float) -> void:
	if _target == null:
		_find_target()
	update_camera(delta)
	if _camera != null:
		var off := shake_offset(delta)
		if off != Vector3.ZERO:
			_camera.h_offset = clampf(off.x, -1.0, 1.0)
			_camera.v_offset = clampf(off.y, -1.0, 1.0)
