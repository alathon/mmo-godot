class_name NetworkClockNew
extends Node

## Clock synchronization that combines NTP-style ping bursts (for RTT measurement)
## with continuous sim_tick observations from WorldPositions packets (for steady-state
## clock discipline).
##
## Initial sync: NTP burst -> snap clock -> emit synchronized.
## Steady state: every WorldPositions packet feeds the drift estimator.
## Periodic re-sync: NTP burst every RESYNC_INTERVAL updates RTT only.

# --- NTP burst config ---
const PING_COUNT := 8
const PING_INTERVAL := 0.1
const RESYNC_INTERVAL := 5.0

# --- Continuous drift config ---
## Exponential moving average factor for smoothing the drift signal.
const DRIFT_EMA_ALPHA := 0.15
## Clamp instantaneous drift observations to this range. A single jittery
## packet is dampened by the EMA, but sustained extreme drift will push
## _smoothed_drift past DRIFT_PANIC_TICKS so a hard reset can fire.
## Must be > DRIFT_PANIC_TICKS (in NetworkTimeNew) for panic to be reachable.
const DRIFT_CLAMP_TICKS := 15.0

## Snap instead of nudge when offset jumps more than this (seconds).
const PANIC_THRESHOLD := 1.0

## Extra ticks of lead beyond RTT/2.
const JITTER_BUFFER_TICKS := 3

signal synchronized

var is_synced: bool = false

## Latest measured RTT (seconds). Updated each NTP burst.
var rtt: float = 0.0
## Current lead time (seconds). RTT/2 + jitter buffer.
var lead_time: float = 0.0

# --- NTP burst state ---
var _handshaking: bool = false
var _pings_sent: int = 0
var _ping_timer: float = 0.0
var _samples: Array = []
var _pending: Dictionary = {}   # ping_id -> t1 (unix float)
var _next_ping_id: int = 0
var _resync_timer: float = 0.0

# --- Continuous clock state ---
var _local_time: float = 0.0
var _offset: float = 0.0          # get_time() = _local_time + _offset
var _target_offset: float = 0.0

## Smoothed drift in ticks: positive = client ahead, negative = client behind.
## Fed into NetworkTimeNew's stretch calculation.
var _smoothed_drift: float = 0.0

## The last sim_tick we observed and the local time when we observed it.
var _last_sim_tick: int = -1
var _last_sim_tick_local_time: float = 0.0

@onready var _api: BackendAPI = %BackendAPI

func _ready() -> void:
	_api.connected_to_server.connect(_on_connected)

func _on_connected() -> void:
	is_synced = false
	_smoothed_drift = 0.0
	_last_sim_tick = -1
	print("[CLIENT] NetworkClockNew: beginning clock sync")
	_pings_sent = 0
	_samples.clear()
	_pending.clear()
	_ping_timer = 0.0
	_handshaking = true

func _process(delta: float) -> void:
	_local_time += delta

	# --- NTP ping burst ---
	if _handshaking and _pings_sent < PING_COUNT:
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_send_ping()
			_pings_sent += 1
			_ping_timer = PING_INTERVAL
		if _pings_sent >= PING_COUNT:
			_handshaking = false

	# Periodic re-sync (RTT refresh only).
	if is_synced and not _handshaking:
		_resync_timer -= delta
		if _resync_timer <= 0.0:
			_pings_sent = 0
			_samples.clear()
			_pending.clear()
			_ping_timer = 0.0
			_handshaking = true
			_resync_timer = RESYNC_INTERVAL


# =============================================================================
#  NTP burst (measures RTT, initial offset)
# =============================================================================

func _send_ping() -> void:
	var id := _next_ping_id
	_next_ping_id += 1
	var t1 := Time.get_unix_time_from_system()
	_pending[id] = t1
	_api.send_clock_ping(id, t1)

func on_clock_pong(pong) -> void:
	var t4 := Time.get_unix_time_from_system()
	var id: int = pong.get_ping_id()
	if not _pending.has(id):
		return
	var t1: float = _pending[id]
	_pending.erase(id)

	var rttime: float = t4 - t1
	var server_tick: int = pong.get_server_tick()
	var server_time: float = pong.get_server_time()
	_samples.append({"rtt": rttime, "server_tick": server_tick, "server_time": server_time, "t4": t4})

	if _samples.size() >= PING_COUNT:
		_finalize_sync()

func _finalize_sync() -> void:
	_samples.sort_custom(func(a, b): return a.rtt < b.rtt)
	var best: Dictionary = _samples[0]
	rtt = best.rtt

	var server_time_at_t4: float = float(best.server_tick) / Globals.TICK_RATE + best.rtt / 2.0
	var elapsed_since_t4: float = Time.get_unix_time_from_system() - best.t4
	var server_time_now: float = server_time_at_t4 + elapsed_since_t4

	lead_time = best.rtt / 2.0 + float(JITTER_BUFFER_TICKS) / Globals.TICK_RATE
	var target_time: float = server_time_now + lead_time
	var new_offset: float = target_time - _local_time

	if not is_synced:
		# First sync: snap immediately.
		_offset = new_offset
		_target_offset = new_offset
		_smoothed_drift = 0.0
		is_synced = true
		_resync_timer = RESYNC_INTERVAL
		NetworkTime.start_client(get_server_tick(), self)
		synchronized.emit()
		print("[CLIENT] NetworkClockNew: clock synced (rtt=%.3fs, lead=%.3fs)" % [rtt, lead_time])
		return

	# Re-sync: only update RTT and lead_time. Do NOT touch _offset — the
	# continuous drift estimator handles that now.
	lead_time = best.rtt / 2.0 + float(JITTER_BUFFER_TICKS) / Globals.TICK_RATE

	# If the NTP measurement implies a large offset jump, it means the
	# continuous estimator drifted too far — panic reset.
	if absf(new_offset - _offset) > PANIC_THRESHOLD:
		print("[CLIENT] Clock panic: NTP offset jumped %.3fs, snapping" % [new_offset - _offset])
		_offset = new_offset
		_target_offset = new_offset
		_smoothed_drift = 0.0
		NetworkTime.reset_tick(get_server_tick())
		return

	print("[CLIENT] NetworkClockNew: RTT updated (rtt=%.3fs, lead=%.3fs)" % [rtt, lead_time])


# =============================================================================
#  Continuous drift estimation (from WorldPositions sim_tick)
# =============================================================================

## Called by GameManager (or wherever WorldPositions are received) every time
## a WorldPositions packet arrives.
func on_world_positions_tick(sim_tick: int) -> void:
	if not is_synced:
		return

	_last_sim_tick = sim_tick
	_last_sim_tick_local_time = _local_time

	# Estimate where the server is *now*.
	# sim_tick is the server tick when the packet was processed; add rtt/2 to get current.
	var one_way_ticks: float = (rtt / 2.0) * Globals.TICK_RATE
	var estimated_server_tick_now: float = float(sim_tick) + one_way_ticks

	# Where we *want* to be: server tick + lead (so our inputs arrive on time).
	var desired_client_tick: float = estimated_server_tick_now + lead_time * Globals.TICK_RATE

	# How far off we are. Positive = client is ahead, negative = behind.
	var instantaneous_drift: float = float(NetworkTime.tick) - desired_client_tick

	# Clamp rather than reject: a single jittery packet gets dampened by the
	# EMA, but sustained large drift still pushes _smoothed_drift toward the
	# panic threshold so NetworkTimeNew can trigger a hard reset.
	instantaneous_drift = clampf(instantaneous_drift, -DRIFT_CLAMP_TICKS, DRIFT_CLAMP_TICKS)

	# Smooth with EMA.
	_smoothed_drift = lerpf(_smoothed_drift, instantaneous_drift, DRIFT_EMA_ALPHA)


## Returns the smoothed drift in ticks. Used by NetworkTimeNew for stretch.
func get_drift() -> float:
	return _smoothed_drift


## Returns estimated server time in seconds.
func get_time() -> float:
	return _local_time + _offset

## Returns estimated server tick.
func get_server_tick() -> int:
	return roundi(get_time() * Globals.TICK_RATE)
