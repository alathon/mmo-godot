extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemotePlayerScene = preload("res://src/client/Player/RemotePlayer.tscn")

const CORRECTION_THRESHOLD = 1.0

@onready var _network: Node = %Network
@onready var _local_player: Player = %LocalPlayer
@onready var _entities: Node = %Entities

var _remote_players: Dictionary[int, Player] = {}

func _ready() -> void:
	_network.world_diff_received.connect(_on_world_diff)

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
	print("[CLIENT] remote player appeared: %d" % entity.get_entity_id())
	var node := RemotePlayerScene.instantiate()
	node.name = "RemotePlayer_%d" % entity.get_entity_id()
	_entities.add_child(node)
	_remote_players[entity.get_entity_id()] = node
	node.on_entity_diff(entity, tick)

func _despawn_remote_player(id: int) -> void:
	print("[CLIENT] remote player left: %d" % id)
	_remote_players[id].queue_free()
	_remote_players.erase(id)

func _test_displacement() -> void:
	for id in _remote_players:
		var player := _remote_players[id]
		# Push away from local player
		var dir := (player.global_position - _local_player.global_position).normalized()
		dir.y = 0.0
		player.apply_displacement(dir * 15.0)
		print("[TEST] Displacement applied to %s" % player.name)
