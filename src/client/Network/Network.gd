extends Node

@export var PORT = 7000
@export var DEFAULT_SERVER_IP = "127.0.0.1"

signal server_disconnected
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

var player_info = {"name": "Name"}

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	join_game()

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	if id == 1:
		return
	
	print("[CLIENT] _on_player_connected(%s)" % id)
	_register_player.rpc_id(id, player_info)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id):
	print("[CLIENT] _on_player_disconnected(%s)" % id)
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	print("[CLIENT] _on_connected_ok")
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	print("[CLIENT] _on_connected_fail")
	remove_multiplayer_peer()


func _on_server_disconnected():
	print("[CLIENT] _on_server_disconnected")
	remove_multiplayer_peer()
	players.clear()
	server_disconnected.emit()
