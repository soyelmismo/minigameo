class_name PlayerMotorConfig
extends Resource
## PlayerMotorConfig — ALL movement tuning as data (scaffold §1.3).
## Never hardcode these in the motor; tweak here.

@export var move_speed: float = 9.0          # m/s target ground speed
@export var sprint_multiplier: float = 1.45
@export var accel: float = 60.0              # m/s^2 toward target velocity
@export var friction: float = 50.0           # m/s^2 when no input
@export var air_accel: float = 25.0          # reduced air control
@export var jump_velocity: float = 8.5       # m/s initial jump
@export var gravity: float = 24.0            # m/s^2 (snappier than 9.8)
@export var coyote_time_s: float = 0.12      # jump grace after leaving ground
@export var jump_buffer_s: float = 0.12      # early jump press grace
@export var turn_lean_deg: float = 18.0      # visual lean into turns
@export var squash_amount: float = 0.15      # procedural squash/stretch
@export var lean_speed: float = 10.0         # how fast lean catches up
