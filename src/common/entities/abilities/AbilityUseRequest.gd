class_name AbilityUseRequest
extends RefCounted

var source_entity_id: int = 0
var ability_id: StringName = &""
var target: AbilityTargetSpec = null
var requested_tick: int = 0


static func create(
		source_entity_id: int,
		ability_id: StringName,
		target: AbilityTargetSpec,
		requested_tick: int) -> AbilityUseRequest:
	var request := AbilityUseRequest.new()
	request.source_entity_id = source_entity_id
	request.ability_id = ability_id
	request.target = target
	request.requested_tick = requested_tick
	return request
