class_name RemoteInterpolator
extends Node

# Tick-based interpolation with a fixed render delay.
# Snapshots are stored in a ring buffer keyed by server tick.
# The render position lags RENDER_DELAY ticks behind the latest received tick,
# so jitter and slightly late packets are absorbed without visible stuttering.
#
# Usage: call push_snapshot(tick, {"global_position": vec3, ...}) on each server update.

const RENDER_DELAY := 1  # ticks to lag behind latest received

var _debug: bool = false
var _paused: bool = false

var _history := _HistoryBuffer.new(64)
var _render_tick: float = -1.0  # negative = not yet initialized
var _last_push_msec: int = -1
var _last_snapshot_tick: int = -1

## Pause/resume interpolation. While paused, snapshots are still buffered
## but position is not applied, allowing external systems (e.g., displacement)
## to drive the transform. On resume, render_tick jumps to latest so
## interpolation picks up from the current server state.
func set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	if not _paused and not _history.is_empty():
		_render_tick = float(_history.get_latest_index() - RENDER_DELAY)

func push_snapshot(tick: int, props: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if _debug and _last_push_msec >= 0:
		var gap_ms := now - _last_push_msec
		var tick_gap := tick - _last_snapshot_tick
		print("[RI:%s] PUSH tick=%d | gap_ms=%d | tick_gap=%d" % [get_parent().name, tick, gap_ms, tick_gap])
	_last_push_msec = now
	_last_snapshot_tick = tick

	_history.set_at(tick, props)
	if _render_tick < 0.0:
		_render_tick = float(tick - RENDER_DELAY)

func _process(delta: float) -> void:
	if _history.is_empty() or _paused:
		return

	var latest := _history.get_latest_index()

	var unclamped := _render_tick + delta * Globals.TICK_RATE
	var ceiling := float(latest - RENDER_DELAY)
	var stalled := unclamped > ceiling

	# Advance render time at the server tick rate, but never ahead of latest - delay.
	_render_tick = minf(unclamped, ceiling)

	if _debug and stalled:
		print("[RI:%s] STALL | render_tick=%.2f | ceiling=%.1f | buffer=%.2f | latest=%d" % [get_parent().name,
			_render_tick, ceiling, ceiling - _render_tick, latest
		])

	# Snap render_tick forward if it's fallen behind the buffer's range.
	var earliest := _history.get_earliest_index()
	if _render_tick < earliest:
		_render_tick = float(earliest)

	var from_tick := floori(_render_tick)
	var to_tick := from_tick + 1
	var alpha: float = _render_tick - from_tick

	var from_idx := _history.get_latest_index_at(from_tick)
	if from_idx < 0:
		if _debug:
			print("[RI:%s] WARNING: Not enough history to interpolate yet" % get_parent().name)
		return  # not enough history yet

	var to_idx := _history.get_latest_index_at(to_tick)

	var from: Variant = _history.get_at(from_idx)
	if from == null:
		# Evicted from ring buffer — snap forward to earliest available.
		_render_tick = float(earliest)
		return
	var to: Dictionary = from if to_idx < 0 else (_history.get_at(to_idx) if _history.get_at(to_idx) != null else from)

	var parent := get_parent()
	for key in to:
		parent.set(key, _lerp(from.get(key, to[key]), to[key], alpha))

static func _lerp(a: Variant, b: Variant, t: float) -> Variant:
	if a is bool:
		return a and b  # on floor only if both snapshots agree; snaps false eagerly, true conservatively
	if a is Quaternion:
		return (a as Quaternion).slerp(b, t)
	if a is float:
		return lerp_angle(a, b, t)
	return a.lerp(b, t)
