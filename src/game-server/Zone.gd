extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

@export var PORT = 7000
@export var DEFAULT_SERVER_IP = "127.0.0.1"
@export var MAX_CLIENTS = 32
@export var TICK_MS = 50 / 1000

var players = {}

var currentTick = 0
var elapsedMs = 0
var server_info = {"tick": 325, "otherStuff": "hi"}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error:
		printerr(error)
		return

	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	print("Game server Zone scene loaded!")

func _tick(delta: float) -> void:
	currentTick += 1
	print("[SERVER] Tick %d" % currentTick)

func _process(delta: float) -> void:
	elapsedMs += delta
	while(elapsedMs > TICK_MS):
		elapsedMs -= TICK_MS
		_tick(elapsedMs)

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	print("[SERVER] _on_player_connected(%s)" % [id])
	%RPC.server_tick.rpc_id(id, server_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	print("[SERVER] on_player_disconnected(%s)" % [id])
	#players.erase(id)
	player_disconnected.emit(id)
