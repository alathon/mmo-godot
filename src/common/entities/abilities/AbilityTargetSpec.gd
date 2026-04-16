class_name AbilityTargetSpec
extends RefCounted

enum Kind {
	NONE,
	ENTITY,
	GROUND,
	SELF,
	CURRENT_TARGET,
}

var kind: Kind = Kind.NONE
var entity_id: int = 0
var ground_position: Vector3 = Vector3.ZERO


static func self_target():
	return null


static func current_target():
	return null


static func entity(entity_id: int):
	return null


static func ground(position: Vector3):
	return null
