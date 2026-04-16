class_name EntityTargetState
extends Node

var target_entity_id: int = 0


func set_target_entity_id(entity_id: int) -> void:
	target_entity_id = entity_id


func get_target_entity_id() -> int:
	return target_entity_id


func has_target() -> bool:
	return target_entity_id > 0


func clear_target() -> void:
	target_entity_id = 0
