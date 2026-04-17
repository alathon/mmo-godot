class_name AbilityTargeting
extends RefCounted

const DEFAULT_CONE_HALF_ANGLE_RADIANS := PI * 0.25

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
	if ability != null and ability.aoe_shape != AbilityResource.AoeShape.NONE:
		return _resolve_aoe_targets(source_entity, ability, target)

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
			return _resolve_ground_targets(source_entity, ability, target.ground_position)
		_:
			return []


func get_valid_targets_for(source_entity: Node, ability: AbilityResource) -> Array[Node]:
	var targets: Array[Node] = []
	for candidate in _get_candidate_entities():
		if is_valid_target(source_entity, candidate, ability):
			targets.append(candidate)
	return targets


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
	if source_entity is ServerPlayer:
		return (source_entity as ServerPlayer).target_state.get_target_entity_id()
	if source_entity.has_method("get_target_entity_id"):
		return source_entity.get_target_entity_id()
	return 0


func _resolve_aoe_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	match ability.aoe_shape:
		AbilityResource.AoeShape.CIRCLE:
			return _resolve_circle_targets(source_entity, ability, _get_aoe_center(source_entity, ability, target))
		AbilityResource.AoeShape.CONE:
			return _resolve_cone_targets(source_entity, ability, target)
		_:
			return []


func _resolve_ground_targets(
		source_entity: Node,
		ability: AbilityResource,
		ground_position: Vector3) -> Array[Node]:
	if ability == null:
		return []
	if ability.aoe_shape == AbilityResource.AoeShape.NONE:
		return []
	return _resolve_aoe_targets(source_entity, ability, AbilityTargetSpec.ground(ground_position))


func _resolve_circle_targets(source_entity: Node, ability: AbilityResource, center: Vector3) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var targets: Array[Node] = []
	for candidate in get_valid_targets_for(source_entity, ability):
		if get_entity_position(candidate).distance_to(center) <= radius:
			targets.append(candidate)
	return targets


func _resolve_cone_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var source_position := get_entity_position(source_entity)
	var forward := _get_cone_forward(source_entity, target)
	if forward == Vector3.ZERO:
		return []

	var targets: Array[Node] = []
	for candidate in get_valid_targets_for(source_entity, ability):
		var offset := get_entity_position(candidate) - source_position
		offset.y = 0.0
		if offset == Vector3.ZERO or offset.length() > radius:
			continue
		if forward.angle_to(offset.normalized()) <= DEFAULT_CONE_HALF_ANGLE_RADIANS:
			targets.append(candidate)
	return targets


func _get_aoe_center(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> Vector3:
	if target == null:
		return get_entity_position(source_entity)
	match target.kind:
		AbilityTargetSpec.Kind.GROUND:
			return target.ground_position
		AbilityTargetSpec.Kind.ENTITY:
			return get_entity_position(get_entity_by_id(target.entity_id))
		AbilityTargetSpec.Kind.CURRENT_TARGET:
			return get_entity_position(get_entity_by_id(_get_current_target_id(source_entity)))
		AbilityTargetSpec.Kind.SELF:
			return get_entity_position(source_entity)
		_:
			return get_entity_position(source_entity)


func _get_cone_forward(source_entity: Node, target: AbilityTargetSpec) -> Vector3:
	var source_position := get_entity_position(source_entity)
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		var toward_ground := target.ground_position - source_position
		toward_ground.y = 0.0
		return toward_ground.normalized() if toward_ground != Vector3.ZERO else Vector3.ZERO
	if source_entity is ServerPlayer:
		var angle := (source_entity as ServerPlayer).body.face_angle
		return Vector3(-sin(angle), 0.0, -cos(angle)).normalized()
	return Vector3.ZERO


func _get_aoe_radius(ability: AbilityResource) -> float:
	if ability == null:
		return 0.0
	if ability.aoe_radius > 0.0:
		return ability.aoe_radius
	return ability.range


func _get_candidate_entities() -> Array[Node]:
	var candidates: Array[Node] = []
	if _zone == null:
		return candidates
	for entity_id in _zone.players:
		candidates.append(_zone.players[entity_id])
	return candidates


func _is_combat_target_type(target_type: int) -> bool:
	return target_type == AbilityResource.TargetType.OTHER_ENEMY or \
			target_type == AbilityResource.TargetType.OTHER_FRIEND or \
			target_type == AbilityResource.TargetType.OTHER_ANY
