extends Node

const Proto = preload("res://src/common/proto/proto.gd")

@export var PORT = 7000
@export var DEFAULT_SERVER_IP = "127.0.0.1"

signal connected_to_server
signal disconnected_from_server
signal world_diff_received(diff: Proto.WorldDiff)

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	_join()

func _join(address: String = "") -> void:
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		printerr("[CLIENT] Failed to connect: %s" % error)
		return
	multiplayer.multiplayer_peer = peer

func send_input(input_x: float, input_z: float, jump_pressed: bool) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			return
	var pkt = Proto.Packet.new()
	var input = pkt.new_player_input()
	input.set_input_x(input_x)
	input.set_input_z(input_z)
	input.set_jump_pressed(jump_pressed)
	multiplayer.send_bytes(pkt.to_bytes(), 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

var _packets_received: int = 0

func _on_packet(_peer_id: int, bytes: PackedByteArray) -> void:
	var pkt = Proto.Packet.new()
	pkt.from_bytes(bytes)
	if pkt.has_world_diff():
		var diff = pkt.get_world_diff()
		_packets_received += 1
		if _packets_received % 20 == 1:
			print("[CLIENT] world_diff tick=%d entities=%d (packet #%d)" % [
				diff.get_tick(), diff.get_entities().size(), _packets_received
			])
		world_diff_received.emit(diff)

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
