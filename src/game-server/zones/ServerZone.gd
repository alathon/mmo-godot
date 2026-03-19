extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const ServerPlayerScene = preload("res://src/game-server/ServerPlayer.tscn")

@export var zone_id: String = ""
@export var PORT: int = 7000
@export var MAX_CLIENTS: int = 32
@export var ORCHESTRATOR_URL: String = "ws://127.0.0.1:9000"

## Reject input tagged for ticks further than this into the future.
const INPUT_FUTURE_LIMIT := 20

## Kick a player if no input received for this many seconds.
const INPUT_TIMEOUT := 10.0

## Where new players spawn. Must match the client's LocalPlayer transform.
const SPAWN_POSITION := Vector3(41.17052, 1.7646443, -28.533752)

## peer_id -> ServerPlayer node
var players: Dictionary[int, CommonPlayer] = {}

## peer_id -> ServerPlayerState node
var _player_states: Dictionary[int, ServerPlayerState] = {}

## peer_id -> { tick: int -> { input_x, input_z, jump_pressed } }
var _input_buffers: Dictionary[int, Dictionary] = {}

## Peers frozen during zone transfer (excluded from simulation and broadcast).
var _frozen_peers: Dictionary[int, bool] = {}

## Peers with zone border immunity after arrival: peer_id -> expiry tick.
var _border_immunity: Dictionary[int, int] = {}

## How many ticks a player is immune to zone borders after arriving.
const BORDER_IMMUNITY_TICKS := 40  # 2 seconds at 20 tick/s

## transfer_token -> { peer_id, target_zone_id, target_address, target_port }
var _pending_redirects: Dictionary[String, Dictionary] = {}

## transfer_token -> { player_state, entry_x/y/z, entry_rot_y }
## Players arriving via zone transfer — token validated on connect.
var _pending_arrivals: Dictionary[String, Dictionary] = {}

@onready var _entities: Node = %Entities

## Raw WebSocket connection to the orchestrator.
var _orch_ws: WebSocketPeer = null
var _orch_connected: bool = false

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size():
			PORT = int(args[i + 1])

func _ready() -> void:
	# Disable MCP editor services when running headless — they share the same
	# user:// data dir as the editor game and would intercept MCP commands.
	if DisplayServer.get_name() == "headless":
		for svc in ["MCPGameInspector", "MCPInputService", "MCPScreenshot"]:
			var n := get_node_or_null("/root/" + svc)
			if n:
				n.queue_free()

	# Align physics tick rate with network tick rate so physics_factor = 1.0
	Engine.physics_ticks_per_second = Globals.TICK_RATE

	_parse_cmdline_args()

	if zone_id.is_empty() or not Globals.ZONE_SCENES.has(zone_id):
		printerr("[SERVER] Invalid zone_id '%s'. Must be one of: %s" % [zone_id, Globals.ZONE_SCENES.keys()])
		get_tree().quit(1)
		return

	_connect_zone_borders()
	_connect_to_orchestrator()

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
	print("[SERVER] Zone '%s' listening on port %d" % [zone_id, PORT])

# ── Orchestrator Connection ────────────────────────────────────────────────────

func _connect_to_orchestrator() -> void:
	_orch_ws = WebSocketPeer.new()
	var error := _orch_ws.connect_to_url(ORCHESTRATOR_URL)
	if error != OK:
		printerr("[SERVER] Failed to connect to orchestrator: %s" % error)
		_orch_ws = null
		return
	print("[SERVER] Connecting to orchestrator at %s..." % ORCHESTRATOR_URL)

func _process(_delta: float) -> void:
	if _orch_ws == null:
		return
	_orch_ws.poll()
	var state := _orch_ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _orch_connected:
			_orch_connected = true
			print("[SERVER] Connected to orchestrator")
			_register_with_orchestrator()
		while _orch_ws.get_available_packet_count() > 0:
			_on_orchestrator_packet(_orch_ws.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _orch_connected:
			print("[SERVER] Disconnected from orchestrator")
			_orch_connected = false
		_orch_ws = null

func _register_with_orchestrator() -> void:
	var pkt := Proto.OrchestratorPacket.new()
	var reg := pkt.new_zone_register()
	reg.set_zone_id(zone_id)
	reg.set_address("127.0.0.1")
	reg.set_port(PORT)
	reg.set_max_players(MAX_CLIENTS)
	reg.set_current_players(players.size())
	_send_to_orchestrator(pkt)
	print("[SERVER] Registered zone '%s' with orchestrator" % zone_id)

func _send_to_orchestrator(pkt: Proto.OrchestratorPacket) -> void:
	if _orch_ws and _orch_connected:
		_orch_ws.send(pkt.to_bytes(), WebSocketPeer.WRITE_MODE_BINARY)

func _on_orchestrator_packet(bytes: PackedByteArray) -> void:
	var pkt := Proto.OrchestratorPacket.new()
	pkt.from_bytes(bytes)
	if pkt.has_zone_transfer_response():
		_handle_zone_transfer_response(pkt.get_zone_transfer_response())
	elif pkt.has_prepare_player():
		_handle_prepare_player(pkt.get_prepare_player())
	elif pkt.has_heartbeat():
		var ack_pkt := Proto.OrchestratorPacket.new()
		var ack := ack_pkt.new_heartbeat_ack()
		ack.set_ping_id(pkt.get_heartbeat().get_ping_id())
		_send_to_orchestrator(ack_pkt)

func _handle_zone_transfer_response(msg: Proto.ZoneTransferResponse) -> void:
	var enet_peer_id: int = msg.get_peer_id()
	var token: String = msg.get_transfer_token()
	var address: String = msg.get_target_address()
	var port: int = msg.get_target_port()
	var target_zone: String = msg.get_zone_id()

	print("[SERVER] Transfer approved for peer %d → %s (%s:%d, token=%s)" % [
		enet_peer_id, target_zone, address, port, token])

	# Send ZoneRedirect to the client via ENet.
	var pkt := Proto.Packet.new()
	var redirect := pkt.new_zone_redirect()
	redirect.set_zone_id(target_zone)
	redirect.set_address(address)
	redirect.set_port(port)
	redirect.set_transfer_token(token)
	multiplayer.send_bytes(pkt.to_bytes(), enet_peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

	# Remove the player after a short delay to let the packet arrive.
	# For now, remove immediately — the client will disconnect on its own.
	_remove_player(enet_peer_id)

func _handle_prepare_player(msg: Proto.PreparePlayer) -> void:
	var token: String = msg.get_transfer_token()
	var state := msg.get_player_state()
	_pending_arrivals[token] = {
		"pos": Vector3(state.get_pos_x(), state.get_pos_y(), state.get_pos_z()),
		"vel": Vector3(state.get_vel_x(), state.get_vel_y(), state.get_vel_z()),
		"rot_y": state.get_rot_y(),
		"entry_spawn_path": msg.get_entry_spawn_path(),
	}
	print("[SERVER] Prepared arrival slot (token=%s, spawn_path='%s')" % [token, msg.get_entry_spawn_path()])

	# Acknowledge to orchestrator.
	var pkt := Proto.OrchestratorPacket.new()
	var ack := pkt.new_prepare_player_ack()
	ack.set_transfer_token(token)
	ack.set_accepted(true)
	_send_to_orchestrator(pkt)

# ── Tick Loop ─────────────────────────────────────────────────────────────────

func _tick(_delta: float, current_tick: int) -> void:
	var sim_tick := current_tick - Globals.INPUT_BUFFER_SIZE

	# Simulate each player using their buffered input for sim_tick
	for peer_id in players:
		if _frozen_peers.has(peer_id):
			continue
		var player: CommonPlayer = players[peer_id]
		var state: ServerPlayerState = _player_states[peer_id]

		if not state.has_received_input:
			# Client hasn't finished clock sync yet — skip simulation.
			continue

		var buf: Dictionary = _input_buffers.get(peer_id, {})

		var input: Dictionary
		if buf.has(sim_tick):
			input = buf[sim_tick]
			buf.erase(sim_tick)
		else:
			# No input for this tick — re-execute last known input
			input = state.last_input
			print("[SERVER] REPLAY input for peer %d at sim_tick=%d" % [peer_id, sim_tick])

		player.simulate(input, Globals.TICK_INTERVAL)
		state.last_input = input.duplicate()
		state.last_input["jump_pressed"] = false

	# Prune old buffered input (anything older than sim_tick)
	for peer_id in _input_buffers:
		var buf: Dictionary = _input_buffers[peer_id]
		for tick_key in buf.keys():
			if tick_key < sim_tick:
				buf.erase(tick_key)

	# Kick players that haven't sent input within the timeout.
	var timeout_ticks := int(INPUT_TIMEOUT * Globals.TICK_RATE)
	for peer_id in players.keys():
		var state: ServerPlayerState = _player_states[peer_id]
		if sim_tick - state.last_input_tick > timeout_ticks:
			print("[SERVER] Kicking peer %d: no input for %.0fs" % [peer_id, INPUT_TIMEOUT])
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)

	# Broadcast world state (skip frozen peers in both entity list and recipients)
	var pkt = Proto.Packet.new()
	var diff = pkt.new_world_diff()
	diff.set_tick(current_tick)
	for peer_id in players:
		if _frozen_peers.has(peer_id):
			continue
		var player: CommonPlayer = players[peer_id]
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
		if _frozen_peers.has(peer_id):
			continue
		multiplayer.send_bytes(bytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_player_input():
		_handle_input(peer_id, pkt.get_player_input())
	elif pkt.has_input_batch():
		var batch = pkt.get_input_batch()
		for input in batch.get_inputs():
			_handle_input(peer_id, input)
	elif pkt.has_clock_ping():
		_handle_clock_ping(peer_id, pkt.get_clock_ping())
	elif pkt.has_zone_arrival():
		_handle_zone_arrival(peer_id, pkt.get_zone_arrival())

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
		# TODO: send back notice that the input was LATE (so client can adjust their clock/tick)
		return
	if input_tick > current_tick + INPUT_FUTURE_LIMIT:
		# Input claims to be way too far in the future — suspicious or clock desync
		print("[SERVER] FUTURE input from peer %d: input_tick=%d current=%d (dropped)" % [peer_id, input_tick, current_tick])
		# TODO: send back notice that the input was FUTURE (so client can adjust their clock/tick)
		return

	# Buffer the input
	if not _input_buffers.has(peer_id):
		_input_buffers[peer_id] = {}

	_input_buffers[peer_id][input_tick] = {
		"input_x": input.get_input_x(),
		"input_z": input.get_input_z(),
		"jump_pressed": input.get_jump_pressed(),
	}

	var state: ServerPlayerState = _player_states[peer_id]
	state.last_input_tick = input_tick
	state.has_received_input = true

func _on_peer_connected(id: int) -> void:
	if id == 1:
		return  # server's own peer — not a real client
	print("[SERVER] Peer connected: %d" % id)
	# Don't spawn yet if the client might be a zone transfer arrival.
	# They'll send a ZoneArrival packet or regular input; we handle both.
	# For now, spawn at default position. ZoneArrival handling will override.
	_spawn_player(id, SPAWN_POSITION)

func _on_peer_disconnected(id: int) -> void:
	print("[SERVER] Peer disconnected: %d" % id)
	_remove_player(id)

func _spawn_player(id: int, position: Vector3, rot_y: float = 0.0) -> void:
	var player := ServerPlayerScene.instantiate() as CommonPlayer
	player.name = "ServerPlayer_%d" % id
	_entities.add_child(player)
	player.global_position = position
	player.rotation.y = rot_y
	players[id] = player
	var state := player.get_node("ServerPlayerState") as ServerPlayerState
	state.last_input_tick = NetworkTime.tick
	_player_states[id] = state
	_input_buffers[id] = {}

func _remove_player(id: int) -> void:
	_frozen_peers.erase(id)
	_border_immunity.erase(id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
		_player_states.erase(id)
	_input_buffers.erase(id)

# ── Zone Borders ──────────────────────────────────────────────────────────────

func _connect_zone_borders() -> void:
	var borders_node := get_parent().get_node_or_null("ZoneBorders")
	if not borders_node:
		return
	for child in borders_node.get_children():
		if child is ZoneBorder:
			child.body_entered.connect(_on_zone_border_entered.bind(child))

func _on_zone_border_entered(body: Node3D, border: ZoneBorder) -> void:
	var peer_id := _find_peer_for_body(body)
	if peer_id < 0:
		return
	if _frozen_peers.has(peer_id):
		return  # already transferring
	if _border_immunity.has(peer_id) and NetworkTime.tick < _border_immunity[peer_id]:
		return  # just arrived, immune to borders

	print("[SERVER] Peer %d entered zone border → %s (spawn_path='%s')" % [
		peer_id, border.target_zone_id, border.target_spawn_path])

	# Freeze the player immediately.
	_frozen_peers[peer_id] = true

	# Send transfer request to orchestrator.
	var player: CommonPlayer = players[peer_id]
	var pkt := Proto.OrchestratorPacket.new()
	var req := pkt.new_zone_transfer_request()
	req.set_peer_id(peer_id)
	req.set_from_zone_id(zone_id)
	req.set_to_zone_id(border.target_zone_id)
	req.set_entry_spawn_path(border.target_spawn_path)
	var state := req.new_player_state()
	state.set_pos_x(player.global_position.x)
	state.set_pos_y(player.global_position.y)
	state.set_pos_z(player.global_position.z)
	state.set_vel_x(player.velocity.x)
	state.set_vel_y(player.velocity.y)
	state.set_vel_z(player.velocity.z)
	state.set_rot_y(player.face_angle)
	_send_to_orchestrator(pkt)

func _handle_zone_arrival(peer_id: int, msg: Proto.ZoneArrival) -> void:
	var token: String = msg.get_transfer_token()
	if not _pending_arrivals.has(token):
		print("[SERVER] ZoneArrival with unknown token from peer %d" % peer_id)
		return

	var arrival: Dictionary = _pending_arrivals[token]
	_pending_arrivals.erase(token)

	# Resolve spawn point from the world scene.
	var spawn_path: String = arrival["entry_spawn_path"]
	var spawn_node: Node3D = get_parent().get_node_or_null(spawn_path) as Node3D
	if spawn_node == null:
		printerr("[SERVER] Spawn path '%s' not found — using default spawn" % spawn_path)
		spawn_node = null

	if players.has(peer_id):
		var player: CommonPlayer = players[peer_id]
		if spawn_node:
			player.global_position = spawn_node.global_position
			player.rotation.y = spawn_node.rotation.y
		else:
			player.global_position = SPAWN_POSITION
		player.velocity = Vector3.ZERO
		_border_immunity[peer_id] = NetworkTime.tick + BORDER_IMMUNITY_TICKS
		var pos := player.global_position
		print("[SERVER] Peer %d arrived via zone transfer at %s (spawn='%s')" % [peer_id, pos, spawn_path])

func _find_peer_for_body(body: Node3D) -> int:
	for peer_id in players:
		if players[peer_id] == body:
			return peer_id
	return -1
