class_name BackendAPI
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@export var PORT = 7000
@export var DEFAULT_SERVER_IP = "127.0.0.1"
@export var ORCHESTRATOR_URL: String = "ws://127.0.0.1:9001"

signal connected_to_server
signal disconnected_from_server
signal world_diff_received(diff: Proto.WorldDiff)
signal zone_redirect_received(zone_id: String, address: String, port: int, token: String)
signal player_spawn_received(pos: Vector3, rot_y: float)

var _orch_ws: WebSocketPeer = null
var _orch_connected: bool = false

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	_connect_to_orchestrator()

func _connect_to_orchestrator() -> void:
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

var _packets_received: int = 0

func _on_packet(_peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_world_diff():
		var diff = pkt.get_world_diff()
		_packets_received += 1
		world_diff_received.emit(diff)
	elif pkt.has_clock_pong():
		%NetworkClock.on_clock_pong(pkt.get_clock_pong())
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
