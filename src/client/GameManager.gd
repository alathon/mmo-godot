extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemotePlayerScene = preload("res://src/client/Player/RemotePlayer.tscn")
const LocalPlayerScene = preload("res://src/client/Player/LocalPlayer.tscn")

const CORRECTION_THRESHOLD = 1.0

@onready var _api: BackendAPI = %BackendAPI
@onready var _tick_interpolator: TickInterpolator = %TickInterpolator
@onready var _camera_pivot: Node3D = %CameraPivot

var _zone_container: ZoneContainer
var _local_player: Player = null
var _remote_players: Dictionary[int, RemotePlayerController] = {}
var _pending_transfer_token: String = ""

func _ready() -> void:
	_api.world_diff_received.connect(_on_world_diff)
	_api.zone_redirect_received.connect(_on_zone_redirect)
	_api.connected_to_server.connect(_on_connected_to_server)
	NetworkTime.after_sync.connect(_on_clock_synced)
	_zone_container = %ZoneContainer as ZoneContainer
	_zone_container.zone_border_entered.connect(_on_zone_border_entered)
	_zone_container.load_zone("forest")

func _swap_zone_container(zone_id: String) -> void:
	# Pull the local player out before freeing the container.
	if _local_player:
		_zone_container.entities.remove_child(_local_player)
	_zone_container.queue_free()
	_zone_container = ZoneContainer.new()
	_zone_container.name = "ZoneContainer"
	get_parent().add_child(_zone_container)
	_zone_container.zone_border_entered.connect(_on_zone_border_entered)
	_zone_container.load_zone(zone_id, _local_player)

func _on_zone_border_entered(body: Node3D) -> void:
	if body == _local_player:
		freeze_local_player()

func freeze_local_player() -> void:
	print("[CLIENT] Player frozen")
	_local_player.frozen = true
	_local_player.set_physics_process(false)
	_local_player.velocity = Vector3.ZERO
	# Clear prediction state immediately — no stale reconciliation while frozen.
	print("[CLIENT] Player input history and pending server tick cleared")
	_local_player._input_history.clear()
	_local_player._pending_server_tick = -1

func unfreeze_local_player() -> void:
	print("[CLIENT] Player unfrozen")
	_local_player.frozen = false
	_local_player.set_physics_process(true)
	# Don't clear _pending_server_tick here — any diff received from the new
	# server while frozen should apply on the first reconcile after unfreeze.

func _on_clock_synced() -> void:
	# Fires after every successful clock sync (initial connect and zone transfers).
	# Only unfreeze if there's a live player — on the very first sync the local
	# player hasn't been spawned yet and the frozen flag isn't set.
	if _local_player != null and _local_player.frozen:
		unfreeze_local_player()

func _on_zone_redirect(zone_id: String, address: String, port: int, token: String) -> void:
	print("[CLIENT] Zone redirect → %s at %s:%d" % [zone_id, address, port])
	_pending_transfer_token = token

	# Clear all remote players.
	for id in _remote_players.keys():
		_despawn_remote_player(id)

	# Swap to a fresh ZoneContainer for the new zone.
	_swap_zone_container(zone_id)

	# Reconnect — this triggers a fresh clock sync on the new server.
	# Player stays frozen until _on_clock_synced fires.
	_api.reconnect(address, port)

func _on_connected_to_server() -> void:
	if _pending_transfer_token != "":
		print("[CLIENT] Sending ZoneArrival (token=%s)" % _pending_transfer_token)
		_api.send_zone_arrival(_pending_transfer_token)
		_pending_transfer_token = ""
		# Do not unfreeze here — clock sync with the new server must complete
		# first. Unfreeze happens in _on_clock_synced via NetworkTime.after_sync.

func _on_world_diff(diff: Proto.WorldDiff) -> void:
	if _local_player != null and _local_player.frozen:
		return
	var local_id := multiplayer.get_unique_id()
	var tick := diff.get_tick()
	var seen_ids := {}

	for entity in diff.get_entities():
		var id := entity.get_entity_id()

		seen_ids[id] = true
		if id == local_id:
			if _local_player == null:
				_spawn_local_player()
			_local_player.on_entity_diff(entity, tick)
		elif not _remote_players.has(id):
			_spawn_remote_player(entity, tick)
		else:
			_remote_players[id].on_entity_diff(entity, tick)

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			_despawn_remote_player(id)

func _spawn_local_player() -> void:
	var node := LocalPlayerScene.instantiate() as Player
	node.name = "LocalPlayer"
	_local_player = node
	_zone_container.entities.add_child(node)
	_tick_interpolator.target = node
	_camera_pivot.target = node
	_local_player.input_source = %LocalInput
	_local_player.input_batcher = %InputBatcher
	_local_player.api = _api

func _spawn_remote_player(entity: Proto.EntityState, tick: int) -> void:
	var node := RemotePlayerScene.instantiate()
	node.name = "RemotePlayer_%d" % entity.get_entity_id()
	_zone_container.entities.add_child(node)
	_remote_players[entity.get_entity_id()] = node
	node.on_entity_diff(entity, tick)

func _despawn_remote_player(id: int) -> void:
	_remote_players[id].queue_free()
	_remote_players.erase(id)
