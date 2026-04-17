class_name DetermineHostility
extends Node

enum HostilityState {
	FRIENDLY,
	HOSTILE,
}

var _aggro_by_entity: Dictionary[int, Dictionary] = {}


func get_hostility_state(target_entity: Node) -> int:
	if target_entity == null or target_entity == get_parent():
		return HostilityState.FRIENDLY
	if has_aggro_for(target_entity):
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
	_aggro_by_entity[entity_id] = {
		"entity": weakref(target_entity),
		"threat": get_aggro(target_entity) + maxf(0.0, aggro_amount),
	}


func get_aggro(target_entity: Node) -> float:
	if target_entity == null:
		return 0.0
	var entry := _get_aggro_entry(target_entity)
	if entry.is_empty():
		return 0.0
	return float(entry.get("threat", 0.0))


func get_aggro_list() -> Dictionary[int, float]:
	_clear_missing_aggro_targets()
	var aggro_list: Dictionary[int, float] = {}
	for entity_id in _aggro_by_entity:
		aggro_list[entity_id] = float(_aggro_by_entity[entity_id].get("threat", 0.0))
	return aggro_list


func get_top_aggro_target() -> Node:
	_clear_missing_aggro_targets()
	var top_target: Node = null
	var top_threat := -1.0
	for entry in _aggro_by_entity.values():
		var target_ref := entry.get("entity", null) as WeakRef
		var target := target_ref.get_ref() as Node if target_ref != null else null
		var threat := float(entry.get("threat", 0.0))
		if target != null and threat > top_threat:
			top_target = target
			top_threat = threat
	return top_target


func has_aggro() -> bool:
	_clear_missing_aggro_targets()
	return not _aggro_by_entity.is_empty()


func has_aggro_for(target_entity: Node) -> bool:
	if target_entity == null:
		return false
	var entry := _get_aggro_entry(target_entity)
	return not entry.is_empty()


func clear_aggro(target_entity: Node) -> void:
	if target_entity == null:
		return
	_aggro_by_entity.erase(target_entity.get_instance_id())


func clear_combat() -> void:
	_aggro_by_entity.clear()


func _get_aggro_entry(target_entity: Node) -> Dictionary:
	var entity_id := target_entity.get_instance_id()
	var entry: Dictionary = _aggro_by_entity.get(entity_id, {})
	if entry.is_empty():
		return {}
	var target_ref := entry.get("entity", null) as WeakRef
	if target_ref == null or target_ref.get_ref() == null:
		_aggro_by_entity.erase(entity_id)
		return {}
	return entry


func _clear_missing_aggro_targets() -> void:
	for entity_id in _aggro_by_entity.keys():
		var entry: Dictionary = _aggro_by_entity[entity_id]
		var target_ref := entry.get("entity", null) as WeakRef
		if target_ref == null or target_ref.get_ref() == null:
			_aggro_by_entity.erase(entity_id)
