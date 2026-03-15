extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const ServerPlayerScene = preload("res://src/game-server/ServerPlayer.tscn")

@export var PORT = 7000
@export var MAX_CLIENTS = 32

## Reject input tagged for ticks further than this into the future.
const INPUT_FUTURE_LIMIT := 20

## Kick a player if no input received for this many seconds.
const INPUT_TIMEOUT := 10.0

## Where new players spawn. Must match the client's LocalPlayer transform.
const SPAWN_POSITION := Vector3(41.17052, 1.7646443, -28.533752)

## peer_id -> ServerPlayer node
var players: Dictionary[int, ServerPlayer] = {}

## peer_id -> { tick: int -> { input_x, input_z, jump_pressed } }
var _input_buffers: Dictionary[int, Dictionary] = {}

@onready var _entities: Node = %Entities

func _ready() -> void:
	# Align physics tick rate with network tick rate so physics_factor = 1.0
	Engine.physics_ticks_per_second = Globals.TICK_RATE

	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error:
		printerr("[SERVER] Failed to start: %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	NetworkTime.start_server()
	NetworkTime.on_tick.connect(_tick)
	print("[SERVER] Zone listening on port %d" % PORT)

func _tick(_delta: float, current_tick: int) -> void:
	var sim_tick := current_tick - Globals.INPUT_BUFFER_SIZE

	# Simulate each player using their buffered input for sim_tick
	for peer_id in players:
		var player: ServerPlayer = players[peer_id]
		var buf: Dictionary = _input_buffers.get(peer_id, {})

		var input: Dictionary
		if buf.has(sim_tick):
			input = buf[sim_tick]
			buf.erase(sim_tick)
			player.has_received_input = true
		elif not player.has_received_input:
			# Client hasn't finished clock sync yet — skip simulation.
			continue
		else:
			# No input for this tick — re-execute last known input
			input = player.last_input
			print("[SERVER] REPLAY input for peer %d at sim_tick=%d" % [peer_id, sim_tick])

		player.simulate(input, Globals.TICK_INTERVAL)

	# Prune old buffered input (anything older than sim_tick)
	for peer_id in _input_buffers:
		var buf: Dictionary = _input_buffers[peer_id]
		for tick_key in buf.keys():
			if tick_key < sim_tick:
				buf.erase(tick_key)

	# Kick players that haven't sent input within the timeout.
	var timeout_ticks := int(INPUT_TIMEOUT * Globals.TICK_RATE)
	for peer_id in players.keys():
		var player: ServerPlayer = players[peer_id]
		if sim_tick - player.last_input_tick > timeout_ticks:
			print("[SERVER] Kicking peer %d: no input for %.0fs" % [peer_id, INPUT_TIMEOUT])
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)

	# Broadcast world state
	var pkt = Proto.Packet.new()
	var diff = pkt.new_world_diff()
	diff.set_tick(current_tick)
	for peer_id in players:
		var player: ServerPlayer = players[peer_id]
		var state = diff.add_entities()
		state.set_entity_id(peer_id)
		state.set_pos_x(player.global_position.x)
		state.set_pos_y(player.global_position.y)
		state.set_pos_z(player.global_position.z)
		state.set_vel_x(player.velocity.x)
		state.set_vel_y(player.velocity.y)
		state.set_vel_z(player.velocity.z)
		state.set_rot_y(player.face_angle)

	var bytes = pkt.to_bytes()
	for peer_id in players:
		multiplayer.send_bytes(bytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_player_input():
		_handle_input(peer_id, pkt.get_player_input())
	elif pkt.has_clock_ping():
		_handle_clock_ping(peer_id, pkt.get_clock_ping())

func _handle_clock_ping(peer_id: int, ping: Proto.ClockPing) -> void:
	var pkt = Proto.Packet.new()
	var pong = pkt.new_clock_pong()
	pong.set_ping_id(ping.get_ping_id())
	pong.set_client_time(ping.get_client_time())
	pong.set_server_time(Time.get_unix_time_from_system())
	pong.set_server_tick(NetworkTime.tick)
	multiplayer.send_bytes(pkt.to_bytes(), peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _handle_input(peer_id: int, input: Proto.PlayerInput) -> void:
	if not players.has(peer_id):
		return

	var input_tick: int = input.get_tick()
	var current_tick: int = NetworkTime.tick
	var sim_tick := current_tick - Globals.INPUT_BUFFER_SIZE

	# Validate tick range
	if input_tick < sim_tick:
		# Input arrived too late — already simulated past this tick
		print("[SERVER] LATE input from peer %d: input_tick=%d sim_tick=%d (dropped)" % [peer_id, input_tick, sim_tick])
		return
	if input_tick > current_tick + INPUT_FUTURE_LIMIT:
		# Input claims to be way too far in the future — suspicious or clock desync
		print("[SERVER] FUTURE input from peer %d: input_tick=%d current=%d (dropped)" % [peer_id, input_tick, current_tick])
		return

	# Buffer the input
	if not _input_buffers.has(peer_id):
		_input_buffers[peer_id] = {}

	_input_buffers[peer_id][input_tick] = {
		"input_x": input.get_input_x(),
		"input_z": input.get_input_z(),
		"jump_pressed": input.get_jump_pressed(),
	}

	players[peer_id].last_input_tick = input_tick

func _on_peer_connected(id: int) -> void:
	if id == 1:
		return  # server's own peer — not a real client
	print("[SERVER] Peer connected: %d" % id)
	var player := ServerPlayerScene.instantiate() as ServerPlayer
	player.name = "ServerPlayer_%d" % id
	_entities.add_child(player)
	var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	player.global_position = SPAWN_POSITION + offset
	player.last_input_tick = NetworkTime.tick
	players[id] = player
	_input_buffers[id] = {}

func _on_peer_disconnected(id: int) -> void:
	print("[SERVER] Peer disconnected: %d" % id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	_input_buffers.erase(id)
