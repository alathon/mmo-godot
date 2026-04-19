class_name AbilityUseResult
extends RefCounted

const EntityEvents = preload("res://src/common/EntityEvents.gd")

var accepted: bool = false
var request_id: int = 0
var ability_id: StringName = &""
var requested_tick: int = 0
var start_tick: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0
var reject_reason: int = AbilityConstants.CANCEL_INVALID
var events: Array[EntityEvents] = []


static func accepted_result(
		ability_id: StringName,
		requested_tick: int,
		start_tick: int,
		events: Array[EntityEvents] = [],
		request_id: int = 0,
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
	return result


static func rejected_result(
		ability_id: StringName,
		requested_tick: int,
		reject_reason: int,
		events: Array[EntityEvents] = [],
		request_id: int = 0) -> AbilityUseResult:
	var result := AbilityUseResult.new()
	result.accepted = false
	result.request_id = request_id
	result.ability_id = ability_id
	result.requested_tick = requested_tick
	result.reject_reason = reject_reason
	result.events = events
	return result


static func from_validation(
		ability_id: StringName,
		requested_tick: int,
		validation: AbilityValidationResult) -> AbilityUseResult:
	if validation != null and validation.ok:
		return accepted_result(ability_id, requested_tick, 0)
	var reason := AbilityConstants.CANCEL_INVALID
	if validation != null:
		reason = validation.cancel_reason
	return rejected_result(ability_id, requested_tick, reason)
