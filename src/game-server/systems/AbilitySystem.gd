class_name AbilitySystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _zone: ServerZone = get_owner()
@onready var _combat_system: CombatSystem = %CombatSystem
var _targeting: RefCounted = null
var _ability_db: AbilityDatabase = AbilityDatabase.new()
var _pending_events: Array[EntityEvents] = []
var _ack_queue: Array = []


func init(zone: Node, combat_system: CombatSystem) -> void:
	_zone = zone
	_combat_system = combat_system
	_targeting = AbilityTargeting.new()
	_targeting.init(_zone, _combat_system)
	_ability_db.load_all()


func tick(sim_tick: int, ctx: Dictionary) -> void:
	var context := _make_execution_context(sim_tick)
	ctx["ability_execution_context"] = context
	if not ctx.has("completed_ability_uses"):
		ctx["completed_ability_uses"] = []
	_process_movement_cancels(ctx.get("moving_entities", {}), sim_tick, context)
	_process_ability_inputs(ctx.get("ability_inputs", {}), sim_tick)
	_tick_ability_managers(sim_tick, context, ctx)
	_flush_ack_queue()


func handle_ability_input(entity_id: int, input: Dictionary, sim_tick: int) -> void:
	var manager := get_ability_manager(entity_id)
	if manager == null:
		return

	var ability_id := StringName(input.get("ability_id", ""))
	if ability_id == &"":
		return

	var target := _target_spec_from_input(input)
	var result := manager.use_ability(
			ability_id,
			target,
			sim_tick,
			_make_execution_context(sim_tick, entity_id))
	_enqueue_ack(entity_id, result)
	_append_events(result.events)


func has_events() -> bool:
	return _pending_events.size() > 0 or _ack_queue.size() > 0


func has_entity_events() -> bool:
	return _pending_events.size() > 0


func build_entity_events_proto(world_state_msg, sim_tick: int) -> void:
	EntityEventCodec.write_events(world_state_msg, _pending_events, sim_tick)
	_pending_events.clear()


func get_entity(entity_id: int) -> Node:
	if _zone == null:
		return null
	return _zone.players.get(entity_id, null)


func get_ability_manager(entity_id: int) -> AbilityManager:
	var source_entity := get_entity(entity_id)
	if source_entity == null:
		return null
	if source_entity is ServerPlayer:
		return (source_entity as ServerPlayer).ability_manager
	return null


func resolve_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	if _targeting == null:
		return []
	return _targeting.resolve_targets(source_entity, ability, target)


func is_in_range(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	if _targeting == null:
		return false
	return _targeting.is_in_range(source_entity, ability, target)


func _process_movement_cancels(
		moving_entities: Dictionary,
		_sim_tick: int,
		context: AbilityExecutionContext) -> void:
	for entity_id in moving_entities:
		var manager := get_ability_manager(entity_id)
		if manager != null and manager.is_casting():
			_append_events(manager.cancel_casting(AbilityConstants.CANCEL_MOVED, context))


func _process_ability_inputs(ability_inputs: Dictionary, sim_tick: int) -> void:
	for entity_id in ability_inputs:
		handle_ability_input(entity_id, ability_inputs[entity_id], sim_tick)


func _tick_ability_managers(
		sim_tick: int,
		context: AbilityExecutionContext,
		ctx: Dictionary) -> void:
	if _zone == null:
		return
	for entity_id in _zone.players:
		if _zone._frozen_peers.has(entity_id):
			continue
		var manager := get_ability_manager(entity_id)
		if manager == null:
			continue
		_append_events(manager.tick(context.delta, sim_tick, context))
		var completed_uses := manager.consume_completed_uses()
		_append_completed_uses(ctx, completed_uses)


func _flush_ack_queue() -> void:
	for ack in _ack_queue:
		var entity_id := int(ack.get("entity_id", 0))
		var result := ack.get("result", null) as AbilityUseResult
		if entity_id <= 0 or result == null:
			continue
		var packet := Proto.Packet.new()
		if result.accepted:
			var accepted = packet.new_ability_accepted()
			accepted.set_ability_id(String(result.ability_id))
			accepted.set_requested_tick(result.requested_tick)
			accepted.set_start_tick(result.start_tick)
		else:
			var rejected = packet.new_ability_rejected()
			rejected.set_ability_id(String(result.ability_id))
			rejected.set_requested_tick(result.requested_tick)
			rejected.set_cancel_reason(result.reject_reason)
		multiplayer.send_bytes(packet.to_bytes(), entity_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)
	_ack_queue.clear()


func _make_execution_context(sim_tick: int, source_entity_id: int = 0) -> AbilityExecutionContext:
	var context := AbilityExecutionContext.new()
	context.sim_tick = sim_tick
	context.source_entity_id = source_entity_id
	context.delta = 1.0 / float(Globals.TICK_RATE)
	context.ability_system = self
	context.combat_system = _combat_system
	context.ability_db = _ability_db
	return context


func _enqueue_ack(entity_id: int, result: AbilityUseResult) -> void:
	if result != null:
		_ack_queue.append({
			"entity_id": entity_id,
			"result": result,
		})


func _append_events(events: Array[EntityEvents]) -> void:
	_pending_events.append_array(events)


func _append_completed_uses(ctx: Dictionary, completed_uses: Array[CompletedAbilityUse]) -> void:
	if completed_uses.is_empty():
		return
	if not ctx.has("completed_ability_uses"):
		ctx["completed_ability_uses"] = []
	ctx["completed_ability_uses"].append_array(completed_uses)


func _target_spec_from_input(input: Dictionary) -> AbilityTargetSpec:
	var target_entity_id := int(input.get("target_entity_id", 0))
	if target_entity_id > 0:
		return AbilityTargetSpec.entity(target_entity_id)

	var ground_position := Vector3(
			float(input.get("ground_x", 0.0)),
			float(input.get("ground_y", 0.0)),
			float(input.get("ground_z", 0.0)))
	if ground_position != Vector3.ZERO:
		return AbilityTargetSpec.ground(ground_position)

	return AbilityTargetSpec.current_target()
