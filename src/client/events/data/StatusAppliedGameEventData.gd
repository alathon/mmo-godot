class_name StatusAppliedGameEventData
extends RefCounted

var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var status_id: int = 0
var remaining_duration: float = 0.0


static func create(
		p_source_entity_id: int,
		p_target_entity_id: int,
		p_ability_id: int,
		p_status_id: int,
		p_remaining_duration: float = 0.0) -> StatusAppliedGameEventData:
	var data := StatusAppliedGameEventData.new()
	data.source_entity_id = p_source_entity_id
	data.target_entity_id = p_target_entity_id
	data.ability_id = p_ability_id
	data.status_id = p_status_id
	data.remaining_duration = p_remaining_duration
	return data


static func from_entity_event(event: EntityEvents) -> StatusAppliedGameEventData:
	return create(
			event.source_entity_id,
			event.target_entity_id,
			event.ability_id,
			event.status_id,
			event.amount)
