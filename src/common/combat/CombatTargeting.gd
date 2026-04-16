class_name CombatTargeting
extends RefCounted

var _zone: Node = null


func init(zone: Node) -> void:
	pass


func is_valid_combat_target(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource) -> bool:
	return false


func is_hostile_target(source_entity: Node, target_entity: Node) -> bool:
	return false


func is_friendly_target(source_entity: Node, target_entity: Node) -> bool:
	return false


func is_alive_target(target_entity: Node) -> bool:
	return false


func is_in_combat_range(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	return false
