class_name AbilityTransition
extends RefCounted

enum Type {
	CAST_STARTED,
	CAST_LOCKED,
	CAST_RESOLVE_DUE,
	CAST_FINISHED,
	CAST_IMPACT_DUE,
	CAST_CANCELED,
	QUEUED_REQUEST_READY,
}

var type: Type = Type.CAST_STARTED
var source_entity_id: int = 0
var request_id: int = 0
var ability_id: int = 0
var target: AbilityTargetSpec = null
var tick: int = 0
var requested_tick: int = 0
var cancel_reason: int = 0
var cast_time: float = 0.0
var start_tick: int = 0
var lock_tick: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0


static func cast_started(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int,
		cast_time: float,
		lock_tick: int,
		resolve_tick: int,
		finish_tick: int,
		impact_tick: int) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_STARTED
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	transition.requested_tick = tick
	transition.cast_time = cast_time
	transition.start_tick = tick
	transition.lock_tick = lock_tick
	transition.resolve_tick = resolve_tick
	transition.finish_tick = finish_tick
	transition.impact_tick = impact_tick
	return transition


static func cast_locked(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_LOCKED
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	return transition


static func cast_resolve_due(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int,
		start_tick: int = 0,
		lock_tick: int = 0,
		resolve_tick: int = 0,
		finish_tick: int = 0,
		impact_tick: int = 0) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_RESOLVE_DUE
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	transition.requested_tick = start_tick if start_tick > 0 else tick
	transition.start_tick = start_tick
	transition.lock_tick = lock_tick
	transition.resolve_tick = resolve_tick
	transition.finish_tick = finish_tick
	transition.impact_tick = impact_tick
	return transition


static func cast_finished(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int,
		start_tick: int = 0,
		lock_tick: int = 0,
		resolve_tick: int = 0,
		finish_tick: int = 0,
		impact_tick: int = 0) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_FINISHED
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	transition.requested_tick = start_tick if start_tick > 0 else tick
	transition.start_tick = start_tick
	transition.lock_tick = lock_tick
	transition.resolve_tick = resolve_tick
	transition.finish_tick = finish_tick
	transition.impact_tick = impact_tick
	return transition


static func cast_impact_due(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int,
		start_tick: int = 0,
		lock_tick: int = 0,
		resolve_tick: int = 0,
		finish_tick: int = 0,
		impact_tick: int = 0) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_IMPACT_DUE
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	transition.requested_tick = start_tick if start_tick > 0 else tick
	transition.start_tick = start_tick
	transition.lock_tick = lock_tick
	transition.resolve_tick = resolve_tick
	transition.finish_tick = finish_tick
	transition.impact_tick = impact_tick
	return transition


static func cast_canceled(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int,
		cancel_reason: int) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.CAST_CANCELED
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	transition.cancel_reason = cancel_reason
	return transition


static func queued_request_ready(
		source_entity_id: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		tick: int) -> AbilityTransition:
	var transition := AbilityTransition.new()
	transition.type = Type.QUEUED_REQUEST_READY
	transition.source_entity_id = source_entity_id
	transition.request_id = request_id
	transition.ability_id = ability_id
	transition.target = target
	transition.tick = tick
	return transition
