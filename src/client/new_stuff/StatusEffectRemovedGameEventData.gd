class_name StatusEffectRemovedGameEventData
extends RefCounted

var source_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var entity_id: int = 0
var status_id: int = 0
var remove_reason: int = 0


static func create(
		p_entity_id: int,
		p_status_id: int,
		p_remove_reason: int) -> StatusEffectRemovedGameEventData:
	var data := StatusEffectRemovedGameEventData.new()
	data.entity_id = p_entity_id
	data.status_id = p_status_id
	data.remove_reason = p_remove_reason
	return data


static func from_entity_event(event: EntityEvents) -> StatusEffectRemovedGameEventData:
	return create(event.entity_id, event.status_id, event.remove_reason)
