class_name PlayerMotor
extends CharacterBody3D
## PlayerMotor — arcade movement (scaffold §6, §13.4).
##
## CharacterBody3D with accel/friction, jump + coyote time + jump buffer,
## air control, procedural lean + squash/stretch. ALL tuning from
## PlayerMotorConfig (.tres). Testable: move()/jump()/advance() are pure
## logic over an injected delta - no input or physics tree required.

@export var config: PlayerMotorConfig = null

enum State { IDLE, RUN, AIR, HURT }

var move_state: State = State.IDLE
var _wish_dir: Vector3 = Vector3.ZERO
var _sprinting: bool = false
var _coyote_left: float = 0.0
var _buffer_left: float = 0.0
var _lean: float = 0.0
var _squash: float = 0.0
var _ground_assumed: bool = true   # headless floor emulation (see advance)
var _just_jumped: bool = false     # suppress same-frame re-grounding


func _ready() -> void:
	if config == null:
		config = load("res://src/player/player_motor.tres") as PlayerMotorConfig
		if config == null:
			config = PlayerMotorConfig.new()


func _physics_process(delta: float) -> void:
	advance(delta)


# --- Input surface -----------------------------------------------------------

## Set the desired movement direction (world space).
func move(dir: Vector3, sprinting: bool = false) -> void:
	_wish_dir = dir
	_sprinting = sprinting


## Request a jump (buffered: works slightly before landing).
func jump() -> void:
	_buffer_left = config.jump_buffer_s


func hurt() -> void:
	move_state = State.HURT


# --- Simulation ---------------------------------------------------------------

## Advance the motor by delta seconds. Pure logic: works headless.
func advance(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	# Headless/no-physics fallback: treat as grounded unless actively rising,
	# so the state machine and jumps behave identically without a floor.
	if not on_floor and velocity.y <= 0.0 and _ground_assumed:
		on_floor = true
	# Coyote time + jump buffer.
	if on_floor:
		_coyote_left = config.coyote_time_s
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = config.jump_velocity
		_buffer_left = 0.0
		_coyote_left = 0.0
		_squash = -config.squash_amount  # stretch on takeoff
		_ground_assumed = false
		_just_jumped = true

	# Horizontal accel/friction.
	var target_speed: float = config.move_speed * \
		(config.sprint_multiplier if _sprinting else 1.0)
	var wish: Vector3 = _wish_dir
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_vel: Vector3 = wish * target_speed
	var rate: float = config.accel if on_floor else config.air_accel
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if wish != Vector3.ZERO:
		horiz = horiz.move_toward(target_vel, rate * delta)
	else:
		var fr: float = config.friction if on_floor else config.friction * 0.2
		horiz = horiz.move_toward(Vector3.ZERO, fr * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	# Gravity.
	if not on_floor:
		velocity.y -= config.gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		# Re-arm the grounded assumption only when not actively rising.
		if not is_on_floor() and velocity.y <= 0.0 and not _just_jumped:
			_ground_assumed = true

	# Procedural lean + squash decay.
	var speed_ratio: float = clampf(horiz.length() / maxf(config.move_speed, 0.01), 0.0, 1.0)
	var target_lean: float = 0.0
	if horiz.length() > 0.1:
		var side: float = signf(horiz.dot(global_transform.basis.x))
		target_lean = -config.turn_lean_deg * speed_ratio * side
	_lean = lerpf(_lean, target_lean, clampf(config.lean_speed * delta, 0.0, 1.0))
	_squash = lerpf(_squash, 0.0, clampf(8.0 * delta, 0.0, 1.0))

	# State. If we jumped this frame we are airborne regardless of the
	# floor flag computed at the top (which predates the jump).
	if _just_jumped:
		move_state = State.AIR
	elif not on_floor:
		move_state = State.AIR
	elif horiz.length() > 0.5:
		move_state = State.RUN
	else:
		move_state = State.IDLE

	# Clear the one-frame jump flag only after the state is decided.
	_just_jumped = false

	move_and_slide()


# --- Read-only animation hooks (avatar reads these) ---------------------------

## Lean angle in degrees for the avatar to apply.
func lean_angle() -> float:
	return _lean


## Squash factor (-1 stretch .. +1 squash) for the avatar.
func squash_factor() -> float:
	return _squash


func current_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
