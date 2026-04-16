class_name AbilityTargeting
extends RefCounted

var _zone: Node = null
var _combat_system: CombatSystem = null


func init(zone: Node, combat_system: CombatSystem) -> void:
	pass


func resolve_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	return []


func get_valid_targets_for(source_entity: Node, ability: AbilityResource) -> Array[Node]:
	return []


func is_valid_target(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	return false


func is_in_range(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	return false


func get_entity_position(entity: Node) -> Vector3:
	return Vector3.ZERO


func get_entity_by_id(entity_id: int) -> Node:
	return null
