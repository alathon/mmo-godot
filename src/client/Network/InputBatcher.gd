class_name InputBatcher
extends Node

## Accumulates player inputs over several ticks and sends them in a single
## packet with redundancy. Each send includes the previous batch so that a
## single lost packet doesn't create an input gap on the server.

const Proto = preload("res://src/common/proto/packets.gd")

## How many ticks of input to accumulate before sending.
@export var batch_size: int = 2

var _current_batch: Array[Dictionary] = []
var _previous_batch: Array[Dictionary] = []

func clear() -> void:
	_current_batch.clear()
	_previous_batch.clear()

func queue_input(input_x: float, input_z: float, jump_pressed: bool, rot_y: float, tick: int) -> void:
	_current_batch.append({
		"input_x": input_x,
		"input_z": input_z,
		"jump_pressed": jump_pressed,
		"rot_y": rot_y,
		"tick": tick,
	})
	if _current_batch.size() >= batch_size:
		_flush()

func _flush() -> void:
	var peer = multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var pkt = Proto.Packet.new()
	var batch = pkt.new_input_batch()

	# Previous batch (redundancy).
	for entry in _previous_batch:
		_add_input(batch, entry)

	# Current batch.
	for entry in _current_batch:
		_add_input(batch, entry)

	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

	_previous_batch = _current_batch.duplicate()
	_current_batch.clear()

func _add_input(batch: Proto.InputBatch, entry: Dictionary) -> void:
	var input = batch.add_inputs()
	input.set_input_x(entry["input_x"])
	input.set_input_z(entry["input_z"])
	input.set_jump_pressed(entry["jump_pressed"])
	input.set_rot_y(entry["rot_y"])
	input.set_tick(entry["tick"])
