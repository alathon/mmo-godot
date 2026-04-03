extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const ServerPlayerScene = preload("res://src/game-server/ServerPlayer.tscn")

var zone_id: String = ""
@export var PORT: int = 7000
@export var MAX_CLIENTS: int = 32
@export var ORCHESTRATOR_URL: String = "ws://127.0.0.1:9000"

## How many ticks a player is immune to zone borders after arriving.
const BORDER_IMMUNITY_TICKS := 40  # 2 seconds at 20 tick/s

## peer_id -> ServerPlayer node
var players: Dictionary[int, CommonPlayer] = {}

## Peers frozen during zone transfer (excluded from simulation and broadcast).
var _frozen_peers: Dictionary[int, bool] = {}

## Peers with zone border immunity after arrival: peer_id -> expiry tick.
var _border_immunity: Dictionary[int, int] = {}

## transfer_token -> { peer_id, target_zone_id, target_address, target_port }
var _pending_redirects: Dictionary[String, Dictionary] = {}

## transfer_token -> { player_state, entry_x/y/z, entry_rot_y }
## Players arriving via zone transfer — token validated on connect.
var _pending_arrivals: Dictionary[String, Dictionary] = {}

@onready var _input_system: InputSystem = %InputSystem
@onready var _movement_system: MovementSystem = %MovementSystem
@onready var _combat_system: CombatSystem = %CombatSystem
@onready var _zone_container: Node3D = %ZoneContainer

var _current_zone: Node = null
var _entities: Node = null

## Raw WebSocket connection to the orchestrator.
var _orch_ws: WebSocketPeer = null
var _orch_connected: bool = false

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_user_args()
	print("Args: %s" % args)
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size():
			PORT = int(args[i + 1])
		elif args[i] == "--zone" and i + 1 < args.size():
			zone_id = args[i + 1]

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

	# TODO: For now. Can't find a way to pass to get_cmdline_user_args() in debug start, argh...
	if zone_id.is_empty():
		zone_id = "forest"

	if zone_id.is_empty() or not Globals.ZONE_SCENES.has(zone_id):
		printerr("[SERVER] Invalid zone_id '%s'. Must be one of: %s" % [zone_id, Globals.ZONE_SCENES.keys()])
		get_tree().quit(1)
		return

	_load_zone(zone_id)
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

func _load_zone(id: String) -> void:
	if _current_zone:
		_current_zone.queue_free()
		_current_zone = null
		_entities = null
	var scene_path: String = Globals.ZONE_SCENES[id]
	var scene := load(scene_path) as PackedScene
	_current_zone = scene.instantiate()
	_zone_container.add_child(_current_zone)
	_entities = _current_zone.get_node("Entities")
	print("[SERVER] Loaded zone scene: %s" % scene_path)

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

	var pkt := Proto.Packet.new()
	var redirect := pkt.new_zone_redirect()
	redirect.set_zone_id(target_zone)
	redirect.set_address(address)
	redirect.set_port(port)
	redirect.set_transfer_token(token)
	multiplayer.send_bytes(pkt.to_bytes(), enet_peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

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

	var pkt := Proto.OrchestratorPacket.new()
	var ack := pkt.new_prepare_player_ack()
	ack.set_transfer_token(token)
	ack.set_accepted(true)
	_send_to_orchestrator(pkt)

# ── Tick Loop ─────────────────────────────────────────────────────────────────

func _tick(_delta: float, current_tick: int) -> void:
	var sim_tick := current_tick - Globals.INPUT_BUFFER_SIZE

	var tick_data := _input_system.tick(sim_tick, players, _frozen_peers)

	for peer_id in tick_data["kick_peers"]:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)

	_movement_system.tick(players, tick_data["inputs"])

	_combat_system.tick(sim_tick, current_tick, players,
			tick_data["ability_inputs"], tick_data["moving_entities"], _frozen_peers)

	# Unreliable broadcast: positions only
	var upkt = Proto.Packet.new()
	var wpos = upkt.new_world_positions()
	wpos.set_tick(current_tick)
	for peer_id in players:
		var player: CommonPlayer = players[peer_id]
		var ep = wpos.add_entities()
		ep.set_entity_id(peer_id)
		ep.set_pos_x(player.global_position.x)
		ep.set_pos_y(player.global_position.y)
		ep.set_pos_z(player.global_position.z)
		ep.set_vel_x(player.velocity.x)
		ep.set_vel_y(player.velocity.y)
		ep.set_vel_z(player.velocity.z)
		ep.set_rot_y(player.face_angle)
	var ubytes = upkt.to_bytes()
	for peer_id in players:
		if not _frozen_peers.has(peer_id):
			multiplayer.send_bytes(ubytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

# ── Packet Handling ────────────────────────────────────────────────────────────

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_player_input():
		_input_system.handle_packet(peer_id, pkt.get_player_input(), players, _frozen_peers)
	elif pkt.has_input_batch():
		for input in pkt.get_input_batch().get_inputs():
			_input_system.handle_packet(peer_id, input, players, _frozen_peers)
	elif pkt.has_clock_ping():
		_handle_clock_ping(peer_id, pkt.get_clock_ping())
	elif pkt.has_zone_arrival():
		_handle_zone_arrival(peer_id, pkt.get_zone_arrival())
	elif pkt.has_target_select():
		_combat_system.handle_target_select(
				peer_id, pkt.get_target_select().get_target_entity_id(), players)

func _handle_clock_ping(peer_id: int, ping: Proto.ClockPing) -> void:
	var pkt = Proto.Packet.new()
	var pong = pkt.new_clock_pong()
	pong.set_ping_id(ping.get_ping_id())
	pong.set_client_time(ping.get_client_time())
	pong.set_server_time(Time.get_unix_time_from_system())
	pong.set_server_tick(NetworkTime.tick)
	multiplayer.send_bytes(pkt.to_bytes(), peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

# ── Player Lifecycle ───────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	if id == 1:
		return  # server's own peer — not a real client
	print("[SERVER] Peer connected: %d (waiting for ZoneArrival)" % id)

func _on_peer_disconnected(id: int) -> void:
	print("[SERVER] Peer disconnected: %d" % id)
	_remove_player(id)

func _spawn_player(id: int, position: Vector3, rot_y: float = 0.0) -> void:
	print("[SERVER] Spawning player %d at %s" % [id, position])
	var player := ServerPlayerScene.instantiate() as CommonPlayer
	player.name = "ServerPlayer_%d" % id
	_entities.add_child(player)
	player.global_position = position
	player.rotation.y = rot_y
	players[id] = player
	var state := player.get_node("PlayerInputState") as PlayerInputState
	state.last_input_tick = NetworkTime.tick
	_input_system.on_player_added(id)

func _remove_player(id: int) -> void:
	_frozen_peers.erase(id)
	_border_immunity.erase(id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
		_input_system.on_player_removed(id)
	_pending_redirects.erase(id)

# ── Zone Borders ───────────────────────────────────────────────────────────────

func _connect_zone_borders() -> void:
	for border in get_tree().get_nodes_in_group("zone_borders"):
		if border is ZoneBorder:
			border.body_entered.connect(_on_zone_border_entered.bind(border))

func _on_zone_border_entered(body: Node3D, border: ZoneBorder) -> void:
	var peer_id := _find_peer_for_body(body)
	if peer_id < 0:
		return
	if _frozen_peers.has(peer_id):
		return
	if _border_immunity.has(peer_id) and NetworkTime.tick < _border_immunity[peer_id]:
		return

	print("[SERVER] Peer %d entered zone border → %s (spawn_path='%s')" % [
		peer_id, border.target_zone_id, border.target_spawn_path])

	_frozen_peers[peer_id] = true
	print("[SERVER] peer=%d FROZEN for zone transfer at pos=%s" % [peer_id, players[peer_id].global_position])
	var player: CommonPlayer = players[peer_id]
	player.velocity = Vector3.ZERO
	_input_system.on_player_added(peer_id)  # clear input buffer
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

	var spawn_path: String = arrival["entry_spawn_path"]
	var spawn_node: Node3D = null
	if not spawn_path.is_empty():
		spawn_node = _current_zone.get_node_or_null(spawn_path) as Node3D
		if spawn_node == null:
			printerr("[SERVER] Spawn path '%s' not found — falling back to player_state pos" % spawn_path)

	var spawn_pos: Vector3 = spawn_node.global_position if spawn_node else arrival["pos"]
	print("[SERVER] _handle_zone_arrival() spawn_pos=%s" % spawn_pos)
	var spawn_rot: float = spawn_node.rotation.y if spawn_node else arrival["rot_y"]
	if not players.has(peer_id):
		_spawn_player(peer_id, spawn_pos, spawn_rot)
	else:
		var player: CommonPlayer = players[peer_id]
		player.global_position = spawn_pos
		player.rotation.y = spawn_rot
		player.velocity = Vector3.ZERO
		var state := player.get_node("PlayerInputState") as PlayerInputState
		state.first_input_tick = -1
		_input_system.on_player_added(peer_id)  # reset input buffer
	_border_immunity[peer_id] = NetworkTime.tick + BORDER_IMMUNITY_TICKS
	print("[SERVER] peer=%d ARRIVED at pos=%s rot_y=%.2f spawn_path='%s'" % [peer_id, spawn_pos, spawn_rot, spawn_path])

	var spawn_pkt := Proto.Packet.new()
	var ps := spawn_pkt.new_player_spawn()
	ps.set_pos_x(spawn_pos.x)
	ps.set_pos_y(spawn_pos.y)
	ps.set_pos_z(spawn_pos.z)
	ps.set_rot_y(spawn_rot)
	multiplayer.send_bytes(spawn_pkt.to_bytes(), peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _find_peer_for_body(body: Node3D) -> int:
	for peer_id in players:
		if players[peer_id] == body:
			return peer_id
	return -1
