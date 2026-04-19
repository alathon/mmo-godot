class_name ApplyStatusEffect
extends AbilityEffect

@export var status: StatusResource
@export var duration: float = 0.0           # 0 = permanent
@export var max_stacks: int = 1
@export var tick_interval: float = CombatConstants.STATUS_EFFECT_DEFAULT_TICK
@export var tick_effects: Array[AbilityEffect] = []


func get_status_id() -> int:
	if status == null:
		return 0
	return status.status_id


func get_status_name() -> String:
	if status == null:
		return ""
	return status.status_name


func is_debuff() -> bool:
	if status == null:
		return false
	return status.is_debuff
