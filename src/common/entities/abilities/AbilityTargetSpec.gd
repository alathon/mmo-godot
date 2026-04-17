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


static func self_target() -> AbilityTargetSpec:
	var target := AbilityTargetSpec.new()
	target.kind = Kind.SELF
	return target


static func current_target() -> AbilityTargetSpec:
	var target := AbilityTargetSpec.new()
	target.kind = Kind.CURRENT_TARGET
	return target


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
