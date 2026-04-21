class_name AggroState
extends Node

@onready var _entity_state: EntityState = get_parent()

var aggro_list: Dictionary = {}


func get_top_aggro() -> int:
	_prune_missing_targets()
	var top_entity_id := -1
	var top_threat := -1.0
	for entity_id in aggro_list:
		var entry := aggro_list[entity_id] as Dictionary
		var threat := float(entry.get("threat", 0.0))
		if threat > top_threat:
			top_threat = threat
			top_entity_id = int(entity_id)
	return top_entity_id


func get_top_aggro_target() -> Node:
	var entity_id := get_top_aggro()
	if entity_id <= 0:
		return null
	var entry := aggro_list.get(entity_id, {}) as Dictionary
	var target_ref := entry.get("entity", null) as WeakRef
	return target_ref.get_ref() as Node


func attacked_by(target_entity: Node, aggro_amount: float = 1.0) -> void:
	add_aggro(target_entity, aggro_amount)


func add_aggro(target_entity: Node, aggro_amount: float) -> void:
	if target_entity == null or target_entity == _owner_entity():
		return

	var entity_id := int(target_entity.id)
	var entry := aggro_list.get(entity_id, {}) as Dictionary
	var current_threat := float(entry.get("threat", 0.0))
	aggro_list[entity_id] = {
		"entity": weakref(target_entity),
		"threat": current_threat + maxf(0.0, aggro_amount),
	}
	_sync_top_target()


func change_aggro(from_entity: int, value: int) -> void:
	var target_entity := _resolve_entity(from_entity)
	if target_entity == null:
		return
	add_aggro(target_entity, value)


func get_aggro(target_entity: Node) -> float:
	if target_entity == null:
		return 0.0
	_prune_missing_targets()
	var entry := aggro_list.get(int(target_entity.id), {}) as Dictionary
	return float(entry.get("threat", 0.0))


func has_aggro() -> bool:
	_prune_missing_targets()
	return not aggro_list.is_empty()


func has_aggro_for(target_entity: Node) -> bool:
	if target_entity == null:
		return false
	return is_on_aggro_list(int(target_entity.id))


func clear_aggro(target_entity: Node = null) -> void:
	if target_entity == null:
		aggro_list.clear()
	else:
		aggro_list.erase(int(target_entity.id))
	_sync_top_target()


func clear_combat() -> void:
	clear_aggro()


func is_on_aggro_list(entity_id: int) -> bool:
	_prune_missing_targets()
	return aggro_list.has(entity_id)


func is_hostile_to(target_entity: Node) -> bool:
	if target_entity == null or target_entity == _owner_entity():
		return false
	if has_aggro_for(target_entity):
		return true
	return true


func is_friendly_to(target_entity: Node) -> bool:
	return not is_hostile_to(target_entity)


func _sync_top_target() -> void:
	var top_target := get_top_aggro_target()
	if top_target == null:
		_entity_state.clear_target()
		_entity_state.set_in_combat(false)
		return
	_entity_state.set_in_combat(true)
	_entity_state.set_target(top_target)


func _prune_missing_targets() -> void:
	for entity_id in aggro_list.keys():
		var entry := aggro_list[entity_id] as Dictionary
		var target_ref := entry.get("entity", null) as WeakRef
		if target_ref == null or target_ref.get_ref() == null:
			aggro_list.erase(entity_id)


func _owner_entity() -> Node:
	return _entity_state.get_parent()


func _resolve_entity(entity_id: int) -> Node:
	if entity_id <= 0:
		return null
	var owner_entity := _owner_entity()
	var node := owner_entity
	while node != null and not node is ServerZone:
		node = node.get_parent()
	if node != null and node.has_method("get_entity_by_id"):
		return node.get_entity_by_id(entity_id)
	return null
