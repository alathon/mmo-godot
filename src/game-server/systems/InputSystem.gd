class_name InputSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

## Reject inputs tagged for ticks further than this into the future.
const INPUT_FUTURE_LIMIT := 20

## Kick a player if no input received for this many seconds.
const INPUT_TIMEOUT := 10.0

## peer_id -> { tick: int -> input_dict }
var _input_buffers: Dictionary[int, Dictionary] = {}

var _zone: Node

var _debug: bool = false

func init(zone: Node) -> void:
	_zone = zone


func on_player_added(peer_id: int) -> void:
	_input_buffers[peer_id] = {}


func on_player_removed(peer_id: int) -> void:
	_input_buffers.erase(peer_id)


## Buffer a single PlayerInput packet. Call from ServerZone._on_packet().
func handle_packet(peer_id: int, input: Proto.PlayerInput) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers
	if not players.has(peer_id):
		return
	if frozen_peers.has(peer_id):
		return

	var input_tick: int = input.get_tick()
	var current_tick: int = NetworkTime.tick
	var sim_tick := current_tick

	if input_tick < sim_tick:
		var diff = sim_tick - input_tick
		# Allow slight lateness to still process the input. This may lead to some correctional drift,
		# but prevents dropped input sprees due to slightly late tick alignment.
		if diff <= 3:
			print("[INPUT] LATE input from peer %d: input_tick=%d sim_tick=%d (moved up %d ticks)" % [peer_id, input_tick, sim_tick, diff])
			input_tick = sim_tick # Lets try this...
		else:
			print("[INPUT] LATE input from peer %d: input_tick=%d sim_tick=%d (dropped)" % [peer_id, input_tick, sim_tick])
			return

	if input_tick > current_tick + INPUT_FUTURE_LIMIT:
		print("[INPUT] FUTURE input from peer %d: input_tick=%d current=%d (dropped)" % [peer_id, input_tick, current_tick])
		return

	if not _input_buffers.has(peer_id):
		_input_buffers[peer_id] = {}

	var buf_entry := {
		"input_x": input.get_input_x(),
		"input_z": input.get_input_z(),
		"jump_pressed": input.get_jump_pressed(),
		"ability_id": "",
		"target_entity_id": 0,
		"ground_x": 0.0, "ground_y": 0.0, "ground_z": 0.0,
	}
	if input.has_ability_input():
		var ai = input.get_ability_input()
		buf_entry["ability_id"] = ai.get_ability_id()
		buf_entry["target_entity_id"] = ai.get_target_entity_id()
		buf_entry["ground_x"] = ai.get_ground_x()
		buf_entry["ground_y"] = ai.get_ground_y()
		buf_entry["ground_z"] = ai.get_ground_z()
	_input_buffers[peer_id][input_tick] = buf_entry
	if _debug and (abs(input.get_input_x()) > 0.01 or abs(input.get_input_z()) > 0.01 or input.get_jump_pressed()):
		print("[TRACE:InputSystem] t=%s tick=%d peer=%d input_received" % [
			Globals.ts(), input_tick, peer_id])

	var state := _get_state(players[peer_id])
	if state:
		state.last_input_tick = input_tick
		if state.first_input_tick < 0:
			state.first_input_tick = input_tick


## Consume buffered inputs for sim_tick. Writes inputs, ability_inputs,
## moving_entities, and kick_peers into ctx.
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers
	var inputs: Dictionary = {}
	var ability_inputs: Dictionary = {}
	var moving_entities: Dictionary = {}
	var kick_peers: Array = []

	var timeout_ticks := int(INPUT_TIMEOUT * Globals.TICK_RATE)

	for peer_id in players:
		if frozen_peers.has(peer_id):
			continue

		var state := _get_state(players[peer_id])
		if state == null:
			continue

		if tick - state.last_input_tick > timeout_ticks:
			print("[INPUT] Kicking peer %d: no input for %.0fs" % [peer_id, INPUT_TIMEOUT])
			kick_peers.append(peer_id)
			continue

		if state.first_input_tick < 0 or tick < state.first_input_tick:
			continue

		var buf: Dictionary = _input_buffers.get(peer_id, {})
		var input: Dictionary
		var is_real_input := false
		if buf.has(tick):
			input = buf[tick]
			buf.erase(tick)
			is_real_input = true
		else:
			input = state.last_input
			print("[INPUT] REPLAY input for peer %d at sim_tick=%d" % [peer_id, tick])

		if abs(input.get("input_x", 0.0)) > 0.01 or abs(input.get("input_z", 0.0)) > 0.01:
			moving_entities[peer_id] = true

		inputs[peer_id] = input

		if input.get("ability_id", "") != "":
			ability_inputs[peer_id] = {
				"ability_id": input["ability_id"],
				"target_entity_id": input.get("target_entity_id", 0),
				"ground_x": input.get("ground_x", 0.0),
				"ground_y": input.get("ground_y", 0.0),
				"ground_z": input.get("ground_z", 0.0),
			}

		# Only update last_input from real inputs so that replays preserve
		# the player's last actual intent instead of feeding back into themselves.
		if is_real_input:
			state.last_input = input.duplicate()
			state.last_input["jump_pressed"] = false
			state.last_input["ability_id"] = ""

	# Prune inputs older than sim_tick
	for peer_id in _input_buffers:
		var buf: Dictionary = _input_buffers[peer_id]
		for tick_key in buf.keys():
			if tick_key < tick:
				buf.erase(tick_key)

	ctx["inputs"] = inputs
	ctx["ability_inputs"] = ability_inputs
	ctx["moving_entities"] = moving_entities
	ctx["kick_peers"] = kick_peers


func _get_state(player: Node) -> PlayerInputState:
	if player is ServerPlayer:
		return (player as ServerPlayer).input_state
	return null
