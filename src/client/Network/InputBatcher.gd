class_name InputBatcher
extends Node

## Accumulates player inputs over several ticks and sends them in a single
## packet with redundancy. Each send includes the previous batch so that a
## single lost packet doesn't create an input gap on the server.

const Proto = preload("res://src/common/proto/packets.gd")

## How many ticks of input to accumulate before sending.
@export var batch_size: int = 1

@onready var _game_manager: GameManager = $/root/Root/Services/GameManager
@onready var _network_clock: NetworkClockNew = $/root/Root/Services/NetworkClock

var _current_batch: Array[Dictionary] = []
var _previous_batch: Array[Dictionary] = []
var _debug: bool = false
var _timing_debug: bool = false

func clear() -> void:
	_current_batch.clear()
	_previous_batch.clear()

func queue_input(
		input_x: float,
		input_z: float,
		jump_pressed: bool,
		rot_y: float,
		tick: int,
		ability_id: int = 0,
		target_entity_id: int = 0,
		ground_position: Vector3 = Vector3.ZERO,
		ability_request_id: int = 0) -> void:
	_current_batch.append({
		"input_x": input_x,
		"input_z": input_z,
		"jump_pressed": jump_pressed,
		"rot_y": rot_y,
		"tick": tick,
		"ability_id": ability_id,
		"target_entity_id": target_entity_id,
		"ground_position": ground_position,
		"ability_request_id": ability_request_id,
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

	var has_input := _current_batch.any(func(e): return e["input_x"] != 0.0 or e["input_z"] != 0.0 or e["jump_pressed"] or int(e.get("ability_id", 0)) > 0)
	if has_input and (_debug or _timing_debug):
		var ticks := _current_batch.map(func(e): return e["tick"])
		var estimated_server_tick := -1
		var lead_adjusted_tick := -1
		var lead_ticks := 0.0
		var drift := 0.0
		if _network_clock != null and _network_clock.is_synced:
			estimated_server_tick = _network_clock.get_estimated_server_tick()
			lead_adjusted_tick = _network_clock.get_lead_adjusted_tick()
			lead_ticks = _network_clock.lead_time * Globals.TICK_RATE
			drift = _network_clock.get_drift()
		var first_tick: int = ticks[0] if ticks.size() > 0 else -1
		var last_tick: int = ticks[ticks.size() - 1] if ticks.size() > 0 else -1
		print("[INPUT_TIMING:client_send] ms=%d peer=%d ticks=%s first_vs_server=%d last_vs_server=%d first_vs_lead=%d last_vs_lead=%d server_est=%d lead_tick=%d lead_ticks=%.2f drift=%.2f" % [
			Time.get_ticks_msec(), multiplayer.get_unique_id(), ticks,
			first_tick - estimated_server_tick, last_tick - estimated_server_tick,
			first_tick - lead_adjusted_tick, last_tick - lead_adjusted_tick,
			estimated_server_tick, lead_adjusted_tick, lead_ticks, drift])
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
	var ability_id := int(entry.get("ability_id", 0))
	if ability_id > 0:
		var ability_input = input.new_ability_input()
		var ground_position := entry.get("ground_position", Vector3.ZERO) as Vector3
		var target_entity_id := int(entry.get("target_entity_id", 0))
		var request_id := int(entry.get("ability_request_id", 0))
		ability_input.set_ability_id(ability_id)
		ability_input.set_target_entity_id(target_entity_id)
		ability_input.set_ground_x(ground_position.x)
		ability_input.set_ground_y(ground_position.y)
		ability_input.set_ground_z(ground_position.z)
		ability_input.set_request_id(request_id)
