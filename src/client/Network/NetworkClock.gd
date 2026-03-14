class_name NetworkClock
extends Node

# NTP-inspired clock synchronization.
# Sends a burst of pings on connect, picks the best sample (lowest RTT),
# and re-syncs periodically. Corrections within DRIFT_THRESHOLD ticks are
# applied gradually; larger corrections snap immediately.

const PING_COUNT := 8
const PING_INTERVAL := 0.1         # seconds between pings in a burst
const RESYNC_INTERVAL := 5.0       # seconds between re-sync bursts
const DRIFT_THRESHOLD := 2.0       # ticks; corrections larger than this snap
const DRIFT_SPEED := 2.0           # ticks/second rate of gradual correction

signal synchronized

var client_tick: int = 0
var tick_offset: float = 0.0       # add to client_tick to get estimated server tick
var is_synced: bool = false

var _tick_accumulator: float = 0.0
var _handshaking: bool = false
var _pings_sent: int = 0
var _ping_timer: float = 0.0
var _samples: Array = []           # Array of {rtt: float, offset: float}
var _pending: Dictionary = {}      # ping_id -> client_time (float)
var _next_ping_id: int = 0
var _resync_timer: float = 0.0
var _target_offset: float = 0.0
var _has_target: bool = false

func _ready() -> void:
	get_parent().connected_to_server.connect(_on_connected)

func _on_connected() -> void:
	_pings_sent = 0
	_samples.clear()
	_pending.clear()
	_ping_timer = 0.0
	_handshaking = true

func _process(delta: float) -> void:
	# Advance client tick counter.
	_tick_accumulator += delta
	while _tick_accumulator >= Globals.TICK_INTERVAL:
		_tick_accumulator -= Globals.TICK_INTERVAL
		client_tick += 1

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

	# Drift tick_offset toward _target_offset.
	if _has_target:
		var delta_offset := _target_offset - tick_offset
		if abs(delta_offset) > DRIFT_THRESHOLD:
			tick_offset = _target_offset
		else:
			tick_offset = move_toward(tick_offset, _target_offset, DRIFT_SPEED * delta)

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
	# Estimate what server tick was current when the pong arrived at the client.
	# server_tick was recorded at t3 ≈ server_time; transit time from server to
	# client is rtt/2, so server has advanced rtt/2 * TICK_RATE ticks since then.
	var server_tick: int = pong.get_server_tick()
	var estimated_server_tick: float = server_tick + (rtt / 2.0) * Globals.TICK_RATE
	var new_offset: float = estimated_server_tick - client_tick

	_samples.append({"rtt": rtt, "offset": new_offset})

	if _samples.size() >= PING_COUNT:
		_finalize_sync()

func _finalize_sync() -> void:
	# Sort by RTT ascending; the lowest-RTT sample has the most accurate offset.
	_samples.sort_custom(func(a, b): return a.rtt < b.rtt)

	# Use best sample (lowest RTT = least queuing delay = most accurate offset).
	_target_offset = _samples[0].offset
	_has_target = true

	if not is_synced:
		tick_offset = _target_offset  # snap on first sync
		is_synced = true
		_resync_timer = RESYNC_INTERVAL
		synchronized.emit()

	print("[CLIENT] Clock synced: server_tick≈%d, offset=%.1f, rtt=%.1fms" % [
		get_server_tick(), tick_offset, _samples[0].rtt * 1000.0
	])

func get_server_tick() -> int:
	return client_tick + roundi(tick_offset)
