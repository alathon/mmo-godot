extends Node

## Tick loop driven by continuous drift feedback from NetworkClockNew.
##
## Instead of computing drift from NetworkClock.get_server_tick() (which is
## NTP-derived and only updates every ~5s), stretch is driven by
## NetworkClockNew.get_drift() — a smoothed EMA fed by every WorldPositions
## packet (~20/s). This makes clock discipline continuous and responsive.
##
## Server: identical to NetworkTime — no clock reference, stretch = 1.0.
## Client: drift comes from NetworkClockNew.get_drift().

signal before_tick_loop(tick: int)
signal on_tick(delta: float, tick: int)
signal after_tick_loop(tick: int)
signal after_sync
signal on_tick_reset

const MAX_TICKS_PER_FRAME := 8
const STRETCH_MAX := 1.25
const STRETCH_MIN := 1.0 / STRETCH_MAX
const DRIFT_PANIC_TICKS := 10

## Current network tick.
var tick: int = 0

## 0.0–1.0 progress through the current tick.
var tick_factor: float:
	get:
		if not is_active:
			return 0.0
		return 1.0 - clampf((_next_tick_time - _process_time) / Globals.TICK_INTERVAL, 0.0, 1.0)

var is_active: bool = false

var physics_factor: float:
	get: return Globals.TICK_INTERVAL * Engine.physics_ticks_per_second

var _clock: NetworkClockNew = null

var _stretch: float = 1.0
var _process_time: float = 0.0
var _tick_time: float = 0.0
var _next_tick_time: float = 0.0

var _debug: bool = false
var _role: String = ""


func start_server() -> void:
	_role = "SRV"
	tick = 0
	_stretch = 1.0
	_process_time = 0.0
	_tick_time = 0.0
	_next_tick_time = Globals.TICK_INTERVAL
	is_active = true
	after_sync.emit()


func start_client(estimated_server_tick: int, clock: NetworkClockNew) -> void:
	_role = "CLI"
	tick = estimated_server_tick
	_clock = clock
	_stretch = 1.0
	_process_time = 0.0
	_tick_time = 0.0
	_next_tick_time = Globals.TICK_INTERVAL
	is_active = true
	after_sync.emit()


func reset_tick(new_tick: int) -> void:
	var old_tick := tick
	tick = new_tick
	_stretch = 1.0
	_process_time = 0.0
	_tick_time = 0.0
	_next_tick_time = Globals.TICK_INTERVAL
	print("[%s] Tick hard-reset: %d -> %d (drift was %d)" % [_role, old_tick, new_tick, new_tick - old_tick])
	on_tick_reset.emit()


func _process(delta: float) -> void:
	if is_active:
		_process_time += delta * _stretch
		if _debug and _role == "CLI" and _clock != null:
			print("[%s] tf=%.3f | tick=%d | stretch=%.3f | drift=%.2f" % [
				_role, tick_factor, tick, _stretch, _clock.get_drift()
			])


func _physics_process(delta: float) -> void:
	if is_active:
		_tick_loop(delta)


func _tick_loop(delta: float) -> void:
	if not is_active:
		return

	if _clock != null:
		var drift: float = _clock.get_drift()

		# Hard-reset if drift is beyond what stretch can fix.
		if absf(drift) > DRIFT_PANIC_TICKS:
			reset_tick(_clock.get_server_tick())
			return

		# drift > 0 means client is ahead -> slow down (stretch < 1)
		# drift < 0 means client is behind -> speed up (stretch > 1)
		var stretch_target := clampf(1.0 - drift * 0.1, STRETCH_MIN, STRETCH_MAX)
		_stretch = lerpf(_stretch, stretch_target, 0.1)

	_tick_time += delta * _stretch

	var ticks_this_frame := 0

	while _tick_time >= _next_tick_time and ticks_this_frame < MAX_TICKS_PER_FRAME:
		before_tick_loop.emit(tick)
		if _debug:
			print("[%s] TICK %d | tt=%.4f | ntt=%.4f" % [_role, tick, _tick_time, _next_tick_time])
		on_tick.emit(Globals.TICK_INTERVAL, tick)
		tick += 1
		ticks_this_frame += 1
		_next_tick_time += Globals.TICK_INTERVAL
		after_tick_loop.emit(tick)

	if ticks_this_frame > 0:
		_process_time = _tick_time
