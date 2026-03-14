extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@export var PORT = 7000
@export var MAX_CLIENTS = 32

const MOVE_SPEED = 5.0
# Allow 2x max speed to accommodate latency and frame timing variance.
# The server will snap back anything beyond this.
const MOVE_TOLERANCE = 2.0

var players: Dictionary = {}
var current_tick: int = 0
var tick_accumulator: float = 0.0

func _ready() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error:
		printerr("[SERVER] Failed to start: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	print("[SERVER] Zone listening on port %d" % PORT)

func _process(delta: float) -> void:
	tick_accumulator += delta
	while tick_accumulator >= Globals.TICK_INTERVAL:
		tick_accumulator -= Globals.TICK_INTERVAL
		_tick()

func _tick() -> void:
	current_tick += 1

	if current_tick % 100 == 0:
		print("[SERVER] tick=%d players=%d" % [current_tick, players.size()])

	var pkt = Proto.Packet.new()
	var diff = pkt.new_world_diff()
	diff.set_tick(current_tick)
	for peer_id in players:
		var p = players[peer_id]
		var state = diff.add_entities()
		state.set_entity_id(peer_id)
		state.set_pos_x(p.position.x)
		state.set_pos_y(p.position.y)
		state.set_pos_z(p.position.z)

	var bytes = pkt.to_bytes()
	for peer_id in players:
		multiplayer.send_bytes(bytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_player_input():
		_handle_input(peer_id, pkt.get_player_input())

func _handle_input(peer_id: int, input: Proto.PlayerInput) -> void:
	if not players.has(peer_id):
		return
	var p = players[peer_id]

	var claimed = Vector3(input.get_pos_x(), input.get_pos_y(), input.get_pos_z())
	var dt = Time.get_ticks_msec() / 1000.0 - p.last_input_time
	var max_dist = 9999 # MOVE_SPEED * MOVE_TOLERANCE * dt

	if p.position == Vector3.ZERO:
		# First input: accept spawn position unconditionally
		p.position = claimed
		print("[SERVER] peer %d spawned at %s" % [peer_id, claimed])
	elif claimed.distance_to(p.position) <= max_dist:
		p.position = claimed
	else:
		print("[SERVER] rejected movement from peer %d: claimed=%s last=%s dist=%.2f max=%.2f" % [
			peer_id, claimed, p.position, claimed.distance_to(p.position), max_dist
		])

	p.last_input_time = Time.get_ticks_msec() / 1000.0

func _on_peer_connected(id: int) -> void:
	print("[SERVER] peer connected: %d" % id)
	players[id] = {
		"position": Vector3.ZERO,
		"last_input_time": Time.get_ticks_msec() / 1000.0,
	}

func _on_peer_disconnected(id: int) -> void:
	print("[SERVER] peer disconnected: %d" % id)
	players.erase(id)
