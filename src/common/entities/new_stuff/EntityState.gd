class_name EntityState
extends Node

@onready var _general_stats: GeneralStats = %GeneralStats
@onready var _class_stats: ClassStats = %ClassStats
@onready var _race_stats: RaceStats = %RaceStats
@onready var _aggro_state: AggroState = %AggroState
@onready var _ability_state: AbilityState = %AbilityState

var in_combat = true:
	set = set_in_combat	

var current_target: Node:
	set = set_target

var is_npc = true

func is_alive() -> bool:
	return _general_stats.hp > 0

func is_attackable_by(target) -> bool:
	if is_npc:
		return true
	
	return false

# kos = kill on sight
func is_kos(target) -> bool:
	if _aggro_state != null and is_npc:
		if _aggro_state.is_on_aggro_list(target):
			return true
	
	# TODO: Some kind of faction/other stuff determining hostility/kill on sight or not
	return true

func set_in_combat(value: bool):
	in_combat = value

func set_target(node: Node):
	current_target = node
