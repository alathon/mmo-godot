class_name BackendAPI
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@export var PORT = 9002
@export var DEFAULT_SERVER_IP = "127.0.0.1"
var ORCHESTRATOR_URL: String = "ws://127.0.0.1:9001"

signal connected_to_server
signal disconnected_from_server
signal ability_use_accepted(ack: Proto.AbilityUseAccepted)
signal ability_use_rejected(rejection: Proto.AbilityUseRejected)
signal world_state_received(diff: Proto.WorldState)
signal world_positions_received(diff: Proto.WorldPositions)
signal zone_redirect_received(zone_id: String, address: String, port: int, token: String)
signal player_spawn_received(pos: Vector3, rot_y: float)

var _orch_ws: WebSocketPeer = null
var _orch_connected: bool = false

func _ready() -> void:
	_load_config()
	_parse_cmdline_args()  # CLI args override config file
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	_connect_to_orchestrator()

func _load_config() -> void:
	var config := ConfigFile.new()
	# Look next to the executable first, then fall back to res://
	var exe_dir := OS.get_executable_path().get_base_dir()
	var path := exe_dir.path_join("client_config.cfg")
	print("[CLIENT] Looking for config at: %s" % path)
	if config.load(path) != OK:
		print("[CLIENT] Not found, trying res://client_config.cfg")
		path = "res://client_config.cfg"
		if config.load(path) != OK:
			print("[CLIENT] No config file found, using defaults")
			return
	print("[CLIENT] Loaded config from %s" % path)
	ORCHESTRATOR_URL = config.get_value("network", "orchestrator_url", ORCHESTRATOR_URL)

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--orchestrator" and i + 1 < args.size():
			ORCHESTRATOR_URL = args[i + 1]

func _connect_to_orchestrator() -> void:
	print("[CLIENT] Connecting to orchestrator at: %s" % ORCHESTRATOR_URL)
	_orch_ws = WebSocketPeer.new()
	var error := _orch_ws.connect_to_url(ORCHESTRATOR_URL)
	if error != OK:
		printerr("[CLIENT] Failed to connect to orchestrator: %s" % error)
		_orch_ws = null

func _process(_delta: float) -> void:
	if _orch_ws == null:
		return
	_orch_ws.poll()
	var state := _orch_ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _orch_connected:
			_orch_connected = true
			print("[CLIENT] Connected to orchestrator, sending LoginRequest")
			var pkt := Proto.Packet.new()
			var req := pkt.new_login_request()
			req.set_username("player")
			_orch_ws.send(pkt.to_bytes(), WebSocketPeer.WRITE_MODE_BINARY)
		while _orch_ws.get_available_packet_count() > 0:
			_on_orchestrator_packet(_orch_ws.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED:
		var code := _orch_ws.get_close_code()
		var reason := _orch_ws.get_close_reason()
		print("[CLIENT] Orchestrator WebSocket closed (code=%d, reason='%s')" % [code, reason])
		_orch_ws = null
		_orch_connected = false

func _on_orchestrator_packet(bytes: PackedByteArray) -> void:
	var pkt := Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_zone_redirect():
		var redirect := pkt.get_zone_redirect()
		zone_redirect_received.emit(
			redirect.get_zone_id(),
			redirect.get_address(),
			redirect.get_port(),
			redirect.get_transfer_token()
		)

func _join(address: String = "", port: int = 0) -> void:
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	if port == 0:
		port = PORT
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error:
		printerr("[CLIENT] Failed to connect: %s" % error)
		return
	multiplayer.multiplayer_peer = peer

func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func reconnect(address: String, port: int) -> void:
	disconnect_from_server()
	_join(address, port)

func send_clock_ping(ping_id: int, client_time: float) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var pkt = Proto.Packet.new()
	var ping = pkt.new_clock_ping()
	ping.set_ping_id(ping_id)
	ping.set_client_time(client_time)
	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_input(input_x: float, input_z: float, jump_pressed: bool, rot_y: float, tick: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var pkt = Proto.Packet.new()
	var input = pkt.new_player_input()
	input.set_input_x(input_x)
	input.set_input_z(input_z)
	input.set_jump_pressed(jump_pressed)
	input.set_tick(tick)
	input.set_rot_y(rot_y)
	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func send_zone_arrival(token: String) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var pkt = Proto.Packet.new()
	var arrival = pkt.new_zone_arrival()
	arrival.set_transfer_token(token)
	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_target_select(entity_id: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var pkt = Proto.Packet.new()
	var target_select = pkt.new_target_select()
	target_select.set_target_entity_id(entity_id)
	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

var _packets_received: int = 0

func _on_packet(_peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_world_state():
		var diff = pkt.get_world_state()
		_packets_received += 1
		world_state_received.emit(diff)
	elif pkt.has_world_positions():
		var diff = pkt.get_world_positions()
		_packets_received += 1
		world_positions_received.emit(diff)
	elif pkt.has_clock_pong():
		%NetworkClock.on_clock_pong(pkt.get_clock_pong())
	elif pkt.has_ability_accepted():
		ability_use_accepted.emit(pkt.get_ability_accepted())
	elif pkt.has_ability_rejected():
		ability_use_rejected.emit(pkt.get_ability_rejected())
	elif pkt.has_zone_redirect():
		var redirect := pkt.get_zone_redirect()
		zone_redirect_received.emit(
			redirect.get_zone_id(),
			redirect.get_address(),
			redirect.get_port(),
			redirect.get_transfer_token()
		)
	elif pkt.has_player_spawn():
		var ps := pkt.get_player_spawn()
		player_spawn_received.emit(Vector3(ps.get_pos_x(), ps.get_pos_y(), ps.get_pos_z()), ps.get_rot_y())

func _on_connected() -> void:
	print("[CLIENT] Connected to server")
	connected_to_server.emit()

func _on_connection_failed() -> void:
	printerr("[CLIENT] Connection failed")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _on_disconnected() -> void:
	print("[CLIENT] Disconnected from server")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	disconnected_from_server.emit()
