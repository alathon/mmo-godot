class_name AbilityTargetSpec
extends RefCounted

enum Kind {
	NONE,
	ENTITY,
	GROUND,
}

var kind: Kind = Kind.NONE
var entity_id: int = -1
var ground_position: Vector3 = Vector3.ZERO

static func entity(entity_id: int) -> AbilityTargetSpec:
	var target := AbilityTargetSpec.new()
	target.kind = Kind.ENTITY
	target.entity_id = entity_id
	return target


static func ground(position: Vector3) -> AbilityTargetSpec:
	var target := AbilityTargetSpec.new()
	target.kind = Kind.GROUND
	target.ground_position = position
	return target


func get_entity_id() -> int:
	if kind != Kind.ENTITY:
		return -1
	return entity_id


func get_ground_position() -> Vector3:
	if kind != Kind.GROUND:
		return Vector3.ZERO
	return ground_position
