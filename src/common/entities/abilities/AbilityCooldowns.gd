class_name AbilityCooldowns
extends Node

var _ability: Dictionary = {}
var _group: Dictionary = {}


func tick(delta: float) -> void:
	pass


func is_ready(ability_id: StringName, cooldown_group: StringName) -> bool:
	return false


func start(ability_id: StringName, cooldown: float, cooldown_group: StringName) -> void:
	pass


func cancel(ability_id: StringName, cooldown_group: StringName) -> void:
	pass


func get_ability_remaining(ability_id: StringName) -> float:
	return 0.0


func get_group_remaining(group_id: StringName) -> float:
	return 0.0
