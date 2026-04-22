class_name HealingReceivedGameEventData
extends RefCounted

var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var amount: float = 0.0


static func create(
		p_source_entity_id: int,
		p_target_entity_id: int,
		p_ability_id: int,
		p_amount: float) -> HealingReceivedGameEventData:
	var data := HealingReceivedGameEventData.new()
	data.source_entity_id = p_source_entity_id
	data.target_entity_id = p_target_entity_id
	data.ability_id = p_ability_id
	data.amount = p_amount
	return data


static func from_entity_event(event: EntityEvents) -> HealingReceivedGameEventData:
	return create(event.source_entity_id, event.target_entity_id, event.ability_id, event.amount)
