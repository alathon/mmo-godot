class_name AbilityManager
extends Node

@onready var state: AbilityState = %AbilityState
@onready var cooldowns: AbilityCooldowns = %AbilityCooldowns
@onready var stats: Stats = %Stats
@onready var entity: Node = get_parent()
# @onready var combat_manager: Node = %CombatManager

var _completed_uses: Array[CompletedAbilityUse] = []


func init(owner_entity: Node) -> void:
	entity = owner_entity


func tick(delta: float, sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	var events: Array[EntityEvents] = []
	state.gcd_remaining = maxf(0.0, state.gcd_remaining - delta)
	state.anim_lock_remaining = maxf(0.0, state.anim_lock_remaining - delta)
	cooldowns.tick(delta)
	if state.is_casting():
		state.cast_remaining = maxf(0.0, state.cast_remaining - delta)
		if state.cast_remaining <= 0.0:
			events.append_array(_complete_cast(sim_tick, context))
	if not state.is_casting():
		events.append_array(_try_dequeue_ability(sim_tick, context))
	return events


func use_ability(
		ability_id: StringName,
		target: AbilityTargetSpec,
		requested_tick: int,
		context: AbilityExecutionContext) -> AbilityUseResult:
	if context == null or context.ability_db == null:
		return AbilityUseResult.rejected_result(ability_id, requested_tick, AbilityConstants.CANCEL_INVALID)

	var ability := context.ability_db.get_ability(ability_id)
	var validation := can_use_ability(ability, target, context, true)
	if not validation.ok:
		return AbilityUseResult.rejected_result(ability_id, requested_tick, validation.cancel_reason)

	var source_entity_id := context.source_entity_id
	var request := AbilityUseRequest.create(source_entity_id, ability_id, target, requested_tick)
	if _should_queue_ability():
		_queue_ability(request)
		return AbilityUseResult.accepted_result(ability_id, requested_tick, 0)

	var events := _start_cast(request, ability, context.sim_tick)

	if ability.cast_time <= 0.0:
		events.append_array(_complete_cast(context.sim_tick, context))

	return AbilityUseResult.accepted_result(ability_id, requested_tick, context.sim_tick, events)


func can_use_ability(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext,
		allow_queue: bool = false) -> AbilityValidationResult:
	if ability == null:
		return AbilityValidationResult.rejected(&"ability_missing", AbilityConstants.CANCEL_INVALID)
	if is_animation_locked() and not _can_queue_now(allow_queue):
		return AbilityValidationResult.rejected(&"animation_locked", AbilityConstants.CANCEL_INVALID)
	if state.is_casting():
		if not _can_queue_now(allow_queue):
			return AbilityValidationResult.rejected(&"already_casting", AbilityConstants.CANCEL_INVALID)
	if ability.uses_gcd and is_on_gcd():
		if not _can_queue_now(allow_queue):
			return AbilityValidationResult.rejected(&"gcd_active", AbilityConstants.CANCEL_INVALID)
	if not cooldowns.is_ready(ability.get_ability_id(), StringName(ability.cooldown_group)):
		return AbilityValidationResult.rejected(&"cooldown_active", AbilityConstants.CANCEL_INVALID)
	if not has_resources_for(ability):
		return AbilityValidationResult.rejected(&"insufficient_resources", AbilityConstants.CANCEL_INVALID)
	if not is_target_legal(ability, target, context):
		return AbilityValidationResult.rejected(&"invalid_target", AbilityConstants.CANCEL_INVALID)
	return AbilityValidationResult.accepted()


func resolve_targets(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> Array[Node]:
	if context == null or context.ability_system == null:
		return []
	return context.ability_system.resolve_targets(entity, ability, target)


func is_target_legal(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> bool:
	if ability == null or context == null or context.ability_system == null:
		return false
	if not context.ability_system.is_in_range(entity, ability, target):
		return false
	if ability.target_type == AbilityResource.TargetType.GROUND:
		return target != null and target.kind == AbilityTargetSpec.Kind.GROUND
	return resolve_targets(ability, target, context).size() > 0


func has_resources_for(ability: AbilityResource) -> bool:
	if ability == null or stats == null:
		return false
	return stats.mana >= ability.mana_cost and \
			stats.stamina >= ability.stamina_cost and \
			stats.energy >= ability.energy_cost


func spend_resources_for(ability: AbilityResource) -> void:
	if ability == null or stats == null:
		return
	stats.mana = maxi(0, stats.mana - ability.mana_cost)
	stats.stamina = maxi(0, stats.stamina - ability.stamina_cost)
	stats.energy = maxi(0, stats.energy - ability.energy_cost)


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

	_cancel_cast_cooldown(ability_id, context)
	state.gcd_remaining = 0.0
	state.anim_lock_remaining = 0.0
	state.clear_cast()
	state.clear_queued()
	return events


func clear_queued_ability() -> void:
	state.clear_queued()


func consume_completed_uses() -> Array[CompletedAbilityUse]:
	var completed := _completed_uses.duplicate()
	_completed_uses.clear()
	return completed


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
	var start_tick := state.cast_start_tick
	var ability := _get_cast_ability(ability_id, context)
	if ability == null or not has_resources_for(ability):
		state.clear_cast()
		return [
			EntityEvents.ability_canceled(source_entity_id, ability_id, AbilityConstants.CANCEL_INVALID)
		]

	spend_resources_for(ability)
	var events: Array[EntityEvents] = [
		EntityEvents.ability_completed(source_entity_id, ability_id)
	]

	_completed_uses.append(CompletedAbilityUse.create(
			source_entity_id,
			ability_id,
			target,
			requested_tick,
			start_tick,
			sim_tick))
	state.clear_cast()
	return events


func _get_cast_ability(ability_id: StringName, context: AbilityExecutionContext) -> AbilityResource:
	if context == null or context.ability_db == null:
		return null
	return context.ability_db.get_ability(ability_id)


func _queue_ability(request: AbilityUseRequest) -> void:
	if request == null:
		return
	state.queued_source_entity_id = request.source_entity_id
	state.queued_ability_id = request.ability_id
	state.queued_target = request.target
	state.queued_requested_tick = request.requested_tick


func _try_dequeue_ability(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if not state.has_queued() or context == null or context.ability_db == null:
		return []
	if state.is_casting() or is_animation_locked():
		return []

	var ability_id := state.queued_ability_id
	var target := state.queued_target
	var ability := context.ability_db.get_ability(ability_id)
	if ability != null and ability.uses_gcd and is_on_gcd():
		return []

	var request := AbilityUseRequest.create(
			state.queued_source_entity_id,
			ability_id,
			target,
			state.queued_requested_tick)
	var validation := can_use_ability(ability, target, context, false)
	state.clear_queued()
	if not validation.ok:
		return [
			EntityEvents.ability_canceled(
					request.source_entity_id,
					request.ability_id,
					validation.cancel_reason)
		]

	var events := _start_cast(request, ability, sim_tick)
	if ability.cast_time <= 0.0:
		events.append_array(_complete_cast(sim_tick, context))
	return events


func _should_queue_ability() -> bool:
	return _can_queue_now(true)


func _can_queue_now(allow_queue: bool) -> bool:
	if not allow_queue:
		return false
	if state.is_casting():
		return _in_cast_queue_window()
	if is_on_gcd():
		return _in_gcd_queue_window()
	return false


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


func _cancel_cast_cooldown(ability_id: StringName, context: AbilityExecutionContext) -> void:
	var ability := _get_cast_ability(ability_id, context)
	if ability != null:
		_cancel_cooldown(ability)


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
