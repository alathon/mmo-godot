class_name GameManager
extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemoteEntityScene = preload("res://src/client/RemoteEntity.tscn")
const LocalPlayerScene = preload("res://src/client/Player/Player.tscn")

const CORRECTION_THRESHOLD = 1.0

signal local_player_spawned(player: Player)
signal remote_player_spawned(player: RemoteEntity)
@onready var _api: BackendAPI = %BackendAPI
@onready var _zone_container: ZoneContainer = $"../../ZoneContainer"

@export var BotMode: bool = false

var _pending_transfer_token: String = ""
var _awaiting_initial_clock_sync: bool = true
var _local_player: Player
var _remote_players: Dictionary[int, RemoteEntity]

func _ready() -> void:
	Engine.physics_ticks_per_second = Globals.TICK_RATE

	_api.world_positions_received.connect(_on_world_positions)
	_api.world_state_received.connect(_on_world_state)
	_api.zone_redirect_received.connect(_on_zone_redirect)
	_api.player_spawn_received.connect(_on_player_spawn)
	_api.connected_to_server.connect(_on_connected_to_server)
	_zone_container.zone_border_entered.connect(_on_zone_border_entered)
	NetworkTime.after_sync.connect(_on_clock_synced)

func _on_clock_synced() -> void:
	# If this is the first 'fresh' clock sync, unfreeze player
	if _awaiting_initial_clock_sync and _local_player:
		_local_player.unfreeze()
		_awaiting_initial_clock_sync = false

func _on_zone_border_entered(node: Variant):
	var player := node.get_parent() as Player if node is PhysicsBody else null
	if player:
		player.freeze()

func _on_zone_redirect(zone_id: String, address: String, port: int, token: String) -> void:
	print("[CLIENT] Zone redirect → %s at %s:%d" % [zone_id, address, port])
	_pending_transfer_token = token
	_awaiting_initial_clock_sync = true

	_remote_players.clear()
	_local_player = null

	if _zone_container:
		_zone_container.unload_zone()
		_zone_container.load_zone(zone_id)

	# Connect to new server.
	_api.reconnect(address, port)

func _on_connected_to_server() -> void:
	if _pending_transfer_token != "":
		print("[CLIENT] Sending ZoneArrival (token=%s)" % _pending_transfer_token)
		_api.send_zone_arrival(_pending_transfer_token)
		_pending_transfer_token = ""

func _on_player_spawn(pos: Vector3, rot_y: float) -> void:
	if BotMode == true:
		_local_player = (load("res://src/client/Player/BotPlayer.tscn")).instantiate() as Player
	else:
		_local_player = LocalPlayerScene.instantiate() as Player
	
	_zone_container.add_entity(_local_player)
	_local_player.setCharacterModel("Wizard")
	_local_player.name = "LocalPlayer"
	_local_player.id = multiplayer.get_unique_id()
	var body = _local_player.get_node("Body");
	body.position = pos
	body.rotation.y = rot_y
	local_player_spawned.emit(_local_player)

func get_local_player_id() -> int:
	return multiplayer.get_unique_id()

func _on_world_state(diff: Proto.WorldState) -> void:
	return

# TODO: Move local player instantiation from variables somewhere more sensible.
# This method should just get a RemoteEntity ref, which it'll then
# e.g., add to _entities and trigger a spawn event etc.
func _spawn_remote_player(id: int, pos: Vector3, rot_y: float) -> void:
	var node: RemoteEntity = RemoteEntityScene.instantiate()
	_zone_container.add_entity(node)
	node.name = "RemotePlayer_%d" % id
	node.id = id
	_remote_players[id] = node
	node.initialize_position(pos, rot_y)
	node.setCharacterModel("Wizard")  # TODO: Get model name from server
	remote_player_spawned.emit(node)

func _despawn_remote_player(id: int) -> void:
	print("Despawn remote player %d called" % id)
	_remote_players[id].queue_free()
	_remote_players.erase(id)

func _on_world_positions(diff: Proto.WorldPositions) -> void:
	var local_id := multiplayer.get_unique_id() # TODO: Are we sure it should be the unique ID from this node?? Feels iffy.
	var tick: int = diff.get_tick()
	var seen_ids := {}

	for entity in diff.get_entities():
		var id := entity.get_entity_id()
		var pos := Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
		var rot := entity.get_rot_y()
		seen_ids[id] = true
		if id == local_id:
			if _local_player != null:
				# TODO: Change on_entity_position_diff to not take a Proto message but the resolved
				# values?
				_local_player.on_entity_position_diff(entity, tick)
		elif not _remote_players.has(id):
			_spawn_remote_player(id, pos, rot)
		else:
			# TODO: Change on_entity_position_diff to not take a Proto message but the resolved
			# values?
			_remote_players[id].on_entity_position_diff(entity, tick)

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			print("Despawning remote player %d as they're no longer present in WorldPositions" % id)
			_despawn_remote_player(id)
