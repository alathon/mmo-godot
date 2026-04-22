class_name GameEvent
extends RefCounted

enum Type {
	UNKNOWN,
	ABILITY_USE_STARTED,
	ABILITY_USE_CANCELED,
	ABILITY_USE_FINISHED,
	ABILITY_USE_IMPACT,
	ABILITY_USE_RESOLVED,
	DAMAGE_TAKEN,
	HEALING_RECEIVED,
	BUFF_APPLIED,
	DEBUFF_APPLIED,
	STATUS_EFFECT_REMOVED,
	COMBAT_STARTED,
	COMBAT_ENDED,
	COMBATANT_DIED,
}

var tick: int = 0
var type: Type = Type.UNKNOWN
var data: Variant = null


static func create(event_tick: int, event_type: Type, event_data: Variant = null) -> GameEvent:
	var event := GameEvent.new()
	event.tick = event_tick
	event.type = event_type
	event.data = event_data
	return event
