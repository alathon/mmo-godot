class_name CombatTargeting
extends RefCounted

var _zone: Node = null


func init(zone: Node) -> void:
	_zone = zone


func is_valid_combat_target(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource) -> bool:
	if source_entity == null or target_entity == null or ability == null:
		return false
	var target_manager := _get_combat_manager(target_entity)
	if target_manager == null or not target_manager.is_alive():
		return false
	match ability.target_type:
		AbilityResource.TargetType.SELF:
			return source_entity == target_entity
		AbilityResource.TargetType.OTHER_ENEMY:
			return is_hostile_target(source_entity, target_entity)
		AbilityResource.TargetType.OTHER_FRIEND:
			return is_friendly_target(source_entity, target_entity)
		AbilityResource.TargetType.OTHER_ANY:
			return source_entity != target_entity
		_:
			return true


func is_hostile_target(source_entity: Node, target_entity: Node) -> bool:
	var source_manager := _get_combat_manager(source_entity)
	return source_manager != null and source_manager.is_hostile_to(target_entity)


func is_friendly_target(source_entity: Node, target_entity: Node) -> bool:
	var source_manager := _get_combat_manager(source_entity)
	return source_manager != null and source_manager.is_friendly_to(target_entity)


func is_alive_target(target_entity: Node) -> bool:
	var target_manager := _get_combat_manager(target_entity)
	return target_manager != null and target_manager.is_alive()


func is_in_combat_range(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	if source_entity == null or target_entity == null or ability == null:
		return false
	if ability.range <= 0.0:
		return true
	return _get_entity_position(source_entity).distance_to(_get_entity_position(target_entity)) <= ability.range


func _get_combat_manager(entity: Node) -> CombatManager:
	if entity == null:
		return null
	return entity.combat_manager as CombatManager


func _get_entity_position(entity: Node) -> Vector3:
	if entity is Node3D:
		return entity.global_position
	return entity.body.global_position
