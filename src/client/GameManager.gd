class_name GameManager
extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const PlayerScene = preload("res://src/client/entities/Player.tscn")
const BotInputScript = preload("res://src/client/input/BotInput.gd")

signal local_player_spawned(player: Player)
signal remote_player_spawned(player: RemoteEntity)

@onready var _api: BackendAPI = %BackendAPI
@onready var _zone_container: ZoneContainer = $"../../ZoneContainer"
@onready var _clock_new: NetworkClock = $"/root/Root/Services/NetworkClock"
@onready var _local_input: LocalInput = %LocalInput
@onready var _input_batcher: InputBatcher = %InputBatcher
@onready var _world_input_service: WorldInputService = %WorldInputService
@onready var _ground_targeting_mode: GroundTargetingMode = %GroundTargetingMode
@onready var _event_gateway: EventGateway = %EventGateway

@export var BotMode: bool = false

var _pending_transfer_token: String = ""
var _awaiting_initial_clock_sync: bool = true
var _local_player: Player
var _remote_players: Dictionary[int, RemoteEntity]
var _debug: bool = false

func _ready() -> void:
	if "--bot" in OS.get_cmdline_user_args():
		BotMode = true
	Engine.physics_ticks_per_second = Globals.TICK_RATE
	if BotMode:
		_replace_local_input_with_bot_input()

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
	NetworkTime.on_tick.connect(_on_network_tick)
	_event_gateway.event_emitted.connect(_on_game_event_emitted)

func _on_network_tick(delta: float, current_tick: int):
	if _local_player == null:
		return

	# Gather input
	var input = _local_input.getInput()

	# Apply movement input
	_local_player.body.simulate(input, delta)

	# TODO: Is the below really necessary?
	for entity in get_all_entities():
		var entity_state = entity.get_node("%EntityState")
		# TODO: Why is it called tick_runtime() and not tick()?
		entity_state.tick_runtime(delta)

	_local_player.local_ability_controller.set_input(int(input.get("ability_id", 0)))
	_local_player.local_ability_controller.tick(current_tick)
	var ability_attempt := _local_player.local_ability_controller.consume_pending_server_request()

	# Client-side post-tick stuff.
	_local_player.csp.setInputAt(current_tick, input)
	_local_player.csp.setPredictionAt(current_tick, { "global_position" = _local_player.body.global_position })

	# Batch input for server send.
	_input_batcher.queue_input(
			input["input_x"],
			input["input_z"],
			input["jump_pressed"],
			_local_player.body.rotation.y,
			current_tick,
			ability_attempt.ability_id if ability_attempt != null and ability_attempt.accepted and ability_attempt.should_send_to_server else 0,
			ability_attempt.get_target_entity_id() if ability_attempt != null and ability_attempt.accepted and ability_attempt.should_send_to_server else 0,
			ability_attempt.get_ground_position() if ability_attempt != null and ability_attempt.accepted and ability_attempt.should_send_to_server else Vector3.ZERO,
			ability_attempt.request_id if ability_attempt != null and ability_attempt.accepted and ability_attempt.should_send_to_server else 0)

func _on_clock_synced() -> void:
	# If this is the first 'fresh' clock sync, unfreeze player
	if _awaiting_initial_clock_sync and _local_player:
		_local_player.set_frozen(false)
		_awaiting_initial_clock_sync = false

func _on_zone_border_entered(node: Variant):
	var player := node.get_parent() as Player if node is PhysicsBody else null
	if player:
		player.set_frozen(true)

func _on_zone_redirect(zone_id: String, address: String, port: int, token: String) -> void:
	print("[CLIENT] Zone redirect → %s at %s:%d" % [zone_id, address, port])
	_pending_transfer_token = token
	_awaiting_initial_clock_sync = true

	_remote_players.clear()
	_local_player = null
	if _ground_targeting_mode != null:
		_ground_targeting_mode.deactivate()

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
	if _local_player == null:
		return
	_local_player.local_ability_controller.on_started_ack(
			int(ack.get_request_id()),
			int(ack.get_start_tick()),
			int(ack.get_resolve_tick()),
			int(ack.get_finish_tick()),
			int(ack.get_impact_tick()))

func _on_ability_use_rejected(rejection: Proto.AbilityUseRejected) -> void:
	if _local_player == null:
		return
	_local_player.local_ability_controller.on_request_rejected(
			int(rejection.get_request_id()),
			rejection.get_cancel_reason(),
			NetworkTime.tick)


func _on_ability_use_resolved(resolved: Proto.AbilityUseResolved) -> void:
	_event_gateway.submit_server_game_event(GameEvent.create(
			int(resolved.get_resolve_tick()),
			GameEvent.Type.ABILITY_USE_RESOLVED,
			AbilityUseResolvedGameEventData.from_proto(resolved)))

func _on_player_spawn(pos: Vector3, rot_y: float) -> void:
	_local_player = PlayerScene.instantiate() as Player

	_zone_container.add_entity(_local_player)
	_local_player.set_character_model("Wizard")
	_local_player.name = "LocalPlayer"
	_local_player.id = multiplayer.get_unique_id()
	_local_player.ability_manager.set_target_resolver(self)
	var body = _local_player.get_node("%Body");
	body.position = pos
	body.rotation.y = rot_y
	local_player_spawned.emit(_local_player)


func _replace_local_input_with_bot_input() -> void:
	if _local_input is BotInput:
		return

	# Preserve the existing service node so unique-name lookups like %LocalInput
	# remain valid while swapping the runtime behavior to the bot controller.
	_local_input.set_script(BotInputScript)
	if _ground_targeting_mode != null:
		_ground_targeting_mode.set_input_source(_local_input)

func get_local_player_id() -> int:
	return multiplayer.get_unique_id()


func get_entity_by_id(entity_id: int):
	return _get_entity(entity_id)


func get_all_entities() -> Array[Node]:
	var entities: Array[Node] = []
	if _local_player != null:
		entities.append(_local_player)
	for entity_id in _remote_players:
		var entity := _remote_players[entity_id]
		if entity != null:
			entities.append(entity)
	return entities


func get_entity_names(entity_ids: Array) -> Dictionary:
	var names := {}
	for entity_id in entity_ids:
		var resolved_id := int(entity_id)
		if resolved_id <= 0:
			continue
		var entity = _get_entity(resolved_id)
		if entity != null and is_instance_valid(entity) and not entity.name.is_empty():
			names[resolved_id] = entity.name
		else:
			names[resolved_id] = str(resolved_id)
	return names

func _on_world_state(diff: Proto.WorldState) -> void:
	for entity_state in diff.get_entities():
		var entity = _get_entity(entity_state.get_entity_id())
		if entity != null and entity.has_method("apply_world_state"):
			entity.apply_world_state(entity_state)
	_dispatch_world_state_events(diff)

# TODO: Move local player instantiation from variables somewhere more sensible.
# This method should just get a RemoteEntity ref, which it'll then
# e.g., add to _entities and trigger a spawn event etc.
func _spawn_remote_player(id: int, pos: Vector3, rot_y: float) -> void:
	var node: RemoteEntity = (load("res://src/client/entities/RemoteEntity.tscn") as PackedScene).instantiate()
	_zone_container.add_entity(node)
	node.name = "RemotePlayer_%d" % id
	node.id = id
	_remote_players[id] = node
	node.initialize_position(pos, rot_y)
	node.set_character_model("Wizard")  # TODO: Get model name from server
	remote_player_spawned.emit(node)

func _despawn_remote_player(id: int) -> void:
	print("Despawn remote player %d called" % id)
	var target = _remote_players.get(id, null)
	if _local_player != null and target != null and _local_player.entity_state.current_target == target:
		_local_player.entity_state.clear_target()
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
		var vel := Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())
		var rot_y := entity.get_rot_y()
		var is_on_floor := entity.get_is_on_floor()
		seen_ids[id] = true
		if id == local_id:
			if _local_player != null:
				_local_player.on_server_position(pos, vel, rot_y, tick)
		elif not _remote_players.has(id):
			_spawn_remote_player(id, pos, rot_y)
		else:
			_remote_players[id].on_server_position(pos, vel, rot_y, is_on_floor, tick)

			if _debug and vel.length_squared() > 0.0001:
				print("[TRACE:GameManager] t=%s tick=%d remote_entity=%d position_received vel=(%.2f,%.2f,%.2f)" % [
					Globals.ts(), tick, id, vel.x, vel.y, vel.z])

	for id in _remote_players.keys():
		if not seen_ids.has(id):
			print("Despawning remote player %d as they're no longer present in WorldPositions" % id)
			_despawn_remote_player(id)


func _get_entity(entity_id: int):
	if _local_player != null and entity_id == _local_player.id:
		return _local_player
	return _remote_players.get(entity_id, null)


func _dispatch_world_state_events(diff: Proto.WorldState) -> void:
	for event in diff.get_events():
		_dispatch_entity_event(event)


func _dispatch_entity_event(event) -> void:
	_event_gateway.submit_server_proto_event(event)


func _log_entity_event(tick: int, event_name: String, entity_id: int, detail: Variant) -> void:
	# if not _debug:
	# 	return
	var resolved_detail := str(detail)
	if detail is int:
		var detail_id := int(detail)
		var ability_name := AbilityDB.get_ability_name(detail_id)
		if ability_name != "":
			resolved_detail = "%d (%s)" % [detail_id, ability_name]
		elif event_name == "buff_applied" or event_name == "debuff_applied" or event_name == "status_effect_removed":
			var status_name := AbilityDB.get_status_name(detail_id)
			if status_name != "":
				resolved_detail = "%d (%s)" % [detail_id, status_name]
	print("%s %s [WORLD_EVENT_RX] event=%s entity=%d detail=%s" % [
		_format_tick_prefix(tick), _get_log_prefix(), event_name, entity_id, resolved_detail])


func _on_game_event_emitted(event: GameEvent) -> void:
	if event == null:
		return

	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			var data = event.data as AbilityUseStartedGameEventData
			_log_entity_event(event.tick, "ability_use_started", data.source_entity_id, data.ability_id)
			_apply_entity_game_event(data.source_entity_id, event)
		GameEvent.Type.ABILITY_USE_CANCELED:
			var data = event.data as AbilityUseCanceledGameEventData
			_log_entity_event(event.tick, "ability_use_canceled", data.source_entity_id, data.ability_id)
			if _local_player != null:
				_local_player.local_ability_controller.on_cast_canceled(data.request_id, data.cancel_reason, event.tick)
			_event_gateway.clear_request_tracking(data.request_id)
			_apply_entity_game_event(data.source_entity_id, event)
		GameEvent.Type.ABILITY_USE_FINISHED:
			var data = event.data as AbilityUseSimpleGameEventData
			_log_entity_event(event.tick, "ability_use_finished", data.source_entity_id, data.ability_id)
			_apply_entity_game_event(data.source_entity_id, event)
		GameEvent.Type.ABILITY_USE_IMPACT:
			var data = event.data as AbilityUseSimpleGameEventData
			_log_entity_event(event.tick, "ability_use_impact", data.source_entity_id, data.ability_id)
			if _local_player != null:
				_local_player.local_ability_controller.clear_request_tracking(data.request_id)
			_apply_entity_game_event(data.source_entity_id, event)
		GameEvent.Type.ABILITY_USE_RESOLVED:
			var data = event.data as AbilityUseResolvedGameEventData
			if _local_player != null:
				_local_player.on_game_event(event)
		GameEvent.Type.DAMAGE_TAKEN:
			var data = event.data as DamageTakenGameEventData
			if not _should_suppress_world_event_log("damage_taken", data.source_entity_id):
				_log_entity_event(event.tick, "damage_taken", data.target_entity_id, data.ability_id)
		GameEvent.Type.HEALING_RECEIVED:
			var data = event.data as HealingReceivedGameEventData
			if not _should_suppress_world_event_log("healing_received", data.source_entity_id):
				_log_entity_event(event.tick, "healing_received", data.target_entity_id, data.ability_id)
		GameEvent.Type.BUFF_APPLIED:
			var data = event.data as StatusAppliedGameEventData
			if not _should_suppress_world_event_log("buff_applied", data.source_entity_id):
				_log_entity_event(event.tick, "buff_applied", data.target_entity_id, data.status_id)
			_apply_entity_game_event(data.target_entity_id, event)
		GameEvent.Type.DEBUFF_APPLIED:
			var data = event.data as StatusAppliedGameEventData
			if not _should_suppress_world_event_log("debuff_applied", data.source_entity_id):
				_log_entity_event(event.tick, "debuff_applied", data.target_entity_id, data.status_id)
			_apply_entity_game_event(data.target_entity_id, event)
		GameEvent.Type.STATUS_EFFECT_REMOVED:
			var data = event.data as StatusEffectRemovedGameEventData
			_log_entity_event(event.tick, "status_effect_removed", data.entity_id, data.status_id)
			_apply_entity_game_event(data.entity_id, event)
		GameEvent.Type.COMBAT_STARTED:
			var data = event.data as CombatEventGameEventData
			_log_entity_event(event.tick, "combat_started", data.entity_id, "")
			_apply_entity_game_event(data.entity_id, event)
		GameEvent.Type.COMBAT_ENDED:
			var data = event.data as CombatEventGameEventData
			_log_entity_event(event.tick, "combat_ended", data.entity_id, "")
			_apply_entity_game_event(data.entity_id, event)
		GameEvent.Type.COMBATANT_DIED:
			var data = event.data as CombatEventGameEventData
			_log_entity_event(event.tick, "combatant_died", data.entity_id, "")
		_:
			return


func _apply_entity_game_event(entity_id: int, event: GameEvent) -> void:
	var entity = _get_entity(entity_id)
	if entity == null:
		return
	if entity.has_method("on_game_event"):
		entity.on_game_event(event)


func _should_suppress_world_event_log(event_name: String, source_entity_id: int) -> bool:
	if _local_player == null:
		return false
	match event_name:
		"damage_taken", "healing_received", "buff_applied", "debuff_applied":
			return source_entity_id == _local_player.id
	return false


func _get_log_prefix() -> String:
	return "[PLAYER %d]" % get_local_player_id()


func _format_tick_prefix(tick: int) -> String:
	return "[TICK %d | (%s)]" % [tick, _timestamp()]


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
