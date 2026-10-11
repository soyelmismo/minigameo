class_name CameraDirector
extends Node
## CameraDirector — follow camera + shake + FOV punch (scaffold §6.6).
##
## Follows the player (duck-typed via GameServices/EventBus) with spring
## lag. Shake is trauma-based (decaying noise). Degrades gracefully with no
## player/camera present (headless tests drive the math directly).

const TRAUMA_DECAY := 1.6      # trauma lost per second
const TRAUMA_MAX := 1.0
const FOLLOW_LERP := 6.0       # spring stiffness

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
var _offset: Vector3 = Vector3.ZERO


func _ready() -> void:
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


# --- Shake ------------------------------------------------------------------

## Add trauma (0..1). Multiple calls accumulate and decay over time.
func shake(trauma: float, freq: float = 24.0, duration: float = 0.4) -> void:
	_trauma = minf(_trauma + trauma, TRAUMA_MAX)
	_trauma_time = duration
	_shake_freq = freq
	_shake_left = duration


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


# --- FOV --------------------------------------------------------------------

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
	_camera.fov = clampf(_fov_base + extra, 30.0, 110.0)


# --- Frame ------------------------------------------------------------------

## Drive follow + shake + fov with an explicit delta (testable).
func update_camera(delta: float) -> void:
	if _trauma > 0.0 and _trauma_time > 0.0:
		_trauma_time -= delta
		_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	_apply_fov(delta)
	if _camera == null or _target == null:
		return
	var desired: Vector3 = _target.global_position + _offset
	var cur: Vector3 = _camera.global_position
	var k: float = clampf(FOLLOW_LERP * delta, 0.0, 1.0)
	_camera.global_position = cur.lerp(desired, k)
	_camera.look_at(_target.global_position + Vector3.UP, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _target == null:
		_find_target()
	update_camera(delta)
	if _camera != null:
		var off := shake_offset(delta)
		if off != Vector3.ZERO:
			_camera.h_offset = clampf(off.x, -1.0, 1.0)
			_camera.v_offset = clampf(off.y, -1.0, 1.0)
