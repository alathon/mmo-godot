class_name EntityEvents
extends RefCounted

enum Type {
	ABILITY_USE_STARTED,
	ABILITY_USE_CANCELED,
	ABILITY_USE_COMPLETED,
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
var ability_id: StringName = &""
var amount: float = 0.0
var cancel_reason: int = 0
var hit_type: int = 0
var ground_position: Vector3 = Vector3.ZERO
var cast_time: float = 0.0
var killer_entity_id: int = 0
var status_effect_id: StringName = &""
var remove_reason: int = 0


static func ability_started():
	return null


static func ability_canceled():
	return null


static func ability_completed():
	return null


static func damage_taken():
	return null


static func healing_received():
	return null


static func combat_started():
	return null


static func combat_ended():
	return null


static func combatant_died():
	return null


static func buff_applied():
	return null


static func debuff_applied():
	return null


static func status_effect_removed():
	return null
