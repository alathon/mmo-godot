class_name ImpulseUtils
## Pure static functions for computing impulse velocity at a given tick.
## No state — easy to unit test and use anywhere.

## Linear decay: full peak_velocity at start_tick, zero at start_tick + duration_ticks.
static func linear(peak_velocity: Vector3, start_tick: int,
		duration_ticks: int, tick: int) -> Vector3:
	var elapsed := tick - start_tick
	if elapsed < 0 or elapsed >= duration_ticks or duration_ticks <= 0:
		return Vector3.ZERO
	var t := float(elapsed) / float(duration_ticks)
	return peak_velocity * (1.0 - t)

## Exponential decay: quadratic falloff from peak_velocity.
static func exponential(peak_velocity: Vector3, start_tick: int,
		duration_ticks: int, tick: int) -> Vector3:
	var elapsed := tick - start_tick
	if elapsed < 0 or elapsed >= duration_ticks or duration_ticks <= 0:
		return Vector3.ZERO
	var t := float(elapsed) / float(duration_ticks)
	return peak_velocity * pow(1.0 - t, 2)
