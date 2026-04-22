class_name LocalAbilityRequestResult
extends RefCounted

var accepted: bool = false
var should_send_to_server: bool = false
var request_id: int = 0
var ability_id: int = 0
var target: AbilityTargetSpec = null
var reject_reason: int = AbilityConstants.CANCEL_INVALID
var game_events: Array[GameEvent] = []


func get_target_entity_id() -> int:
	if target != null and target.kind == AbilityTargetSpec.Kind.ENTITY:
		return target.entity_id
	return 0


func get_ground_position() -> Vector3:
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return target.ground_position
	return Vector3.ZERO
