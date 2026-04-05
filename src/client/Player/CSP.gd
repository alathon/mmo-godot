class_name CSP
extends Node

## How many ticks of input history to keep for replay.
const INPUT_HISTORY_SIZE := 64
## Only reconcile when prediction error exceeds this (meters).
const CORRECTION_THRESHOLD := 0.1
## Snap instead of replay when error exceeds this (meters).
const CORRECTION_SNAP_THRESHOLD := 5.0

## Input history
## tick -> { input_x, input_z, jump_pressed }
var _input_history: Dictionary[int, Dictionary] = {}
## Predicted outcomes history
## tick -> { global_position }
var _predictions_history: Dictionary[int, Dictionary] = {}

## Pending server state for reconciliation (applied in _on_before_tick_loop).
var _pending_server_tick: int = -1
var _pending_server_pos: Vector3 = Vector3.ZERO
var _pending_server_vel: Vector3 = Vector3.ZERO
var _pending_server_rot: float = 0.0

@export var _body: CharacterBody3D
@export var EnableReconciliation: bool = true

func _ready() -> void:
	NetworkTime.on_tick_reset.connect(_on_tick_reset)
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_on_after_tick_loop)

func _on_tick_reset() -> void:
	_input_history.clear()
	_predictions_history.clear()
	_pending_server_tick = -1

func _on_after_tick_loop(tick: int) -> void:
	pruneOldHistory(tick)

func _on_before_tick_loop(tick: int) -> void:
	if _pending_server_tick < 0:
		return

	# The server stamps WorldPositions with the sim_tick it was computed from.
	var sim_tick := _pending_server_tick

	# Check prediction accuracy at sim_tick.
	var entry: Variant = _predictions_history.get(sim_tick, null)
	if entry != null:
		var predicted_pos: Vector3 = entry["global_position"]
		var error := predicted_pos.distance_to(_pending_server_pos)

		if error < CORRECTION_THRESHOLD:
			# Prediction was accurate — no correction needed.
			_pending_server_tick = -1
			return

		if error > CORRECTION_SNAP_THRESHOLD:
			print("[Player] SNAP correction: error=%.2f at sim_tick=%d" % [error, sim_tick])

	if not EnableReconciliation:
		dropUpTo(sim_tick)
		return

	# Snap to server state (position + velocity + rotation).
	_body.global_position = _pending_server_pos
	_body.velocity = _pending_server_vel
	_body.rotation.y = _pending_server_rot

	# Drop inputs the server has already processed.
	dropUpTo(sim_tick)

	# Replay remaining buffered inputs to re-predict up to current tick.
	# move_and_slide() is a self-contained collision query — calling it
	# N times in a loop produces the same result as N separate physics frames
	# against static geometry (terrain). is_on_floor() updates between calls.
	var replay_ticks: Array = _input_history.keys()
	replay_ticks.sort()
	for t in replay_ticks:
		_body.simulate(_input_history[t], Globals.TICK_INTERVAL)
		setPredictionAt(t, { "global_position": _body.global_position })

	_pending_server_tick = -1

func pruneOldHistory(tick: int) -> void:
	var oldest := tick - INPUT_HISTORY_SIZE
	dropUpTo(oldest - 1)

func setPendingServerTick(tick: int, server_pos: Vector3, server_vel: Vector3, server_rot: float) -> void:
	_pending_server_tick = tick
	_pending_server_pos = server_pos
	_pending_server_vel = server_vel
	_pending_server_rot = server_rot

func setInputAt(tick: int, input: Variant) -> void:
	_input_history.set(tick, input)

func getInputAt(tick: int) -> Dictionary:
	return _input_history.get(tick, null)

func getPredictionAt(tick: int) -> Dictionary:
	return _predictions_history.get(tick, null)

func setPredictionAt(tick: int, prediction: Variant) -> void:
	_predictions_history.set(tick, prediction)

func dropUpTo(tick: int) -> void:
	# Drop already-processed inputs + predictions
	for tick_key in _input_history.keys():
		if tick_key <= tick:
			_input_history.erase(tick_key)
	
	for tick_key in _predictions_history.keys():
		if tick_key <= tick:
			_predictions_history.erase(tick_key)
