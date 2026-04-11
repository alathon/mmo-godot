class_name Cooldowns
extends Node

## Tracks per-ability and per-group cooldowns for one entity.
## Does NOT track GCD or animation lock — those live on MobCombatState.
## Server: ticked by CombatManager each sim tick (no Godot Timer nodes).
## Client: ticked predictively; corrected on AbilityUseRejected.

var _ability: Dictionary = {}  # ability_id -> remaining seconds
var _group: Dictionary = {}    # group_id   -> remaining seconds


func tick(delta: float) -> void:
	for key in _ability:
		_ability[key] = maxf(0.0, _ability[key] - delta)
	for key in _group:
		_group[key] = maxf(0.0, _group[key] - delta)


## Returns true if neither the ability nor its group is on cooldown.
func is_ready(ability_id: String, cooldown_group: String) -> bool:
	if _ability.get(ability_id, 0.0) > 0.0:
		return false
	if cooldown_group != "" and _group.get(cooldown_group, 0.0) > 0.0:
		return false
	return true


## Starts cooldowns. cooldown == 0 is a no-op.
func start(ability_id: String, cooldown: float, cooldown_group: String) -> void:
	if cooldown <= 0.0:
		return
	_ability[ability_id] = cooldown
	if cooldown_group != "":
		_group[cooldown_group] = cooldown


## Cancels cooldowns (e.g. cast was interrupted before completion).
func cancel(ability_id: String, cooldown_group: String) -> void:
	_ability.erase(ability_id)
	if cooldown_group != "":
		_group.erase(cooldown_group)


func get_ability_remaining(ability_id: String) -> float:
	return _ability.get(ability_id, 0.0)


func get_group_remaining(group_id: String) -> float:
	return _group.get(group_id, 0.0)
