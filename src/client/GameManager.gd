extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemotePlayerScene = preload("res://src/client/Player/RemotePlayer.tscn")

const CORRECTION_THRESHOLD = 1.0

@onready var _network: Node = %Network
@onready var _local_player: Player = %LocalPlayer
@onready var _entities: Node = %Entities
@onready var _zone_container: Node3D = %ZoneContainer

var _remote_players: Dictionary[int, RemotePlayerController] = {}

var _current_zone: Node = null
var _pending_transfer_token: String = ""

func load_zone(zone_id: String) -> void:
	if _current_zone:
		_current_zone.queue_free()
		_current_zone = null
	var scene_path: String = Globals.ZONE_SCENES[zone_id]
	var scene := load(scene_path) as PackedScene
	_current_zone = scene.instantiate()
	_zone_container.add_child(_current_zone)
	# Strip server-only nodes (NPC spawners, etc.).
	for node in _current_zone.get_children():
		if node.is_in_group("server_only"):
			node.queue_free()
	_connect_zone_borders()

func _ready() -> void:
	_network.world_diff_received.connect(_on_world_diff)
	_network.zone_redirect_received.connect(_on_zone_redirect)
	_network.connected_to_server.connect(_on_connected_to_server)
	load_zone("forest")

func _connect_zone_borders() -> void:
	for border in get_tree().get_nodes_in_group("zone_borders"):
		if border is ZoneBorder:
			border.body_entered.connect(_on_zone_border_entered)

func _on_zone_border_entered(body: Node3D) -> void:
	if body == _local_player:
		_local_player.frozen = true
		_local_player.velocity = Vector3.ZERO

func _on_zone_redirect(zone_id: String, address: String, port: int, token: String) -> void:
	print("[CLIENT] Zone redirect → %s at %s:%d" % [zone_id, address, port])
	_pending_transfer_token = token

	# Clear all remote players.
	for id in _remote_players.keys():
		_despawn_remote_player(id)

	# Reset local player state.
	_local_player.frozen = false
	_local_player._input_history.clear()
	_local_player._pending_server_tick = -1

	# Load new zone visuals.
	load_zone(zone_id)

	# Reconnect to the new server.
	_network.reconnect(address, port)

func _on_connected_to_server() -> void:
	if _pending_transfer_token != "":
		print("[CLIENT] Sending ZoneArrival (token=%s)" % _pending_transfer_token)
		_network.send_zone_arrival(_pending_transfer_token)
		_pending_transfer_token = ""
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_test_displacement()

func _on_world_diff(diff: Proto.WorldDiff) -> void:
	var local_id := multiplayer.get_unique_id()
	var tick := diff.get_tick()
	var seen_ids := {}

	for entity in diff.get_entities():
		var id := entity.get_entity_id()

		seen_ids[id] = true
		if id == local_id:
			_local_player.on_entity_diff(entity, tick)
		elif not _remote_players.has(id):
			_spawn_remote_player(entity, tick)
		else:
			_remote_players[id].on_entity_diff(entity, tick)

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			_despawn_remote_player(id)

func _spawn_remote_player(entity: Proto.EntityState, tick: int) -> void:
	var node := RemotePlayerScene.instantiate()
	node.name = "RemotePlayer_%d" % entity.get_entity_id()
	_entities.add_child(node)
	_remote_players[entity.get_entity_id()] = node
	node.on_entity_diff(entity, tick)

func _despawn_remote_player(id: int) -> void:
	_remote_players[id].queue_free()
	_remote_players.erase(id)

func _test_displacement() -> void:
	for id in _remote_players:
		var player := _remote_players[id]
		# Push away from local player
		var dir := (player.global_position - _local_player.global_position).normalized()
		dir.y = 0.0
		player.apply_displacement(dir * 15.0)
