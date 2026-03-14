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

const MAX_TICKS_PER_FRAME := 8
const STRETCH_MAX := 1.25
const STRETCH_MIN := 1.0 / STRETCH_MAX

## Current network tick.
var tick: int = 0

## 0.0–1.0 progress through the current tick. Useful for render interpolation.
var tick_factor: float = 0.0

## Whether the tick loop is running.
var is_active: bool = false

# Reference to NetworkClock on clients; null on server.
var _clock: Node = null

var _accumulator: float = 0.0
var _stretch: float = 1.0
var _next_tick_time: float = 0.0
var _last_time: float = 0.0

## Called by Zone (server) once its multiplayer peer is up.
func start_server() -> void:
	tick = 0
	_accumulator = 0.0
	_stretch = 1.0
	is_active = true
	after_sync.emit()
	print("[NetworkTime] Server tick loop started")

## Called by NetworkClock (client) after NTP sync completes.
func start_client(estimated_server_tick: int, clock: Node) -> void:
	tick = estimated_server_tick
	_clock = clock
	_accumulator = 0.0
	_stretch = 1.0
	is_active = true
	after_sync.emit()
	print("[NetworkTime] Client tick loop started at tick %d" % tick)

func _process(delta: float) -> void:
	if not is_active:
		return

	# Update stretch factor from clock drift (client only).
	if _clock != null:
		var server_tick: int = _clock.get_server_tick()
		var drift: float = float(server_tick - tick)
		# Positive drift = we're behind; negative = we're ahead.
		var stretch_target := clampf(1.0 + drift * 0.1, STRETCH_MIN, STRETCH_MAX)
		_stretch = lerpf(_stretch, stretch_target, 0.1)

	_accumulator += delta * _stretch

	var ticks_this_frame := 0
	if _accumulator >= Globals.TICK_INTERVAL:
		before_tick_loop.emit()

	while _accumulator >= Globals.TICK_INTERVAL and ticks_this_frame < MAX_TICKS_PER_FRAME:
		_accumulator -= Globals.TICK_INTERVAL
		on_tick.emit(Globals.TICK_INTERVAL, tick)
		tick += 1
		ticks_this_frame += 1

	if ticks_this_frame > 0:
		after_tick_loop.emit()

	# tick_factor: how far we are through the *current* tick.
	tick_factor = 1.0 - clampf(_accumulator / Globals.TICK_INTERVAL, 0.0, 1.0)
