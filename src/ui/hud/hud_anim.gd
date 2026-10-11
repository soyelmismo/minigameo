class_name HudAnim
## Deterministic, frame-rate independent decay for HUD pops and counters.
##
## Why not a Tween: a SceneTreeTween does not step in headless runs, which
## makes every HUD animation untestable, and it hides the timing behind the
## SceneTree instead of the frame delta. This helper is pure math, runs
## identically at 12 or 240 fps, and is unit-testable in isolation (§7).
##
## Frame-rate independence comes from the exponential approach: advancing by
## x = 1 - exp(-decay * delta) leaves a constant fraction (1/2) of the
## remaining distance per time constant, regardless of how small delta is.


## Fraction of the remaining distance covered after `delta` seconds.
static func step_fraction(decay: float, delta: float) -> float:
	return 1.0 - exp(-maxf(0.0, decay) * maxf(0.0, delta))


## Approaches `target` by the decay law. Settles exactly on target so
## assertions like `is_equal_approx(value, target)` hold without epsilon.
static func approach(current: float, target: float, decay: float, delta: float) -> float:
	if absf(target - current) < 0.0001:
		return target
	return current + (target - current) * step_fraction(decay, delta)


## True when a value is close enough to be considered settled.
static func settled(value: float, target: float, epsilon: float = 0.001) -> bool:
	return absf(value - target) <= epsilon
