class_name AggroState
extends Node

@onready var _entity_state: EntityState = get_parent()

# Entity ID -> Aggro
var aggro_list: Dictionary[int, int]

func get_top_aggro() -> int:
	return -1 # TODO

func change_aggro(from_entity: int, value: int):
	# Store current top aggro
	var top_aggro = get_top_aggro()

	# Change aggro to from_entity by value in aggro_list
	# If 0 or less, remove from aggro_list
	# TODO

	# If new target is top aggro..
	var new_top_aggro = get_top_aggro()
	
	if new_top_aggro == -1:
		# No one left on aggro list.
		_entity_state.set_in_combat(false)
	elif top_aggro != new_top_aggro:
		# New top target
		_entity_state.set_target(top_aggro)

	return

func clear_aggro():
	aggro_list.clear()
	_entity_state.set_in_combat(false)

func is_on_aggro_list(entity_id: int) -> bool:
	return aggro_list.has(entity_id)
