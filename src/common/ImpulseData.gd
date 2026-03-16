class_name ImpulseData
## State wrapper around an active impulse effect.
## Delegates to ImpulseUtils pure functions for the actual math.

enum DecayType { LINEAR, EXPONENTIAL }

var peak_velocity: Vector3
var start_tick: int
var duration_ticks: int
var decay_type: DecayType

func _init(p_peak_velocity: Vector3, p_start_tick: int,
		p_duration_ticks: int, p_decay_type: DecayType) -> void:
	peak_velocity = p_peak_velocity
	start_tick = p_start_tick
	duration_ticks = p_duration_ticks
	decay_type = p_decay_type

func get_velocity_at_tick(tick: int) -> Vector3:
	match decay_type:
		DecayType.LINEAR:
			return ImpulseUtils.linear(peak_velocity, start_tick,
				duration_ticks, tick)
		DecayType.EXPONENTIAL:
			return ImpulseUtils.exponential(peak_velocity, start_tick,
				duration_ticks, tick)
	return Vector3.ZERO

func is_active_at_tick(tick: int) -> bool:
	var elapsed := tick - start_tick
	return elapsed >= 0 and elapsed < duration_ticks
