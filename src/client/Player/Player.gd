class_name Player
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

## Only reconcile when prediction error exceeds this (meters).
const CORRECTION_THRESHOLD := 0.1
## Snap instead of replay when error exceeds this (meters).
const CORRECTION_SNAP_THRESHOLD := 5.0
## How many ticks of input history to keep for replay.
const INPUT_HISTORY_SIZE := 64

@export_range(2.0, 20.0) var Speed = 10.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5
@export_range(1.0, 30.0) var TurnSpeed = 10.0

# When set, this player runs physics from the input source and sends to the server.
# These must be set by the spawner (GameManager) after add_child — %unique lookups
# don't work for dynamically-spawned nodes because the owner chain points to the
# zone scene root, not Game.tscn's root where Network/InputBatcher live.
var input_source: Node
var input_batcher: InputBatcher
var api: BackendAPI

## Input + prediction history for CSP reconciliation.
## tick -> { input_x, input_z, jump_pressed, predicted_pos }
var _input_history: Dictionary[int, Dictionary] = {}

## Pending server state for reconciliation (applied in _on_before_tick_loop).
var _pending_server_tick: int = -1
var _pending_server_pos: Vector3 = Vector3.ZERO
var _pending_server_vel: Vector3 = Vector3.ZERO
var _pending_server_rot: float = 0.0

var frozen: bool = false

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
	NetworkTime.on_tick.connect(_on_network_tick)
	NetworkTime.on_tick_reset.connect(_on_tick_reset)

func _on_tick_reset() -> void:
	print("[CLIENT] Player tick reset — input history and pending server tick cleared")
	_input_history.clear()
	_pending_server_tick = -1

func _on_before_tick_loop() -> void:
	if _pending_server_tick < 0:
		return

	# The server's WorldDiff at tick T reflects input processed through sim_tick.
	var sim_tick := _pending_server_tick - Globals.INPUT_BUFFER_SIZE

	# Check prediction accuracy at sim_tick.
	var entry: Variant = _input_history.get(sim_tick, null)
	if entry != null:
		var predicted_pos: Vector3 = entry["predicted_pos"]
		var error := predicted_pos.distance_to(_pending_server_pos)

		if error < CORRECTION_THRESHOLD:
			# Prediction was accurate — no correction needed.
			_pending_server_tick = -1
			return

		if error > CORRECTION_SNAP_THRESHOLD:
			print("[Player] SNAP correction: error=%.2f at sim_tick=%d" % [error, sim_tick])

	# Snap to server state (position + velocity + rotation).
	if not frozen:
		global_position = _pending_server_pos
		velocity = _pending_server_vel
		face_angle = _pending_server_rot

	# Drop inputs the server has already processed.
	for tick_key in _input_history.keys():
		if tick_key <= sim_tick:
			_input_history.erase(tick_key)

	# Replay remaining buffered inputs to re-predict up to current tick.
	# move_and_slide() is a self-contained collision query — calling it
	# N times in a loop produces the same result as N separate physics frames
	# against static geometry (terrain). is_on_floor() updates between calls.
	var replay_ticks: Array = _input_history.keys()
	replay_ticks.sort()
	for t in replay_ticks:
		_simulate(_input_history[t], Globals.TICK_INTERVAL)
		# Update the predicted_pos in history to reflect the corrected replay.
		_input_history[t]["predicted_pos"] = global_position

	_pending_server_tick = -1

## Core movement simulation — used for both normal ticks and CSP replay.
func _simulate(input: Dictionary, delta: float) -> void:
	if frozen:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	if input.get("jump_pressed", false) and is_on_floor():
		velocity.y = JumpVelocity

	var ix: float = input.get("input_x", 0.0)
	var iz: float = input.get("input_z", 0.0)
	var movement := Vector3(ix, 0.0, iz)

	if movement != Vector3.ZERO:
		velocity.x = movement.x * Speed
		velocity.z = movement.z * Speed
		var target_y := atan2(-movement.x, -movement.z)
		rotation.y = lerp_angle(rotation.y, target_y, delta * TurnSpeed)
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _on_network_tick(delta: float, current_tick: int) -> void:
	if frozen or input_source == null:
		return

	var input := {
		"input_x": input_source.movement.x,
		"input_z": input_source.movement.z,
		"jump_pressed": input_source.jump_pressed,
	}

	_simulate(input, delta)

	# Store input + predicted position for reconciliation.
	input["predicted_pos"] = global_position
	_input_history[current_tick] = input

	# Prune old history.
	var oldest := current_tick - INPUT_HISTORY_SIZE
	for tick_key in _input_history.keys():
		if tick_key < oldest:
			_input_history.erase(tick_key)

	if input_batcher:
		input_batcher.queue_input(input["input_x"], input["input_z"], input["jump_pressed"], rotation.y, current_tick)
	elif api:
		api.send_input(input["input_x"], input["input_z"], input["jump_pressed"], rotation.y, current_tick)
	else:
		printerr("[CLIENT] No input_batcher or api in Player.gd!")

func on_entity_diff(entity: Proto.EntityState, tick: int) -> void:
	var server_pos := Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	var server_vel := Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())
	var server_rot := entity.get_rot_y()

	# Local player: defer reconciliation to _on_before_tick_loop
	# (where TickInterpolator has already restored its state).
	_pending_server_tick = tick
	_pending_server_pos = server_pos
	_pending_server_vel = server_vel
	_pending_server_rot = server_rot
