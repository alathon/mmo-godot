class_name EntityEvents
extends RefCounted

enum Type {
	ABILITY_USE_STARTED,
	ABILITY_USE_CANCELED,
	ABILITY_USE_FINISHED,
	ABILITY_USE_IMPACT,
	DAMAGE_TAKEN,
	HEALING_RECEIVED,
	COMBAT_STARTED,
	COMBAT_ENDED,
	COMBATANT_DIED,
	BUFF_APPLIED,
	DEBUFF_APPLIED,
	STATUS_EFFECT_REMOVED,
}

var type: Type = Type.ABILITY_USE_STARTED
var source_entity_id: int = 0
var target_entity_id: int = 0
var entity_id: int = 0
var ability_id: int = 0
var request_id: int = 0
var amount: float = 0.0
var cancel_reason: int = 0
var hit_type: int = 0
var ground_position: Vector3 = Vector3.ZERO
var cast_time: float = 0.0
var killer_entity_id: int = 0
var status_id: int = 0
var remove_reason: int = 0


static func ability_started(
		source_entity_id: int,
		ability_id: int,
		request_id: int = 0,
		target_entity_id: int = 0,
		ground_position: Vector3 = Vector3.ZERO,
		cast_time: float = 0.0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.ABILITY_USE_STARTED
	event.source_entity_id = source_entity_id
	event.target_entity_id = target_entity_id
	event.ability_id = ability_id
	event.request_id = request_id
	event.ground_position = ground_position
	event.cast_time = cast_time
	return event


static func ability_canceled(
		source_entity_id: int,
		ability_id: int,
		cancel_reason: int,
		request_id: int = 0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.ABILITY_USE_CANCELED
	event.source_entity_id = source_entity_id
	event.ability_id = ability_id
	event.cancel_reason = cancel_reason
	event.request_id = request_id
	return event


static func ability_finished(source_entity_id: int, ability_id: int, request_id: int = 0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.ABILITY_USE_FINISHED
	event.source_entity_id = source_entity_id
	event.ability_id = ability_id
	event.request_id = request_id
	return event


static func ability_impact(source_entity_id: int, ability_id: int, request_id: int = 0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.ABILITY_USE_IMPACT
	event.source_entity_id = source_entity_id
	event.ability_id = ability_id
	event.request_id = request_id
	return event


static func damage_taken(
		source_entity_id: int,
		target_entity_id: int,
		ability_id: int,
		amount: float) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.DAMAGE_TAKEN
	event.source_entity_id = source_entity_id
	event.target_entity_id = target_entity_id
	event.ability_id = ability_id
	event.amount = amount
	return event


static func healing_received(
		source_entity_id: int,
		target_entity_id: int,
		ability_id: int,
		amount: float) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.HEALING_RECEIVED
	event.source_entity_id = source_entity_id
	event.target_entity_id = target_entity_id
	event.ability_id = ability_id
	event.amount = amount
	return event


static func combat_started(entity_id: int, source_entity_id: int = 0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.COMBAT_STARTED
	event.entity_id = entity_id
	event.source_entity_id = source_entity_id
	return event


static func combat_ended(entity_id: int) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.COMBAT_ENDED
	event.entity_id = entity_id
	return event


static func combatant_died(entity_id: int, killer_entity_id: int = 0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.COMBATANT_DIED
	event.entity_id = entity_id
	event.killer_entity_id = killer_entity_id
	return event


static func buff_applied(
		source_entity_id: int,
		target_entity_id: int,
		ability_id: int,
		status_id: int,
		remaining_duration: float = 0.0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.BUFF_APPLIED
	event.source_entity_id = source_entity_id
	event.target_entity_id = target_entity_id
	event.ability_id = ability_id
	event.status_id = status_id
	event.amount = remaining_duration
	return event


static func debuff_applied(
		source_entity_id: int,
		target_entity_id: int,
		ability_id: int,
		status_id: int,
		remaining_duration: float = 0.0) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.DEBUFF_APPLIED
	event.source_entity_id = source_entity_id
	event.target_entity_id = target_entity_id
	event.ability_id = ability_id
	event.status_id = status_id
	event.amount = remaining_duration
	return event


static func status_effect_removed(entity_id: int, status_id: int, remove_reason: int) -> EntityEvents:
	var event := EntityEvents.new()
	event.type = Type.STATUS_EFFECT_REMOVED
	event.entity_id = entity_id
	event.status_id = status_id
	event.remove_reason = remove_reason
	return event
