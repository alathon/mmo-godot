extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemotePlayerScene = preload("res://src/client/Player/Player.tscn")

const CORRECTION_THRESHOLD = 1.0

@onready var _network: Node = %Network
@onready var _local_player: CharacterBody3D = %LocalPlayer
@onready var _entities: Node = %Entities

var _remote_players: Dictionary = {}  # entity_id -> Node

func _ready() -> void:
	_network.world_diff_received.connect(_on_world_diff)

func _on_world_diff(diff: Proto.WorldDiff) -> void:
	var local_id := multiplayer.get_unique_id()
	var seen_ids := {}

	for entity in diff.get_entities():
		var id := entity.get_entity_id()
		var pos := Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
		seen_ids[id] = true

		if id == local_id:
			_apply_correction(pos)
		else:
			if not _remote_players.has(id):
				_spawn_remote_player(id, pos)
			else:
				_remote_players[id].set_target_position(pos)

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			_despawn_remote_player(id)

func _apply_correction(server_pos: Vector3) -> void:
	if _local_player.global_position.distance_to(server_pos) > CORRECTION_THRESHOLD:
		print("[CLIENT] server correction: %.2f units, snapping" % _local_player.global_position.distance_to(server_pos))
		_local_player.global_position = server_pos

func _spawn_remote_player(id: int, pos: Vector3) -> void:
	print("[CLIENT] remote player appeared: %d at %s" % [id, pos])
	var node := RemotePlayerScene.instantiate()
	node.global_position = pos
	_entities.add_child(node)
	_remote_players[id] = node

func _despawn_remote_player(id: int) -> void:
	print("[CLIENT] remote player left: %d" % id)
	_remote_players[id].queue_free()
	_remote_players.erase(id)
