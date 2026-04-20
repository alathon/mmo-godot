class_name Mob
extends Node

@onready var stats: Stats = %Stats
@onready var hostility: DetermineHostility = %DetermineHostility


func is_alive() -> bool:
	return stats != null and stats.hp > 0


func is_hostile_to(target_entity: Node) -> bool:
	return hostility != null and hostility.is_hostile_to(target_entity)


func is_friendly_to(target_entity: Node) -> bool:
	return hostility == null or hostility.is_friendly_to(target_entity)
