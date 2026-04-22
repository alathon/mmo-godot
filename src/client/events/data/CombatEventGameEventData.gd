class_name CombatEventGameEventData
extends RefCounted

var entity_id: int = 0
var source_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var killer_entity_id: int = 0


static func create(
		p_entity_id: int,
		p_source_entity_id: int = 0,
		p_killer_entity_id: int = 0) -> CombatEventGameEventData:
	var data := CombatEventGameEventData.new()
	data.entity_id = p_entity_id
	data.source_entity_id = p_source_entity_id
	data.killer_entity_id = p_killer_entity_id
	return data


static func from_entity_event(event: EntityEvents) -> CombatEventGameEventData:
	return create(event.entity_id, event.source_entity_id, event.killer_entity_id)
