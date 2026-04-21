class_name AbilitySystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _zone: ServerZone = get_owner()
@onready var _combat_system: CombatSystem = %CombatSystem

var _pending_events: Array[EntityEvents] = []
var _ack_queue: Array = []


func init(zone: Node, combat_system: CombatSystem) -> void:
	_zone = zone
	_combat_system = combat_system


func tick(sim_tick: int, ctx: Dictionary) -> void:
	var context := _make_execution_context(sim_tick)
	ctx["ability_execution_context"] = context
	_tick_entity_runtime(context.delta)
	_process_movement_cancels(ctx.get("moving_entities", {}), sim_tick, context)
	_process_ability_inputs(ctx.get("ability_inputs", {}), sim_tick, context)
	_tick_ability_managers(sim_tick, context)
	_flush_ack_queue()


func handle_ability_input(entity_id: int, input: Dictionary, sim_tick: int, context: AbilityExecutionContext) -> void:
	var manager := get_ability_manager(entity_id)
	if manager == null:
		return
	manager.set_target_resolver(_zone)

	var ability_id := int(input.get("ability_id", 0))
	if ability_id <= 0:
		return

	var target := _target_spec_from_input(input)
	var request_id := int(input.get("ability_request_id", 0))
	var decision := manager.evaluate_activation(request_id, ability_id, target, sim_tick)

	match decision.outcome:
		AbilityDecision.Outcome.REJECTED:
			_enqueue_rejection(entity_id, request_id, decision.reject_reason)
		AbilityDecision.Outcome.QUEUED:
			manager.queue_request(request_id, ability_id, target, decision.earliest_activate_tick)
			_enqueue_accepted(entity_id, request_id, ability_id, _build_timing_preview(ability_id, decision.earliest_activate_tick))
		AbilityDecision.Outcome.STARTED:
			_process_transitions(manager, manager.start_cast(request_id, ability_id, target, sim_tick), context)


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
	return source_entity.ability_manager as AbilityManager


func _tick_entity_runtime(delta: float) -> void:
	if _zone == null:
		return
	for entity_id in _zone.players:
		var entity := _zone.players[entity_id]
		entity.entity_state.tick_runtime(delta)


func _process_movement_cancels(
		moving_entities: Dictionary,
		sim_tick: int,
		context: AbilityExecutionContext) -> void:
	for entity_id in moving_entities:
		var manager := get_ability_manager(entity_id)
		if manager != null and manager.can_movement_cancel_current_cast():
			_process_transitions(manager, manager.cancel_current_cast(AbilityConstants.CANCEL_MOVED, sim_tick), context)


func _process_ability_inputs(
		ability_inputs: Dictionary,
		sim_tick: int,
		context: AbilityExecutionContext) -> void:
	for entity_id in ability_inputs:
		handle_ability_input(entity_id, ability_inputs[entity_id], sim_tick, context)


func _tick_ability_managers(sim_tick: int, context: AbilityExecutionContext) -> void:
	if _zone == null:
		return
	for entity_id in _zone.players:
		if _zone._frozen_peers.has(entity_id):
			continue
		var manager := get_ability_manager(entity_id)
		if manager == null:
			continue
		manager.set_target_resolver(_zone)
		_process_transitions(manager, manager.tick(sim_tick), context)


func _process_transitions(manager: AbilityManager, transitions: Array, context: AbilityExecutionContext) -> void:
	if manager == null:
		return
	for transition_value in transitions:
		var transition := transition_value as AbilityTransition
		if transition == null:
			continue
		match transition.type:
			AbilityTransition.Type.CAST_STARTED:
				_append_events([_to_started_event(transition)])
				_enqueue_accepted(
						transition.source_entity_id,
						transition.request_id,
						transition.ability_id,
						{
							"start_tick": transition.start_tick,
							"resolve_tick": transition.resolve_tick,
							"finish_tick": transition.finish_tick,
							"impact_tick": transition.impact_tick,
						})
			AbilityTransition.Type.CAST_LOCKED:
				_append_events(_combat_system.on_cast_locked(transition, context))
			AbilityTransition.Type.CAST_RESOLVE_DUE:
				_append_events(_combat_system.on_cast_resolve_due(transition, context))
			AbilityTransition.Type.CAST_FINISHED:
				manager.commit_cast_costs(transition.request_id)
				_append_events([EntityEvents.ability_finished(
						transition.source_entity_id,
						transition.ability_id,
						transition.request_id)])
			AbilityTransition.Type.CAST_IMPACT_DUE:
				_append_events(_combat_system.on_cast_impact_due(transition, context))
			AbilityTransition.Type.CAST_CANCELED:
				_append_events([EntityEvents.ability_canceled(
						transition.source_entity_id,
						transition.ability_id,
						transition.cancel_reason,
						transition.request_id)])
			AbilityTransition.Type.QUEUED_REQUEST_READY:
				_process_queued_ready(manager, transition, context)


func _process_queued_ready(
		manager: AbilityManager,
		transition: AbilityTransition,
		context: AbilityExecutionContext) -> void:
	if manager == null or transition == null:
		return

	var decision := manager.evaluate_activation(
			transition.request_id,
			transition.ability_id,
			transition.target,
			transition.tick)

	match decision.outcome:
		AbilityDecision.Outcome.STARTED:
			_process_transitions(
					manager,
					manager.start_cast(
							transition.request_id,
							transition.ability_id,
							transition.target,
							transition.tick),
					context)
		AbilityDecision.Outcome.QUEUED:
			manager.queue_request(
					transition.request_id,
					transition.ability_id,
					transition.target,
					decision.earliest_activate_tick)
		_:
			manager.clear_queued_request(transition.request_id)


func _flush_ack_queue() -> void:
	for ack in _ack_queue:
		var entity_id := int(ack.get("entity_id", 0))
		var ack_type := String(ack.get("type", ""))
		if entity_id <= 0 or ack_type == "":
			continue

		var packet := Proto.Packet.new()
		if ack_type == "accepted":
			var accepted = packet.new_ability_accepted()
			accepted.set_ability_id(int(ack.get("ability_id", 0)))
			accepted.set_request_id(int(ack.get("request_id", 0)))
			accepted.set_start_tick(int(ack.get("start_tick", 0)))
			accepted.set_resolve_tick(int(ack.get("resolve_tick", 0)))
			accepted.set_finish_tick(int(ack.get("finish_tick", 0)))
			accepted.set_impact_tick(int(ack.get("impact_tick", 0)))
		elif ack_type == "rejected":
			var rejected = packet.new_ability_rejected()
			rejected.set_cancel_reason(int(ack.get("cancel_reason", AbilityConstants.CANCEL_INVALID)))
			rejected.set_request_id(int(ack.get("request_id", 0)))
		else:
			continue

		multiplayer.send_bytes(packet.to_bytes(), entity_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)
	_ack_queue.clear()


func _make_execution_context(sim_tick: int, source_entity_id: int = 0) -> AbilityExecutionContext:
	var context := AbilityExecutionContext.new()
	context.sim_tick = sim_tick
	context.source_entity_id = source_entity_id
	context.delta = 1.0 / float(Globals.TICK_RATE)
	context.combat_system = _combat_system
	context.target_resolver = _zone
	return context


func _enqueue_accepted(entity_id: int, request_id: int, ability_id: int, timing: Dictionary) -> void:
	_ack_queue.append({
		"type": "accepted",
		"entity_id": entity_id,
		"request_id": request_id,
		"ability_id": ability_id,
		"start_tick": int(timing.get("start_tick", 0)),
		"resolve_tick": int(timing.get("resolve_tick", 0)),
		"finish_tick": int(timing.get("finish_tick", 0)),
		"impact_tick": int(timing.get("impact_tick", 0)),
	})


func _enqueue_rejection(entity_id: int, request_id: int, cancel_reason: int) -> void:
	_ack_queue.append({
		"type": "rejected",
		"entity_id": entity_id,
		"request_id": request_id,
		"cancel_reason": cancel_reason,
	})


func _append_events(events: Array[EntityEvents]) -> void:
	_pending_events.append_array(events)


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

	return null


func _build_timing_preview(ability_id: int, start_tick: int) -> Dictionary:
	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		return {
			"start_tick": start_tick,
			"resolve_tick": 0,
			"finish_tick": 0,
			"impact_tick": 0,
		}

	var cast_ticks := int(ceil(maxf(0.0, ability.cast_time) * float(Globals.TICK_RATE)))
	var finish_tick := start_tick + cast_ticks
	return {
		"start_tick": start_tick,
		"resolve_tick": start_tick + maxi(0, cast_ticks - ability.resolve_lead_ticks),
		"finish_tick": finish_tick,
		"impact_tick": finish_tick + int(ceil(AbilityConstants.IMPACT_DELAY_DURATION * float(Globals.TICK_RATE))),
	}


func _to_started_event(transition: AbilityTransition) -> EntityEvents:
	var target_entity_id := 0
	var ground_position := Vector3.ZERO
	if transition.target != null:
		if transition.target.kind == AbilityTargetSpec.Kind.ENTITY:
			target_entity_id = transition.target.entity_id
		elif transition.target.kind == AbilityTargetSpec.Kind.GROUND:
			ground_position = transition.target.ground_position

	return EntityEvents.ability_started(
			transition.source_entity_id,
			transition.ability_id,
			transition.request_id,
			target_entity_id,
			ground_position,
			transition.cast_time)
