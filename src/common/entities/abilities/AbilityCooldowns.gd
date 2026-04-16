class_name AbilityCooldowns
extends Node

var _ability: Dictionary = {}
var _group: Dictionary = {}


func tick(delta: float) -> void:
	for ability_id in _ability.keys():
		var remaining := maxf(0.0, _ability[ability_id] - delta)
		if remaining <= 0.0:
			_ability.erase(ability_id)
		else:
			_ability[ability_id] = remaining

	for group_id in _group.keys():
		var remaining := maxf(0.0, _group[group_id] - delta)
		if remaining <= 0.0:
			_group.erase(group_id)
		else:
			_group[group_id] = remaining


func is_ready(ability_id: StringName, cooldown_group: StringName) -> bool:
	if get_ability_remaining(ability_id) > 0.0:
		return false
	if cooldown_group != &"" and get_group_remaining(cooldown_group) > 0.0:
		return false
	return true


func start(ability_id: StringName, cooldown: float, cooldown_group: StringName) -> void:
	if cooldown <= 0.0:
		return
	_ability[ability_id] = cooldown
	if cooldown_group != &"":
		_group[cooldown_group] = cooldown


func cancel(ability_id: StringName, cooldown_group: StringName) -> void:
	_ability.erase(ability_id)
	if cooldown_group != &"":
		_group.erase(cooldown_group)


func get_ability_remaining(ability_id: StringName) -> float:
	return _ability.get(ability_id, 0.0)


func get_group_remaining(group_id: StringName) -> float:
	return _group.get(group_id, 0.0)
