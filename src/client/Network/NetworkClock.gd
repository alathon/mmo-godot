class_name NetworkClock
extends Node

# NTP-inspired clock synchronization with gradual clock discipline.
# Sends a burst of pings on connect and re-syncs periodically.
#
# Maintains a local clock (_local_time) with a gradually adjusted offset
# so that get_time() tracks server time smoothly. On re-sync, the offset
# nudges toward the new measurement rather than snapping, unless the
# difference exceeds PANIC_THRESHOLD.

const PING_COUNT := 8
const PING_INTERVAL := 0.1      # seconds between pings in a burst
const RESYNC_INTERVAL := 5.0    # seconds between re-sync bursts
const NUDGE_RATE := 0.5         # seconds of offset correction per second
const PANIC_THRESHOLD := 1.0    # seconds; snap if offset jumps more than this
const JITTER_BUFFER_TICKS := 2  # extra ticks of lead beyond RTT/2

signal synchronized

var is_synced: bool = false

var _handshaking: bool = false
var _pings_sent: int = 0
var _ping_timer: float = 0.0
var _samples: Array = []        # Array of {rtt: float, server_tick: int, t4: float}
var _pending: Dictionary = {}   # ping_id -> t1 (unix time float)
var _next_ping_id: int = 0
var _resync_timer: float = 0.0

# Continuous clock state.
var _local_time: float = 0.0    # monotonic, advances by delta each frame
var _offset: float = 0.0        # applied offset: get_time() = _local_time + _offset
var _target_offset: float = 0.0 # measured offset to nudge toward

## Current lead time added to run ahead of the server (seconds).
## Equals RTT/2 + jitter buffer so input arrives before the server needs it.
var lead_time: float = 0.0
## Latest measured RTT from the best sample (seconds).
var rtt: float = 0.0

func _ready() -> void:
	get_parent().connected_to_server.connect(_on_connected)

func _on_connected() -> void:
	# Reset sync state so _finalize_sync takes the fresh-snap path and
	# re-emits synchronized + calls NetworkTime.start_client, ensuring the
	# tick loop re-aligns with the new server (critical for zone transfers).
	is_synced = false
	print("[CLIENT] NetworkClock: beginning clock sync")
	_pings_sent = 0
	_samples.clear()
	_pending.clear()
	_ping_timer = 0.0
	_handshaking = true

func _process(delta: float) -> void:
	_local_time += delta

	# Nudge offset toward target.
	if is_synced and _offset != _target_offset:
		_offset = move_toward(_offset, _target_offset, NUDGE_RATE * delta)

	# Send ping burst.
	if _handshaking and _pings_sent < PING_COUNT:
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_send_ping()
			_pings_sent += 1
			_ping_timer = PING_INTERVAL
		if _pings_sent >= PING_COUNT:
			_handshaking = false

	# Periodic re-sync.
	if is_synced:
		_resync_timer -= delta
		if _resync_timer <= 0.0:
			_pings_sent = 0
			_samples.clear()
			_pending.clear()
			_ping_timer = 0.0
			_handshaking = true
			_resync_timer = RESYNC_INTERVAL

func _send_ping() -> void:
	var id := _next_ping_id
	_next_ping_id += 1
	var t1 := Time.get_unix_time_from_system()
	_pending[id] = t1
	get_parent().send_clock_ping(id, t1)

func on_clock_pong(pong) -> void:
	var t4 := Time.get_unix_time_from_system()
	var id: int = pong.get_ping_id()
	if not _pending.has(id):
		return
	var t1: float = _pending[id]
	_pending.erase(id)

	var rtt: float = t4 - t1
	var server_tick: int = pong.get_server_tick()
	var server_time: float = pong.get_server_time()
	_samples.append({"rtt": rtt, "server_tick": server_tick, "server_time": server_time, "t4": t4})

	if _samples.size() >= PING_COUNT:
		_finalize_sync()

func _finalize_sync() -> void:
	# Best sample = lowest RTT (least queuing jitter).
	_samples.sort_custom(func(a, b): return a.rtt < b.rtt)
	var best: Dictionary = _samples[0]
	rtt = best.rtt

	# Server time (in seconds) at the moment we received the pong.
	# Derived from integer server_tick (±1 tick quantization, mitigated by lowest-RTT selection).
	var server_time_at_t4: float = float(best.server_tick) / Globals.TICK_RATE + best.rtt / 2.0

	# Extrapolate to now (in case some time passed since the pong arrived).
	var elapsed_since_t4: float = Time.get_unix_time_from_system() - best.t4
	var server_time_now: float = server_time_at_t4 + elapsed_since_t4

	# Lead: run ahead of server time by RTT/2 (one-way delay for our input
	# to reach the server) plus a jitter buffer for resilience.
	lead_time = best.rtt / 2.0 + float(JITTER_BUFFER_TICKS) / Globals.TICK_RATE
	var target_time: float = server_time_now + lead_time

	# Compute what offset makes get_time() == target_time.
	var new_offset: float = target_time - _local_time

	if not is_synced:
		# First sync: snap immediately.
		_offset = new_offset
		_target_offset = new_offset
		is_synced = true
		_resync_timer = RESYNC_INTERVAL
		NetworkTime.start_client(get_server_tick(), self)
		synchronized.emit()
		print("[CLIENT] NetworkClock: clock synced")
		return

	# Panic: measurement is too far from current clock — snap immediately
	# and hard-reset NetworkTime's tick to match.
	if absf(new_offset - _offset) > PANIC_THRESHOLD:
		print("[CLIENT] Clock panic: offset jumped %.3fs, snapping" % [new_offset - _offset])
		_offset = new_offset
		_target_offset = new_offset
		NetworkTime.reset_tick(get_server_tick())
		return

	_target_offset = new_offset

## Returns the estimated server time in seconds.
## Advances smoothly every frame; corrections are gradually nudged in.
func get_time() -> float:
	return _local_time + _offset

## Returns the estimated server tick.
func get_server_tick() -> int:
	return roundi(get_time() * Globals.TICK_RATE)
