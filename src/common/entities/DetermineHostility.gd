class_name DetermineHostility
extends Node

enum HostilityState {
	FRIENDLY,
	HOSTILE,
}

var _aggro_by_entity: Dictionary[int, float] = {}


func get_hostility_state(target_entity: Node) -> int:
	if target_entity == null or target_entity == get_parent():
		return HostilityState.FRIENDLY
	if _aggro_by_entity.has(target_entity.get_instance_id()):
		return HostilityState.HOSTILE
	# Everything is hostile.
	# TODO: Actual races/alliances/groups/whatever.
	return HostilityState.HOSTILE


func is_hostile_to(target_entity: Node) -> bool:
	return get_hostility_state(target_entity) == HostilityState.HOSTILE


func is_friendly_to(target_entity: Node) -> bool:
	return get_hostility_state(target_entity) == HostilityState.FRIENDLY


func attacked_by(target_entity: Node, aggro_amount: float = 1.0) -> void:
	if target_entity == null or target_entity == get_parent():
		return
	add_aggro(target_entity, aggro_amount)


func add_aggro(target_entity: Node, aggro_amount: float) -> void:
	if target_entity == null or target_entity == get_parent():
		return
	var entity_id := target_entity.get_instance_id()
	_aggro_by_entity[entity_id] = get_aggro(target_entity) + maxf(0.0, aggro_amount)


func get_aggro(target_entity: Node) -> float:
	if target_entity == null:
		return 0.0
	return _aggro_by_entity.get(target_entity.get_instance_id(), 0.0)


func get_aggro_list() -> Dictionary[int, float]:
	return _aggro_by_entity.duplicate()


func clear_combat() -> void:
	_aggro_by_entity.clear()
