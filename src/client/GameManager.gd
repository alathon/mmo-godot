extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemotePlayerScene = preload("res://src/client/Player/RemotePlayer.tscn")

const CORRECTION_THRESHOLD = 1.0

@onready var _network: Node = %Network
@onready var _local_player: LocalPlayer = %LocalPlayer
@onready var _entities: Node = %Entities

var _remote_players: Dictionary[int, RemotePlayer] = {}

func _ready() -> void:
	_network.world_diff_received.connect(_on_world_diff)

func _on_world_diff(diff: Proto.WorldDiff) -> void:
	var local_id := multiplayer.get_unique_id()
	var seen_ids := {}

	for entity in diff.get_entities():
		var id := entity.get_entity_id()
		
		seen_ids[id] = true
		if id == local_id:
			continue
		
		if not _remote_players.has(id):
			_spawn_remote_player(entity)
		else:
			_remote_players[id].on_entity_diff(entity)

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			_despawn_remote_player(id)

func _spawn_remote_player(entity: Proto.EntityState) -> void:
	print("[CLIENT] remote player appeared: %d" % entity.get_entity_id())
	var node := RemotePlayerScene.instantiate()
	_entities.add_child(node)
	_remote_players[entity.get_entity_id()] = node
	node.on_entity_diff(entity)

func _despawn_remote_player(id: int) -> void:
	print("[CLIENT] remote player left: %d" % id)
	_remote_players[id].queue_free()
	_remote_players.erase(id)
