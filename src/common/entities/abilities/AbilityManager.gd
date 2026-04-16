class_name AbilityManager
extends Node

@onready var state: AbilityState = %AbilityState
@onready var cooldowns: AbilityCooldowns = %AbilityCooldowns
@onready var stats: Stats = %Stats
@onready var entity: Node = get_parent()
# @onready var combat_manager: Node = %CombatManager

func init(owner_entity: Node) -> void:
	pass


func tick(delta: float, sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func use_ability(
		ability_id: StringName,
		target: AbilityTargetSpec,
		requested_tick: int,
		context: AbilityExecutionContext) -> AbilityUseResult:
	return AbilityUseResult.new()


func can_use_ability(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext,
		allow_queue: bool = false) -> AbilityValidationResult:
	return AbilityValidationResult.new()


func has_resources_for(ability: AbilityResource) -> bool:
	return false


func spend_resources_for(ability: AbilityResource) -> void:
	pass


func is_casting() -> bool:
	return state.is_casting()


func is_on_gcd() -> bool:
	return state.gcd_remaining > 0.0


func is_animation_locked() -> bool:
	return state.anim_lock_remaining > 0.0


func get_gcd_remaining() -> float:
	return state.gcd_remaining


func get_cooldown_remaining(ability_id: StringName) -> float:
	return cooldowns.get_ability_remaining(ability_id)


func cancel_casting(reason: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func clear_queued_ability() -> void:
	state.clear_queued()


func _start_cast(request: AbilityUseRequest, ability: AbilityResource, sim_tick: int) -> Array[EntityEvents]:
	return []


func _complete_cast(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _resolve_ability(
		request: AbilityUseRequest,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _queue_ability(request: AbilityUseRequest) -> void:
	pass


func _try_dequeue_ability(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _in_cast_queue_window() -> bool:
	return false


func _in_gcd_queue_window() -> bool:
	return false


func _apply_gcd(ability: AbilityResource) -> void:
	pass


func _apply_cooldown(ability: AbilityResource) -> void:
	pass


func _cancel_cooldown(ability: AbilityResource) -> void:
	pass
