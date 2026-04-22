class_name AbilityUseSimpleGameEventData
extends RefCounted

var source_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0


static func create(
		p_source_entity_id: int,
		p_ability_id: int,
		p_request_id: int = 0) -> AbilityUseSimpleGameEventData:
	var data := AbilityUseSimpleGameEventData.new()
	data.source_entity_id = p_source_entity_id
	data.ability_id = p_ability_id
	data.request_id = p_request_id
	return data


static func from_entity_event(event: EntityEvents) -> AbilityUseSimpleGameEventData:
	return create(event.source_entity_id, event.ability_id, event.request_id)
