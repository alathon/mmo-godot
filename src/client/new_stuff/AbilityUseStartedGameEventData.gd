class_name AbilityUseStartedGameEventData
extends RefCounted

var source_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var target_entity_id: int = 0
var ground_position: Vector3 = Vector3.ZERO
var cast_time: float = 0.0


static func create(
		p_source_entity_id: int,
		p_ability_id: int,
		p_request_id: int = 0,
		p_target_entity_id: int = 0,
		p_ground_position: Vector3 = Vector3.ZERO,
		p_cast_time: float = 0.0) -> AbilityUseStartedGameEventData:
	var data := AbilityUseStartedGameEventData.new()
	data.source_entity_id = p_source_entity_id
	data.ability_id = p_ability_id
	data.request_id = p_request_id
	data.target_entity_id = p_target_entity_id
	data.ground_position = p_ground_position
	data.cast_time = p_cast_time
	return data


static func from_entity_event(event: EntityEvents) -> AbilityUseStartedGameEventData:
	return create(
			event.source_entity_id,
			event.ability_id,
			event.request_id,
			event.target_entity_id,
			event.ground_position,
			event.cast_time)
