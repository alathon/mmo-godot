class_name AbilityManager
extends Node

@onready var entity_state: EntityState = %EntityState
@onready var cooldowns: AbilityCooldowns = %Cooldowns
@onready var entity: Node = get_parent()

var _target_resolver = null
var ability_state: AbilityState:
	get:
		return entity_state.ability_state


func set_target_resolver(target_resolver) -> void:
	_target_resolver = target_resolver


func evaluate_activation(
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		requested_tick: int) -> AbilityDecision:
	var decision = AbilityDecision.new()
	decision.request_id = request_id
	decision.ability_id = ability_id
	decision.target = target
	decision.requested_tick = requested_tick

	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		decision.reject_reason = AbilityConstants.CANCEL_INVALID
		return decision

	if not _passes_common_validation(ability, target):
		decision.reject_reason = _get_validation_failure_reason(ability, target)
		return decision

	if ability_state.current_queue != null and ability_state.current_queue.request_id != request_id:
		decision.reject_reason = AbilityConstants.CANCEL_INVALID
		return decision

	if ability_state.is_casting():
		if _in_cast_queue_window(requested_tick):
			decision.outcome = AbilityDecision.Outcome.QUEUED
			decision.earliest_activate_tick = _get_cast_queue_ready_tick(ability, requested_tick)
			return decision
		decision.reject_reason = AbilityConstants.CANCEL_INVALID
		return decision

	if ability.uses_gcd and ability_state.is_on_gcd(requested_tick):
		if _in_gcd_queue_window(requested_tick):
			decision.outcome = AbilityDecision.Outcome.QUEUED
			decision.earliest_activate_tick = _get_gcd_ready_tick(requested_tick)
			return decision
		decision.reject_reason = AbilityConstants.CANCEL_INVALID
		return decision

	if ability_state.is_animation_locked(requested_tick):
		decision.reject_reason = AbilityConstants.CANCEL_INVALID
		return decision

	decision.outcome = AbilityDecision.Outcome.STARTED
	return decision


func start_cast(
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		start_tick: int) -> Array[AbilityTransition]:
	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		return []

	var cast := ability_state.start_cast_from_ability(request_id, ability, target, start_tick)
	if cast == null:
		return []

	return [
		AbilityTransition.cast_started(
				_get_source_entity_id(),
				request_id,
				ability_id,
				target,
				start_tick,
				ability.cast_time,
				cast.lock_tick,
				cast.resolve_tick,
				cast.finish_tick,
				cast.impact_tick)
	]


func queue_request(
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		earliest_activate_tick: int) -> void:
	ability_state.queue_request(request_id, ability_id, target, earliest_activate_tick)


func clear_queued_request(request_id: int = 0) -> void:
	ability_state.clear_queue(request_id)


func correct_cast_timing(
		request_id: int,
		start_tick: int,
		resolve_tick: int,
		finish_tick: int,
		impact_tick: int) -> void:
	ability_state.confirm_cast_timing(request_id, start_tick, resolve_tick, finish_tick, impact_tick)


func commit_cast_costs(request_id: int) -> void:
	var cast = _get_cast_by_request_id(request_id)
	if cast == null or cast.costs_committed:
		return
	var ability := AbilityDB.get_ability(cast.ability_id)
	if ability == null:
		return
	entity_state.spend_resources_for(ability)
	cooldowns.start(ability.get_ability_id(), ability.cooldown, StringName(ability.cooldown_group))
	cast.costs_committed = true


func cancel_current_cast(cancel_reason: int, current_tick: int) -> Array[AbilityTransition]:
	if ability_state.current_cast == null:
		return []

	var cast := ability_state.current_cast
	var ability := AbilityDB.get_ability(cast.ability_id)
	ability_state.rollback_started_timers(ability, current_tick)
	if ability != null:
		cooldowns.cancel(ability.get_ability_id(), StringName(ability.cooldown_group))
	ability_state.clear_cast(cast.request_id)
	return [
		AbilityTransition.cast_canceled(
				_get_source_entity_id(),
				cast.request_id,
				cast.ability_id,
				cast.target,
				current_tick,
				cancel_reason)
	]


func tick(current_tick: int) -> Array[AbilityTransition]:
	var transitions: Array[AbilityTransition] = []

	if ability_state.current_cast != null:
		var cast := ability_state.current_cast
		if not cast.locked and current_tick >= cast.lock_tick:
			ability_state.lock_current_cast(cast.request_id)
			transitions.append(AbilityTransition.cast_locked(
					_get_source_entity_id(),
					cast.request_id,
					cast.ability_id,
					cast.target,
					current_tick))
		if not cast.resolved and current_tick >= cast.resolve_tick:
			ability_state.mark_resolved(cast.request_id)
			transitions.append(AbilityTransition.cast_resolve_due(
					_get_source_entity_id(),
					cast.request_id,
					cast.ability_id,
					cast.target,
					current_tick,
					cast.start_tick,
					cast.lock_tick,
					cast.resolve_tick,
					cast.finish_tick,
					cast.impact_tick))
		if not cast.finished and current_tick >= cast.finish_tick:
			ability_state.finish_cast(cast.request_id)
			transitions.append(AbilityTransition.cast_finished(
					_get_source_entity_id(),
					cast.request_id,
					cast.ability_id,
					cast.target,
					current_tick,
					cast.start_tick,
					cast.lock_tick,
					cast.resolve_tick,
					cast.finish_tick,
					cast.impact_tick))
		if not cast.impact_emitted and current_tick >= cast.impact_tick:
			ability_state.mark_impact_emitted(cast.request_id)
			transitions.append(AbilityTransition.cast_impact_due(
					_get_source_entity_id(),
					cast.request_id,
					cast.ability_id,
					cast.target,
					current_tick,
					cast.start_tick,
					cast.lock_tick,
					cast.resolve_tick,
					cast.finish_tick,
					cast.impact_tick))
			ability_state.clear_cast(cast.request_id)

	for pending_cast_value in ability_state.pending_impacts.duplicate():
		var pending_cast := pending_cast_value as AbilityState.Cast
		if pending_cast == null or pending_cast.impact_emitted:
			continue
		if current_tick >= pending_cast.impact_tick:
			ability_state.mark_impact_emitted(pending_cast.request_id)
			ability_state.remove_pending_impact(pending_cast.request_id)
			transitions.append(AbilityTransition.cast_impact_due(
					_get_source_entity_id(),
					pending_cast.request_id,
					pending_cast.ability_id,
					pending_cast.target,
					current_tick,
					pending_cast.start_tick,
					pending_cast.lock_tick,
					pending_cast.resolve_tick,
					pending_cast.finish_tick,
					pending_cast.impact_tick))

	if ability_state.current_queue != null and (ability_state.current_cast == null or ability_state.current_cast.finished):
		var queued := ability_state.current_queue
		if current_tick >= queued.earliest_activate_tick:
			ability_state.clear_queue(queued.request_id)
			transitions.append(AbilityTransition.queued_request_ready(
					_get_source_entity_id(),
					queued.request_id,
					queued.ability_id,
					queued.target,
					current_tick))

	return transitions


func has_active_cast_request(request_id: int) -> bool:
	return ability_state.current_cast != null and ability_state.current_cast.request_id == request_id


func has_queued_request(request_id: int) -> bool:
	return ability_state.current_queue != null and ability_state.current_queue.request_id == request_id


func has_pending_impact(request_id: int) -> bool:
	return ability_state.has_pending_impact(request_id)


func can_movement_cancel_current_cast() -> bool:
	return ability_state.current_cast != null and not ability_state.current_cast.locked and not ability_state.current_cast.finished


func can_activate_ability(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		current_tick: int) -> AbilityValidationResult:
	if ability == null:
		return AbilityValidationResult.rejected(&"ability_missing", AbilityConstants.CANCEL_INVALID)
	if not _passes_common_validation(ability, target):
		return AbilityValidationResult.rejected(&"invalid_state", _get_validation_failure_reason(ability, target))
	if ability_state.current_queue != null:
		return AbilityValidationResult.rejected(&"queue_full", AbilityConstants.CANCEL_INVALID)
	if ability_state.is_casting():
		return AbilityValidationResult.rejected(&"already_casting", AbilityConstants.CANCEL_INVALID)
	if ability.uses_gcd and ability_state.is_on_gcd(current_tick):
		return AbilityValidationResult.rejected(&"gcd_active", AbilityConstants.CANCEL_INVALID)
	if ability_state.is_animation_locked(current_tick):
		return AbilityValidationResult.rejected(&"animation_locked", AbilityConstants.CANCEL_INVALID)
	return AbilityValidationResult.accepted()


func is_target_legal(
		ability: AbilityResource,
		target: AbilityTargetSpec) -> bool:
	if ability == null:
		return false

	match ability.target_type:
		AbilityResource.TargetType.SELF:
			return true
		AbilityResource.TargetType.GROUND:
			return target != null and target.kind == AbilityTargetSpec.Kind.GROUND
		_:
			pass

	if target == null or target.kind != AbilityTargetSpec.Kind.ENTITY:
		return false

	var target_entity := _get_entity_by_id(target.entity_id)
	if target_entity == null:
		return false
	if not target_entity.entity_state.is_alive():
		return false

	return _is_in_range(ability, target, target_entity)


func _passes_common_validation(ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	if ability == null:
		return false
	if not cooldowns.is_ready(ability.get_ability_id(), StringName(ability.cooldown_group)):
		return false
	if not entity_state.has_resources_for(ability):
		return false
	if not is_target_legal(ability, target):
		return false
	return true


func _get_validation_failure_reason(ability: AbilityResource, target: AbilityTargetSpec) -> int:
	if ability == null:
		return AbilityConstants.CANCEL_INVALID
	if not cooldowns.is_ready(ability.get_ability_id(), StringName(ability.cooldown_group)):
		return AbilityConstants.CANCEL_INVALID
	if not entity_state.has_resources_for(ability):
		return AbilityConstants.CANCEL_INSUFFICIENT_RESOURCES
	if not is_target_legal(ability, target):
		return AbilityConstants.CANCEL_INVALID
	return AbilityConstants.CANCEL_INVALID


func _get_gcd_ready_tick(current_tick: int) -> int:
	return maxi(current_tick, ability_state.gcd_end_tick)


func _get_cast_queue_ready_tick(ability: AbilityResource, current_tick: int) -> int:
	var ready_tick := ability_state.current_cast.finish_tick
	if ability != null and ability.uses_gcd:
		ready_tick = maxi(ready_tick, _get_gcd_ready_tick(current_tick))
	return ready_tick


func _in_cast_queue_window(current_tick: int) -> bool:
	if ability_state.current_cast == null:
		return false
	var total_ticks := maxi(0, ability_state.current_cast.finish_tick - ability_state.current_cast.start_tick)
	if total_ticks <= 0:
		return false
	var remaining_ticks := maxi(0, ability_state.current_cast.finish_tick - current_tick)
	return remaining_ticks <= int(ceil(float(total_ticks) * AbilityConstants.ABILITY_QUEUE_WINDOW))


func _in_gcd_queue_window(current_tick: int) -> bool:
	var queue_window_ticks := int(ceil(
			AbilityConstants.GCD_DURATION
			* AbilityConstants.ABILITY_QUEUE_WINDOW
			* float(Globals.TICK_RATE)))
	return ability_state.get_gcd_remaining_ticks(current_tick) <= queue_window_ticks


func _get_source_entity_id() -> int:
	return int(entity.id)


func _get_entity_by_id(entity_id: int) -> Node:
	if entity_id <= 0 or _target_resolver == null:
		return null
	if _target_resolver.has_method("get_entity_by_id"):
		return _target_resolver.get_entity_by_id(entity_id)
	return null


func _is_in_range(ability: AbilityResource, target: AbilityTargetSpec, target_entity: Node) -> bool:
	if ability == null or ability.range <= 0.0:
		return true
	var source_position := _get_entity_position(entity)
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return source_position.distance_to(target.ground_position) <= ability.range
	return source_position.distance_to(_get_entity_position(target_entity)) <= ability.range


func _get_entity_position(target_entity: Node) -> Vector3:
	if target_entity == null:
		return Vector3.ZERO
	if target_entity is Node3D:
		return (target_entity as Node3D).global_position
	return target_entity.body.global_position


func _get_cast_by_request_id(request_id: int):
	if request_id <= 0:
		return null
	if ability_state.current_cast != null and ability_state.current_cast.request_id == request_id:
		return ability_state.current_cast
	return ability_state.get_pending_impact(request_id)
