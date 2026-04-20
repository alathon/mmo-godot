class_name AbilityUseResult
extends RefCounted

const EntityEvents = preload("res://src/common/EntityEvents.gd")

var accepted: bool = false
var request_id: int = 0
var ability_id: int = 0
var requested_tick: int = 0
var start_tick: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0
var reject_reason: int = AbilityConstants.CANCEL_INVALID
var events: Array[EntityEvents] = []
var target_spec: AbilityTargetSpec = null


static func accepted_result(
		ability_id: int,
		requested_tick: int,
		start_tick: int,
		events: Array[EntityEvents] = [],
		request_id: int = 0,
		target: AbilityTargetSpec = null,
		resolve_tick: int = 0,
		finish_tick: int = 0,
		impact_tick: int = 0) -> AbilityUseResult:
	var result := AbilityUseResult.new()
	result.accepted = true
	result.request_id = request_id
	result.ability_id = ability_id
	result.requested_tick = requested_tick
	result.start_tick = start_tick
	result.resolve_tick = resolve_tick
	result.finish_tick = finish_tick
	result.impact_tick = impact_tick
	result.events = events
	result.target_spec = target
	return result


static func rejected_result(
		ability_id: int,
		requested_tick: int,
		reject_reason: int,
		events: Array[EntityEvents] = [],
		request_id: int = 0,
		target: AbilityTargetSpec = null) -> AbilityUseResult:
	var result := AbilityUseResult.new()
	result.accepted = false
	result.request_id = request_id
	result.ability_id = ability_id
	result.requested_tick = requested_tick
	result.reject_reason = reject_reason
	result.events = events
	result.target_spec = target
	return result


static func from_validation(
		ability_id: int,
		requested_tick: int,
		validation: AbilityValidationResult,
		target: AbilityTargetSpec = null) -> AbilityUseResult:
	if validation != null and validation.ok:
		return accepted_result(ability_id, requested_tick, 0, [], 0, target)
	var reason := AbilityConstants.CANCEL_INVALID
	if validation != null:
		reason = validation.cancel_reason
	return rejected_result(ability_id, requested_tick, reason, [], 0, target)


func get_target_entity_id() -> int:
	if target_spec == null:
		return 0
	var entity_id := target_spec.get_entity_id()
	return entity_id if entity_id != null else 0


func get_ground_position() -> Vector3:
	if target_spec == null:
		return Vector3.ZERO
	var ground_position := target_spec.get_ground_position()
	return ground_position if ground_position != null else Vector3.ZERO
