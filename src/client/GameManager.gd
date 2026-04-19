class_name GameManager
extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const RemoteEntityScene = preload("res://src/client/RemoteEntity.tscn")
const LocalPlayerScene = preload("res://src/client/Player/Player.tscn")

const CORRECTION_THRESHOLD = 1.0
const TARGET_PICK_RADIUS_PX = 80.0
const TARGET_PICK_HEIGHT = 1.0

signal local_player_spawned(player: Player)
signal remote_player_spawned(player: RemoteEntity)
signal ability_use_accepted(ack)
signal ability_use_rejected(rejection)
signal ability_use_resolved(resolved)
signal entity_event_received(event)
signal ability_use_started(event)
signal ability_use_canceled(event)
signal ability_use_completed(event)
signal damage_taken(event)
signal healing_received(event)
signal buff_applied(event)
signal debuff_applied(event)
signal status_effect_removed(event)
signal combat_started(event)
signal combat_ended(event)
signal combatant_died(event)

@onready var _api: BackendAPI = %BackendAPI
@onready var _zone_container: ZoneContainer = $"../../ZoneContainer"
@onready var _clock_new: NetworkClockNew = $"/root/Root/Services/NetworkClock"
@onready var _camera: Camera3D = $"/root/Root/CameraPivot/SpringArm3D/Camera"
@onready var _target_indicator: TargetSelectionIndicator = %TargetSelectionIndicator

@export var BotMode: bool = false

var _pending_transfer_token: String = ""
var _awaiting_initial_clock_sync: bool = true
var _local_player: Player
var _remote_players: Dictionary[int, RemoteEntity]
var _debug: bool = false
var _ability_db: AbilityDatabase = AbilityDatabase.new()

func _ready() -> void:
	_ability_db.load_all()
	if "--bot" in OS.get_cmdline_user_args():
		BotMode = true
	Engine.physics_ticks_per_second = Globals.TICK_RATE

	_api.world_positions_received.connect(_on_world_positions)
	_api.world_state_received.connect(_on_world_state)
	_api.ability_use_accepted.connect(_on_ability_use_accepted)
	_api.ability_use_rejected.connect(_on_ability_use_rejected)
	_api.ability_use_resolved.connect(_on_ability_use_resolved)
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


func _on_ability_use_accepted(ack: Proto.AbilityUseAccepted) -> void:
	ability_use_accepted.emit(ack)
	if _local_player != null:
		_local_player.on_ability_accepted(ack)


func _on_ability_use_rejected(rejection: Proto.AbilityUseRejected) -> void:
	ability_use_rejected.emit(rejection)
	if _local_player != null:
		_local_player.on_ability_rejected(rejection)


func _on_ability_use_resolved(resolved: Proto.AbilityUseResolved) -> void:
	ability_use_resolved.emit(resolved)
	if _local_player != null:
		_local_player.on_ability_resolved(resolved)

func _on_player_spawn(pos: Vector3, rot_y: float) -> void:
	if BotMode == true:
		_local_player = (load("res://src/client/Player/BotPlayer.tscn")).instantiate() as Player
	else:
		_local_player = LocalPlayerScene.instantiate() as Player

	_zone_container.add_entity(_local_player)
	_local_player.setCharacterModel("Wizard")
	_local_player.name = "LocalPlayer"
	_local_player.id = multiplayer.get_unique_id()
	_local_player.is_local = true
	var body = _local_player.get_node("Body");
	body.position = pos
	body.rotation.y = rot_y
	local_player_spawned.emit(_local_player)

func get_local_player_id() -> int:
	return multiplayer.get_unique_id()


func get_entity_by_id(entity_id: int) -> Node:
	return _get_entity(entity_id)

func select_target_at_screen_position(screen_position: Vector2) -> void:
	var entity_id := _get_nearest_target_entity_id(screen_position)
	select_target_entity(entity_id)

func select_target_entity(entity_id: int) -> void:
	if _local_player == null:
		return
	if entity_id > 0:
		_local_player.set_target_entity_id(entity_id)
	else:
		_local_player.clear_target()
		_target_indicator.clear()

	var target_entity := _get_entity(entity_id) as Node3D
	if entity_id > 0 and target_entity == null:
		print("[CLIENT_TARGET] client=%d target=%d has no Node3D entity for indicator" % [
			get_local_player_id(), entity_id])
	_target_indicator.set_target(target_entity)
	_api.send_target_select(entity_id)
	print("[CLIENT_TARGET] client=%d selected target=%d" % [get_local_player_id(), entity_id])

func _on_world_state(diff: Proto.WorldState) -> void:
	for entity_state in diff.get_entities():
		var entity := _get_entity(entity_state.get_entity_id())
		if entity != null and entity.has_method("apply_world_state"):
			entity.apply_world_state(entity_state)
	_dispatch_world_state_events(diff)

# TODO: Move local player instantiation from variables somewhere more sensible.
# This method should just get a RemoteEntity ref, which it'll then
# e.g., add to _entities and trigger a spawn event etc.
func _spawn_remote_player(id: int, pos: Vector3, rot_y: float) -> void:
	var node: RemoteEntity = RemoteEntityScene.instantiate()
	_zone_container.add_entity(node)
	node.name = "RemotePlayer_%d" % id
	node.id = id
	node.is_local = false
	_remote_players[id] = node
	node.initialize_position(pos, rot_y)
	node.setCharacterModel("Wizard")  # TODO: Get model name from server
	remote_player_spawned.emit(node)

func _despawn_remote_player(id: int) -> void:
	print("Despawn remote player %d called" % id)
	_target_indicator.clear_if_target(_remote_players[id])
	_remote_players[id].queue_free()
	_remote_players.erase(id)

func _on_world_positions(diff: Proto.WorldPositions) -> void:
	var local_id := multiplayer.get_unique_id() # TODO: Are we sure it should be the unique ID from this node?? Feels iffy.
	var tick: int = diff.get_tick()
	_clock_new.on_world_positions_tick(tick)

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
			var vel := Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())
			if _debug and vel.length_squared() > 0.0001:
				print("[TRACE:GameManager] t=%s tick=%d remote_entity=%d position_received vel=(%.2f,%.2f,%.2f)" % [
					Globals.ts(), tick, id, vel.x, vel.y, vel.z])

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			print("Despawning remote player %d as they're no longer present in WorldPositions" % id)
			_despawn_remote_player(id)


func _get_entity(entity_id: int) -> Node:
	if _local_player != null and entity_id == _local_player.id:
		return _local_player
	return _remote_players.get(entity_id, null)


func _get_nearest_target_entity_id(screen_position: Vector2) -> int:
	if _camera == null:
		return 0

	var nearest_id := 0
	var nearest_distance_sq := TARGET_PICK_RADIUS_PX * TARGET_PICK_RADIUS_PX
	for entity_id in _remote_players.keys():
		var entity: RemoteEntity = _remote_players[entity_id]
		if entity == null or not is_instance_valid(entity):
			continue
		var target_position := entity.global_position + Vector3.UP * TARGET_PICK_HEIGHT
		if _camera.is_position_behind(target_position):
			continue
		var entity_screen_position := _camera.unproject_position(target_position)
		var distance_sq := screen_position.distance_squared_to(entity_screen_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_id = int(entity_id)
	return nearest_id


func _dispatch_world_state_events(diff: Proto.WorldState) -> void:
	for event in diff.get_events():
		_dispatch_entity_event(event)


func _dispatch_entity_event(event) -> void:
	entity_event_received.emit(event)
	if event.has_ability_use_started():
		var payload = event.get_ability_use_started()
		ability_use_started.emit(payload)
		_dispatch_ability_started_to_entity(payload, event.get_tick())
		_log_entity_event(event.get_tick(), "ability_started", payload.get_source_entity_id(), payload.get_ability_id())
	elif event.has_ability_use_canceled():
		var payload = event.get_ability_use_canceled()
		ability_use_canceled.emit(payload)
		_dispatch_ability_canceled_to_entity(payload, event.get_tick())
		_log_entity_event(event.get_tick(), "ability_canceled", payload.get_source_entity_id(), payload.get_ability_id())
	elif event.has_ability_use_completed():
		var payload = event.get_ability_use_completed()
		ability_use_completed.emit(payload)
		_dispatch_ability_completed_to_entity(payload, event.get_tick())
		_log_entity_event(event.get_tick(), "ability_completed", payload.get_source_entity_id(), payload.get_ability_id())
	elif event.has_damage_taken():
		var payload = event.get_damage_taken()
		damage_taken.emit(payload)
		_log_entity_event(event.get_tick(), "damage_taken", payload.get_target_entity_id(), payload.get_ability_id())
	elif event.has_healing_received():
		var payload = event.get_healing_received()
		healing_received.emit(payload)
		_log_entity_event(event.get_tick(), "healing_received", payload.get_target_entity_id(), payload.get_ability_id())
	elif event.has_buff_applied():
		var payload = event.get_buff_applied()
		buff_applied.emit(payload)
		_log_entity_event(event.get_tick(), "buff_applied", payload.get_target_entity_id(), payload.get_status_id())
	elif event.has_debuff_applied():
		var payload = event.get_debuff_applied()
		debuff_applied.emit(payload)
		_log_entity_event(event.get_tick(), "debuff_applied", payload.get_target_entity_id(), payload.get_status_id())
	elif event.has_status_effect_removed():
		var payload = event.get_status_effect_removed()
		status_effect_removed.emit(payload)
		_log_entity_event(event.get_tick(), "status_effect_removed", payload.get_entity_id(), payload.get_status_id())
	elif event.has_combat_started():
		var payload = event.get_combat_started()
		combat_started.emit(payload)
		_log_entity_event(event.get_tick(), "combat_started", payload.get_entity_id(), "")
	elif event.has_combat_ended():
		var payload = event.get_combat_ended()
		combat_ended.emit(payload)
		_log_entity_event(event.get_tick(), "combat_ended", payload.get_entity_id(), "")
	elif event.has_combatant_died():
		var payload = event.get_combatant_died()
		combatant_died.emit(payload)
		_log_entity_event(event.get_tick(), "combatant_died", payload.get_entity_id(), "")


func _log_entity_event(tick: int, event_name: String, entity_id: int, detail: Variant) -> void:
	# if not _debug:
	# 	return
	var resolved_detail := str(detail)
	if detail is int:
		var detail_id := int(detail)
		var ability_name := _ability_db.get_ability_name(detail_id)
		if ability_name != "":
			resolved_detail = "%d (%s)" % [detail_id, ability_name]
		elif event_name == "buff_applied" or event_name == "debuff_applied" or event_name == "status_effect_removed":
			var status_name := _ability_db.get_status_name(detail_id)
			if status_name != "":
				resolved_detail = "%d (%s)" % [detail_id, status_name]
	print("[CLIENT_EVENT] tick=%d event=%s entity=%d detail=%s" % [
		tick, event_name, entity_id, resolved_detail])


func _dispatch_ability_started_to_entity(payload, event_tick: int) -> void:
	var entity := _get_entity(payload.get_source_entity_id())
	if entity != null and entity.has_method("on_ability_started"):
		entity.on_ability_started(payload, event_tick)


func _dispatch_ability_completed_to_entity(payload, event_tick: int) -> void:
	var entity := _get_entity(payload.get_source_entity_id())
	if entity != null and entity.has_method("on_ability_completed"):
		entity.on_ability_completed(payload, event_tick)


func _dispatch_ability_canceled_to_entity(payload, event_tick: int) -> void:
	var entity := _get_entity(payload.get_source_entity_id())
	if entity != null and entity.has_method("on_ability_canceled"):
		entity.on_ability_canceled(payload, event_tick)
