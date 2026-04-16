class_name AbilityManager
extends Node

@onready var state: AbilityState = %AbilityState
@onready var cooldowns: AbilityCooldowns = %AbilityCooldowns
@onready var stats: Stats = %Stats
@onready var entity: Node = get_parent()
# @onready var combat_manager: Node = %CombatManager

func init(owner_entity: Node) -> void:
	entity = owner_entity


func tick(delta: float, sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	state.gcd_remaining = maxf(0.0, state.gcd_remaining - delta)
	state.anim_lock_remaining = maxf(0.0, state.anim_lock_remaining - delta)
	cooldowns.tick(delta)
	if state.is_casting():
		state.cast_remaining = maxf(0.0, state.cast_remaining - delta)
		if state.cast_remaining <= 0.0:
			return _complete_cast(sim_tick, context)
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
	if not state.is_casting():
		return []

	var source_entity_id := state.cast_source_entity_id
	var ability_id := state.cast_ability_id
	var events: Array[EntityEvents] = [
		EntityEvents.ability_canceled(source_entity_id, ability_id, reason)
	]

	if context != null:
		_cancel_cooldown(context.ability)
	state.gcd_remaining = 0.0
	state.anim_lock_remaining = 0.0
	state.clear_cast()
	state.clear_queued()
	return events


func clear_queued_ability() -> void:
	state.clear_queued()


func _start_cast(request: AbilityUseRequest, ability: AbilityResource, sim_tick: int) -> Array[EntityEvents]:
	if request == null or ability == null:
		return []

	state.cast_source_entity_id = request.source_entity_id
	state.cast_ability_id = request.ability_id
	state.cast_target = request.target
	state.cast_total = ability.cast_time
	state.cast_remaining = ability.cast_time
	state.cast_requested_tick = request.requested_tick
	state.cast_start_tick = sim_tick

	_apply_gcd(ability)
	state.anim_lock_remaining = AbilityConstants.ANIMATION_LOCK_DURATION
	_apply_cooldown(ability)

	return [
		EntityEvents.ability_started(
				request.source_entity_id,
				request.ability_id,
				_event_target_entity_id(request.target),
				_event_ground_position(request.target),
				ability.cast_time)
	]


func _complete_cast(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if not state.is_casting():
		return []

	var source_entity_id := state.cast_source_entity_id
	var ability_id := state.cast_ability_id
	var target := state.cast_target
	var requested_tick := state.cast_requested_tick
	var events: Array[EntityEvents] = [
		EntityEvents.ability_completed(source_entity_id, ability_id)
	]

	state.clear_cast()
	events.append_array(_resolve_ability(
			source_entity_id,
			ability_id,
			target,
			requested_tick,
			context))
	return events


func _resolve_ability(
		source_entity_id: int,
		ability_id: StringName,
		target: AbilityTargetSpec,
		requested_tick: int,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _queue_ability(request: AbilityUseRequest) -> void:
	if request == null:
		return
	state.queued_source_entity_id = request.source_entity_id
	state.queued_ability_id = request.ability_id
	state.queued_target = request.target
	state.queued_requested_tick = request.requested_tick


func _try_dequeue_ability(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _in_cast_queue_window() -> bool:
	return state.cast_total > 0.0 and \
			state.cast_remaining <= state.cast_total * AbilityConstants.ABILITY_QUEUE_WINDOW


func _in_gcd_queue_window() -> bool:
	return state.gcd_remaining <= AbilityConstants.GCD_DURATION * AbilityConstants.ABILITY_QUEUE_WINDOW


func _apply_gcd(ability: AbilityResource) -> void:
	if ability != null and ability.uses_gcd:
		state.gcd_remaining = AbilityConstants.GCD_DURATION


func _apply_cooldown(ability: AbilityResource) -> void:
	if ability == null:
		return
	cooldowns.start(ability.get_ability_id(), ability.cooldown, StringName(ability.cooldown_group))


func _cancel_cooldown(ability: AbilityResource) -> void:
	if ability == null:
		return
	cooldowns.cancel(ability.get_ability_id(), StringName(ability.cooldown_group))


func _event_target_entity_id(target: AbilityTargetSpec) -> int:
	if target == null:
		return 0
	if target.kind == AbilityTargetSpec.Kind.ENTITY:
		return target.entity_id
	return 0


func _event_ground_position(target: AbilityTargetSpec) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if target.kind == AbilityTargetSpec.Kind.GROUND:
		return target.ground_position
	return Vector3.ZERO
