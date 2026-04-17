class_name AbilityTargeting
extends RefCounted

var _zone: Node = null
var _combat_system: CombatSystem = null


func init(zone: Node, combat_system: CombatSystem) -> void:
	_zone = zone
	_combat_system = combat_system


func resolve_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	if source_entity == null or target == null:
		return []
	if ability != null and ability.target_type == AbilityResource.TargetType.SELF:
		return [source_entity]

	match target.kind:
		AbilityTargetSpec.Kind.SELF:
			return [source_entity]
		AbilityTargetSpec.Kind.ENTITY:
			var explicit_target := get_entity_by_id(target.entity_id)
			return [explicit_target] if explicit_target != null else []
		AbilityTargetSpec.Kind.CURRENT_TARGET:
			var current_target_id := _get_current_target_id(source_entity)
			var current_target := get_entity_by_id(current_target_id)
			return [current_target] if current_target != null else []
		AbilityTargetSpec.Kind.GROUND:
			return []
		_:
			return []


func get_valid_targets_for(source_entity: Node, ability: AbilityResource) -> Array[Node]:
	return []


func is_valid_target(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	if source_entity == null or target_entity == null or ability == null:
		return false
	if ability.target_type == AbilityResource.TargetType.SELF:
		return source_entity == target_entity
	if _is_combat_target_type(ability.target_type) and _combat_system != null:
		return _combat_system.is_valid_combat_target(source_entity, target_entity, ability)
	return true


func is_in_range(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	if source_entity == null or ability == null:
		return false
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return get_entity_position(source_entity).distance_to(target.ground_position) <= ability.range
	var target_entities := resolve_targets(source_entity, ability, target)
	if target_entities.is_empty():
		return ability.target_type == AbilityResource.TargetType.GROUND
	for target_entity in target_entities:
		if not is_valid_target(source_entity, target_entity, ability):
			return false
		if ability.range <= 0.0:
			continue
		if get_entity_position(source_entity).distance_to(get_entity_position(target_entity)) > ability.range:
			return false
	return true


func get_entity_position(entity: Node) -> Vector3:
	if entity == null:
		return Vector3.ZERO
	if entity is ServerPlayer:
		return (entity as ServerPlayer).body.global_position
	if entity is Node3D:
		return entity.global_position
	return Vector3.ZERO


func get_entity_by_id(entity_id: int) -> Node:
	if _zone == null or entity_id <= 0:
		return null
	return _zone.players.get(entity_id, null)


func _get_current_target_id(source_entity: Node) -> int:
	if source_entity == null:
		return 0
	if source_entity.has_method("get_target_entity_id"):
		return source_entity.get_target_entity_id()
	return 0


func _is_combat_target_type(target_type: int) -> bool:
	return target_type == AbilityResource.TargetType.OTHER_ENEMY or \
			target_type == AbilityResource.TargetType.OTHER_FRIEND or \
			target_type == AbilityResource.TargetType.OTHER_ANY
