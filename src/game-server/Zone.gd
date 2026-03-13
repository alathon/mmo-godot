extends Node

const Proto = preload("res://src/common/proto/proto.gd")

@export var PORT = 7000
@export var MAX_CLIENTS = 32

const TICK_RATE = 20
const TICK_INTERVAL = 1.0 / TICK_RATE
const MOVE_SPEED = 5.0

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
	while tick_accumulator >= TICK_INTERVAL:
		tick_accumulator -= TICK_INTERVAL
		_tick()

func _tick() -> void:
	current_tick += 1

	for peer_id in players:
		var p = players[peer_id]
		var input: Proto.PlayerInput = p.last_input
		if input != null:
			var dir = Vector3(input.get_input_x(), 0.0, input.get_input_z())
			p.position += dir * MOVE_SPEED * TICK_INTERVAL

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
	if p.last_input == null:
		print("[SERVER] first input from peer %d: x=%.2f z=%.2f jump=%s" % [
			peer_id, input.get_input_x(), input.get_input_z(), input.get_jump_pressed()
		])
	p.last_input = input

func _on_peer_connected(id: int) -> void:
	print("[SERVER] peer connected: %d" % id)
	players[id] = { "position": Vector3.ZERO, "last_input": null }

func _on_peer_disconnected(id: int) -> void:
	print("[SERVER] peer disconnected: %d" % id)
	players.erase(id)
