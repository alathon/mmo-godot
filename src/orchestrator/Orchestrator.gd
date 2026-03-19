extends Node

## Central orchestrator that manages zone server registration and player
## zone transfers. Runs as a headless Godot instance with a WebSocket server.
## Game servers connect on startup and send OrchestratorPacket messages.

const Proto = preload("res://src/common/proto/packets.gd")

@export var PORT: int = 9000

## Transfer tokens expire after this many seconds.
const TOKEN_TIMEOUT := 30.0

## Registered zone servers: zone_id -> { peer_id, address, port, max_players, current_players }
var _zones: Dictionary[String, Dictionary] = {}

## WebSocket peer_id -> zone_id (reverse lookup)
var _peer_zones: Dictionary[int, String] = {}

## Pending transfers: transfer_token -> { from_zone_id, to_zone_id, peer_id, player_state,
##   entry_x, entry_y, entry_z, entry_rot_y, origin_ws_peer, dest_ws_peer, created_at }
var _pending_transfers: Dictionary[String, Dictionary] = {}

var _ws_server: WebSocketMultiplayerPeer = null

func _ready() -> void:
	_ws_server = WebSocketMultiplayerPeer.new()
	var error := _ws_server.create_server(PORT)
	if error != OK:
		printerr("[ORCHESTRATOR] Failed to start WebSocket server on port %d: %s" % [PORT, error])
		return
	multiplayer.multiplayer_peer = _ws_server
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_packet.connect(_on_packet)
	print("[ORCHESTRATOR] Listening on port %d" % PORT)

func _process(_delta: float) -> void:
	_expire_tokens()

func _expire_tokens() -> void:
	var now := Time.get_unix_time_from_system()
	for token in _pending_transfers.keys():
		var transfer: Dictionary = _pending_transfers[token]
		if now - transfer["created_at"] > TOKEN_TIMEOUT:
			print("[ORCHESTRATOR] Transfer token expired: %s" % token)
			_pending_transfers.erase(token)

func _on_peer_connected(peer_id: int) -> void:
	print("[ORCHESTRATOR] Game server connected: peer %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[ORCHESTRATOR] Game server disconnected: peer %d" % peer_id)
	if _peer_zones.has(peer_id):
		var zone_id: String = _peer_zones[peer_id]
		_zones.erase(zone_id)
		_peer_zones.erase(peer_id)
		print("[ORCHESTRATOR] Unregistered zone '%s'" % zone_id)

func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pkt := Proto.OrchestratorPacket.new()
	pkt.from_bytes(bytes)
	if pkt.has_zone_register():
		_handle_zone_register(peer_id, pkt.get_zone_register())
	elif pkt.has_zone_transfer_request():
		_handle_zone_transfer_request(peer_id, pkt.get_zone_transfer_request())
	elif pkt.has_prepare_player_ack():
		_handle_prepare_player_ack(peer_id, pkt.get_prepare_player_ack())

# ── Zone Registration ─────────────────────────────────────────────────────────

func _handle_zone_register(peer_id: int, msg: Proto.ZoneRegister) -> void:
	var zone_id: String = msg.get_zone_id()
	_zones[zone_id] = {
		"peer_id": peer_id,
		"address": msg.get_address(),
		"port": msg.get_port(),
		"max_players": msg.get_max_players(),
		"current_players": msg.get_current_players(),
	}
	_peer_zones[peer_id] = zone_id
	print("[ORCHESTRATOR] Registered zone '%s' at %s:%d (peer %d)" % [
		zone_id, msg.get_address(), msg.get_port(), peer_id])

# ── Zone Transfer ─────────────────────────────────────────────────────────────

func _handle_zone_transfer_request(origin_peer: int, msg: Proto.ZoneTransferRequest) -> void:
	var to_zone: String = msg.get_to_zone_id()
	var from_zone: String = msg.get_from_zone_id()
	var game_peer_id: int = msg.get_peer_id()

	if not _zones.has(to_zone):
		print("[ORCHESTRATOR] Transfer rejected: zone '%s' not registered" % to_zone)
		# TODO: send rejection back to origin so it can unfreeze the player.
		return

	var dest: Dictionary = _zones[to_zone]
	var token := _generate_token()

	_pending_transfers[token] = {
		"from_zone_id": from_zone,
		"to_zone_id": to_zone,
		"peer_id": game_peer_id,
		"player_state": msg.get_player_state(),
		"entry_x": msg.get_entry_x(),
		"entry_y": msg.get_entry_y(),
		"entry_z": msg.get_entry_z(),
		"entry_rot_y": msg.get_entry_rot_y(),
		"origin_ws_peer": origin_peer,
		"dest_ws_peer": dest["peer_id"],
		"created_at": Time.get_unix_time_from_system(),
	}

	print("[ORCHESTRATOR] Transfer: peer %d from '%s' → '%s' (token=%s)" % [
		game_peer_id, from_zone, to_zone, token])

	# Send PreparePlayer to destination server.
	var pkt := Proto.OrchestratorPacket.new()
	var prepare := pkt.new_prepare_player()
	prepare.set_transfer_token(token)
	prepare.set_entry_x(msg.get_entry_x())
	prepare.set_entry_y(msg.get_entry_y())
	prepare.set_entry_z(msg.get_entry_z())
	prepare.set_entry_rot_y(msg.get_entry_rot_y())
	# Copy player state fields.
	var src_state := msg.get_player_state()
	var dst_state := prepare.new_player_state()
	dst_state.set_pos_x(src_state.get_pos_x())
	dst_state.set_pos_y(src_state.get_pos_y())
	dst_state.set_pos_z(src_state.get_pos_z())
	dst_state.set_vel_x(src_state.get_vel_x())
	dst_state.set_vel_y(src_state.get_vel_y())
	dst_state.set_vel_z(src_state.get_vel_z())
	dst_state.set_rot_y(src_state.get_rot_y())

	_send_to_peer(dest["peer_id"], pkt)

func _handle_prepare_player_ack(dest_peer: int, msg: Proto.PreparePlayerAck) -> void:
	var token: String = msg.get_transfer_token()
	if not _pending_transfers.has(token):
		print("[ORCHESTRATOR] PreparePlayerAck for unknown token: %s" % token)
		return

	var transfer: Dictionary = _pending_transfers[token]

	if not msg.get_accepted():
		print("[ORCHESTRATOR] Destination rejected transfer (token=%s)" % token)
		_pending_transfers.erase(token)
		# TODO: send rejection back to origin so it can unfreeze the player.
		return

	var dest: Dictionary = _zones[transfer["to_zone_id"]]

	# Send ZoneTransferResponse to origin server so it can redirect the client.
	var pkt := Proto.OrchestratorPacket.new()
	var resp := pkt.new_zone_transfer_response()
	resp.set_peer_id(transfer["peer_id"])
	resp.set_transfer_token(token)
	resp.set_target_address(dest["address"])
	resp.set_target_port(dest["port"])
	resp.set_zone_id(transfer["to_zone_id"])

	_send_to_peer(transfer["origin_ws_peer"], pkt)
	print("[ORCHESTRATOR] Redirect sent to origin for peer %d (token=%s)" % [
		transfer["peer_id"], token])
	# Token stays in _pending_transfers until the client connects or it expires.

# ── Helpers ───────────────────────────────────────────────────────────────────

func _send_to_peer(peer_id: int, pkt: Proto.OrchestratorPacket) -> void:
	multiplayer.send_bytes(pkt.to_bytes(), peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _generate_token() -> String:
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(randi() % 256)
	return bytes.hex_encode()
