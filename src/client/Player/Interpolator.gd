class_name Interpolator
extends Node

# Tick-based interpolation with a fixed render delay.
# Snapshots are stored in a ring buffer keyed by server tick.
# The render position lags RENDER_DELAY ticks behind the latest received tick,
# so jitter and slightly late packets are absorbed without visible stuttering.
#
# Usage: call push_snapshot(tick, {"global_position": vec3, ...}) on each server update.

const RENDER_DELAY := 2  # ticks to lag behind latest received

var _history := _HistoryBuffer.new(64)
var _render_tick: float = -1.0  # negative = not yet initialized

func push_snapshot(tick: int, props: Dictionary) -> void:
	_history.set_at(tick, props)
	if _render_tick < 0.0:
		_render_tick = float(tick - RENDER_DELAY)

func _process(delta: float) -> void:
	if _history.is_empty():
		return

	var latest := _history.get_latest_index()

	# Advance render time at the server tick rate, but never ahead of latest - delay.
	_render_tick = minf(_render_tick + delta * Globals.TICK_RATE, float(latest - RENDER_DELAY))

	var from_tick := floori(_render_tick)
	var to_tick := from_tick + 1
	var alpha: float = _render_tick - from_tick

	var from_idx := _history.get_latest_index_at(from_tick)
	if from_idx < 0:
		return  # not enough history yet

	var to_idx := _history.get_latest_index_at(to_tick)

	var from: Dictionary = _history.get_at(from_idx)
	var to: Dictionary = from if to_idx < 0 else _history.get_at(to_idx)

	var parent := get_parent()
	for key in to:
		parent.set(key, _lerp(from.get(key, to[key]), to[key], alpha))

static func _lerp(a: Variant, b: Variant, t: float) -> Variant:
	if a is Quaternion:
		return (a as Quaternion).slerp(b, t)
	return a.lerp(b, t)
