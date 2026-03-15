extends Node

## Central network tick authority. Works on both server and client.
##
## Server:   call start() immediately after multiplayer peer is ready.
##           Tick increments at TICK_RATE with no offset.
##
## Client:   NetworkClock calls start(estimated_server_tick) after NTP sync.
##           The tick loop uses clock stretching to stay aligned with the
##           server, using NetworkClock as the reference.
##
## All tick-driven logic should connect to on_tick rather than running its
## own accumulator.

signal before_tick_loop
signal on_tick(delta: float, tick: int)
signal after_tick_loop
signal after_sync   # emitted when the tick loop becomes active
signal on_tick_reset  # emitted after a hard tick reset; listeners should clear stale state

const MAX_TICKS_PER_FRAME := 8
const STRETCH_MAX := 1.25
const STRETCH_MIN := 1.0 / STRETCH_MAX
## Hard-reset tick if drift exceeds this many ticks (stretch can't recover fast enough).
const DRIFT_PANIC_TICKS := 10

## Current network tick.
var tick: int = 0

## 0.0–1.0 progress through the current tick. Useful for render interpolation.
## Computed from wall-clock time so it updates every render frame, even when
## the tick loop runs at the physics rate.
var tick_factor: float:
	get:
		if not is_active:
			return 0.0
		return 1.0 - clampf((_next_tick_time - _process_time) / Globals.TICK_INTERVAL, 0.0, 1.0)

## Whether the tick loop is running.
var is_active: bool = false

## Velocity multiplier to compensate for move_and_slide()'s assumed physics delta.
## move_and_slide() internally uses 1/physics_fps as its delta. When called from
## a network tick (at a lower rate), multiply velocity by this before the call
## and divide after, so the actual displacement matches the tick interval.
var physics_factor: float:
	get: return Globals.TICK_INTERVAL * Engine.physics_ticks_per_second

# Reference to NetworkClock on clients; null on server.
var _clock: Node = null

var _stretch: float = 1.0
var _process_time: float = 0.0    # clock time, advanced every _process (for tick_factor)
var _tick_time: float = 0.0       # clock time used by the tick loop to decide when to fire
var _next_tick_time: float = 0.0  # scheduled time of the next tick

var _debug: bool = false
var _role: String = ""

## Called by Zone (server) once its multiplayer peer is up.
func start_server() -> void:
	_role = "SRV"
	tick = 0
	_stretch = 1.0
	_process_time = 0.0
	_tick_time = 0.0
	_next_tick_time = Globals.TICK_INTERVAL
	is_active = true
	after_sync.emit()
	print("[%s] Tick loop started" % _role)

## Called by NetworkClock (client) after NTP sync completes.
func start_client(estimated_server_tick: int, clock: Node) -> void:
	_role = "CLI"
	tick = estimated_server_tick
	_clock = clock
	_stretch = 1.0
	_process_time = 0.0
	_tick_time = 0.0
	_next_tick_time = Globals.TICK_INTERVAL
	is_active = true
	after_sync.emit()
	print("[%s] Tick loop started at tick %d" % [_role, tick])

## Hard-reset the tick counter and accumulators. Called on clock panic
## when drift is too large for stretch to recover from.
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
		if _debug and _role == "CLI":
			var srv_tick_str := ""
			if _clock != null:
				var srv_tick: int = _clock.get_server_tick()
				srv_tick_str = " | srv=%d | drift=%d" % [srv_tick, srv_tick - tick]
			print("[%s] tf=%.3f | tick=%d | stretch=%.3f%s" % [
				_role, tick_factor, tick, _stretch, srv_tick_str
			])

func _physics_process(delta: float) -> void:
	if is_active:
		_tick_loop(delta)

func _tick_loop(delta: float) -> void:
	if not is_active:
		return

	# Update stretch factor from clock drift (client only).
	if _clock != null:
		var server_tick: int = _clock.get_server_tick()
		var drift: float = float(server_tick - tick)

		# Hard-reset if drift is beyond what stretch can reasonably fix.
		if absf(drift) > DRIFT_PANIC_TICKS:
			reset_tick(server_tick)
			return

		# Positive drift = we're behind; negative = we're ahead.
		var stretch_target := clampf(1.0 + drift * 0.1, STRETCH_MIN, STRETCH_MAX)
		_stretch = lerpf(_stretch, stretch_target, 0.1)

	# Advance the tick clock. This is the authoritative time for deciding when
	# ticks fire. Separate from _process_time so that when running in
	# _physics_process, ticks aren't delayed by one render frame.
	_tick_time += delta * _stretch

	var ticks_this_frame := 0
	if _tick_time >= _next_tick_time:
		before_tick_loop.emit()

	while _tick_time >= _next_tick_time and ticks_this_frame < MAX_TICKS_PER_FRAME:
		if _debug:
			print("[%s] TICK %d | tt=%.4f | ntt=%.4f" % [_role, tick, _tick_time, _next_tick_time])
		on_tick.emit(Globals.TICK_INTERVAL, tick)
		tick += 1
		ticks_this_frame += 1
		_next_tick_time += Globals.TICK_INTERVAL

	if ticks_this_frame > 0:
		after_tick_loop.emit()
