class_name AbilityManager
extends Node

@onready var state: AbilityState = %AbilityState
@onready var cooldowns: AbilityCooldowns = %AbilityCooldowns
@onready var stats: Stats = %Stats
@onready var mob: Mob = %Mob
@onready var entity: Node = get_parent()

var _scheduled_uses: Array = []
var _active_scheduled_use: ScheduledAbilityUse = null
var _recent_completed_requests: Dictionary = {}
var _next_request_id: int = 1

func tick(context: AbilityExecutionContext) -> Array[EntityEvents]:
	var events: Array[EntityEvents] = []
	var delta := context.delta if context != null else 0.0
	var sim_tick := context.sim_tick if context != null else 0
	state.gcd_remaining = maxf(0.0, state.gcd_remaining - delta)
	state.anim_lock_remaining = maxf(0.0, state.anim_lock_remaining - delta)
	cooldowns.tick(delta)
	if state.is_casting():
		if not state.cast_locked and sim_tick >= state.cast_lock_tick:
			state.cast_locked = true
			_log_ability("Lock cast", sim_tick, state.cast_ability_id, state.cast_source_entity_id, {
				"request": state.cast_request_id,
				"lock": state.cast_lock_tick,
				"finish": state.cast_finish_tick,
			})
		if sim_tick >= state.cast_finish_tick:
			events.append_array(_complete_cast(sim_tick, context))
	if not state.is_casting():
		events.append_array(_try_dequeue_ability(sim_tick, context))
	return events


func get_next_request_id() -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	return request_id


func use_ability(
		sim_tick: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> AbilityUseResult:
	var requested_tick := sim_tick
	if ability_id <= 0:
		return AbilityUseResult.rejected_result(
				ability_id,
				requested_tick,
				AbilityConstants.CANCEL_INVALID,
				[],
				request_id,
				target)
	if context == null:
		_log_ability("Reject ability", 0, ability_id, 0, {
			"request": request_id,
			"requested": requested_tick,
			"reason": "missing_context",
			"cancel_reason": AbilityConstants.CANCEL_INVALID,
		})
		return AbilityUseResult.rejected_result(
				ability_id,
				requested_tick,
				AbilityConstants.CANCEL_INVALID,
				[],
				request_id,
				target)

	var ability := AbilityDB.get_ability(ability_id)
	var validation := can_use_ability(ability, target, context, true)
	if not validation.ok:
		_log_ability("Reject ability", sim_tick, ability_id, _get_source_entity_id(context), {
			"request": request_id,
			"requested": requested_tick,
			"reason": validation.reason,
			"cancel_reason": validation.cancel_reason,
		})
		return AbilityUseResult.rejected_result(
				ability_id,
				requested_tick,
				validation.cancel_reason,
				[],
				request_id,
				target)

	if _should_queue_ability(sim_tick):
		_queue_ability(ability_id, target, requested_tick, request_id)
		return AbilityUseResult.accepted_result(ability_id, requested_tick, 0, [], request_id, target)

	var events := _start_cast(sim_tick, request_id, ability_id, target, requested_tick, ability)
	var resolve_tick := state.cast_resolve_tick
	var finish_tick := state.cast_finish_tick
	var impact_tick := state.cast_impact_tick

	if ability.cast_time <= 0.0:
		events.append_array(_complete_cast(sim_tick, context))

	return AbilityUseResult.accepted_result(
			ability_id,
			requested_tick,
			sim_tick,
			events,
			request_id,
			target,
			resolve_tick,
			finish_tick,
			impact_tick)


func can_use_ability(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext,
		allow_queue: bool = false) -> AbilityValidationResult:
	if ability == null:
		return AbilityValidationResult.rejected(&"ability_missing", AbilityConstants.CANCEL_INVALID)
	if is_animation_locked() and not _can_queue_now(allow_queue, context.sim_tick):
		return AbilityValidationResult.rejected(&"animation_locked", AbilityConstants.CANCEL_INVALID)
	if state.is_casting():
		if not _can_queue_now(allow_queue, context.sim_tick):
			return AbilityValidationResult.rejected(&"already_casting", AbilityConstants.CANCEL_INVALID)
	if ability.uses_gcd and is_on_gcd():
		if not _can_queue_now(allow_queue, context.sim_tick):
			return AbilityValidationResult.rejected(&"gcd_active", AbilityConstants.CANCEL_INVALID)
	if not cooldowns.is_ready(ability.get_ability_id(), StringName(ability.cooldown_group)):
		return AbilityValidationResult.rejected(&"cooldown_active", AbilityConstants.CANCEL_INVALID)
	if not has_resources_for(ability):
		return AbilityValidationResult.rejected(&"insufficient_resources", AbilityConstants.CANCEL_INSUFFICIENT_RESOURCES)
	if not is_target_legal(ability, target, context):
		return AbilityValidationResult.rejected(&"invalid_target", AbilityConstants.CANCEL_INVALID)
	return AbilityValidationResult.accepted()


func resolve_targets(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> Array[Node]:
	if entity == null or target == null:
		return _empty_targets()
	if ability != null and ability.target_type == AbilityResource.TargetType.SELF:
		return _single_target(entity)
	if ability != null and ability.aoe_shape != AbilityResource.AoeShape.NONE:
		return _resolve_aoe_targets(ability, target, context)

	match target.kind:
		AbilityTargetSpec.Kind.ENTITY:
			return _single_target(_get_entity_by_id(target.entity_id, context))
		AbilityTargetSpec.Kind.GROUND:
			return _resolve_ground_targets(ability, target.ground_position, context)
		_:
			return _empty_targets()


func is_in_range(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> bool:
	if entity == null or ability == null:
		return false
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return _get_entity_position(entity).distance_to(target.ground_position) <= ability.range
	var target_entities := resolve_targets(ability, target, context)
	if target_entities.is_empty():
		return ability.target_type == AbilityResource.TargetType.GROUND
	for target_entity in target_entities:
		if not _is_valid_target(target_entity, ability, context):
			return false
		if ability.range <= 0.0:
			continue
		if _get_entity_position(entity).distance_to(_get_entity_position(target_entity)) > ability.range:
			return false
	return true


func is_target_legal(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> bool:
	if ability == null or context == null:
		return false
	if not is_in_range(ability, target, context):
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


func can_movement_cancel_current_cast() -> bool:
	return state.is_casting() and not state.cast_locked


func is_on_gcd() -> bool:
	return state.gcd_remaining > 0.0


func is_animation_locked() -> bool:
	return state.anim_lock_remaining > 0.0


func get_gcd_remaining() -> float:
	return state.gcd_remaining


func get_cooldown_remaining(ability_id: int) -> float:
	return cooldowns.get_ability_remaining(ability_id)


func get_recent_request_impact_tick(request_id: int) -> int:
	if request_id <= 0 or not _recent_completed_requests.has(request_id):
		return 0
	var completed := _recent_completed_requests[request_id] as Dictionary
	return int(completed.get("impact_tick", 0))


func cancel_casting(reason: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if not state.is_casting():
		return []

	var source_entity_id := state.cast_source_entity_id
	var ability_id := state.cast_ability_id
	var events: Array[EntityEvents] = [
		EntityEvents.ability_canceled(source_entity_id, ability_id, reason, state.cast_request_id)
	]

	_log_ability("Cancel cast", context.sim_tick if context != null else 0, ability_id, source_entity_id, {
		"request": state.cast_request_id,
		"reason": reason,
		"locked": state.cast_locked,
		"lock": state.cast_lock_tick,
		"finish": state.cast_finish_tick,
	})
	if _active_scheduled_use != null:
		_active_scheduled_use.canceled = true
		_active_scheduled_use = null
	state.gcd_remaining = 0.0
	state.anim_lock_remaining = 0.0
	state.clear_cast()
	state.clear_queued()
	return events


func confirm_request(
		request_id: int,
		start_tick: int,
		resolve_tick: int,
		finish_tick: int,
		impact_tick: int) -> void:
	if request_id <= 0 or start_tick <= 0:
		return
	if state.cast_request_id != request_id:
		return
	state.cast_start_tick = start_tick
	state.cast_resolve_tick = resolve_tick
	state.cast_finish_tick = finish_tick
	state.cast_impact_tick = impact_tick
	if _active_scheduled_use != null and _active_scheduled_use.request_id == request_id:
		_active_scheduled_use.start_tick = start_tick
		_active_scheduled_use.resolve_tick = resolve_tick
		_active_scheduled_use.finish_tick = finish_tick
		_active_scheduled_use.impact_tick = impact_tick


func reject_request(request_id: int, cancel_reason: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if request_id <= 0:
		return []
	if state.cast_request_id == request_id:
		return cancel_casting(cancel_reason, context)
	if state.queued_request_id == request_id:
		var queued_ability_id := state.queued_ability_id
		state.clear_queued()
		if queued_ability_id > 0:
			return [EntityEvents.ability_canceled(_get_source_entity_id(context), queued_ability_id, cancel_reason, request_id)]
		return []
	if _recent_completed_requests.has(request_id):
		var completed := _recent_completed_requests[request_id] as Dictionary
		var ability_id := int(completed.get("ability_id", 0))
		var cooldown_group := StringName(completed.get("cooldown_group", &""))
		state.gcd_remaining = 0.0
		state.anim_lock_remaining = 0.0
		cooldowns.cancel(ability_id, cooldown_group)
		_recent_completed_requests.erase(request_id)
		if ability_id > 0:
			return [EntityEvents.ability_canceled(_get_source_entity_id(context), ability_id, cancel_reason, request_id)]
	return []


func clear_queued_ability() -> void:
	state.clear_queued()


func consume_scheduled_uses() -> Array:
	var uses := _scheduled_uses.duplicate()
	_scheduled_uses.clear()
	return uses


func _start_cast(
		sim_tick: int,
		request_id: int,
		ability_id: int,
		target: AbilityTargetSpec,
		requested_tick: int,
		ability: AbilityResource) -> Array[EntityEvents]:
	if ability == null:
		return []

	var source_entity_id := _get_source_entity_id()
	state.cast_source_entity_id = source_entity_id
	state.cast_request_id = request_id
	state.cast_ability_id = ability_id
	state.cast_target = target
	state.cast_total = ability.cast_time
	state.cast_total_ticks = _seconds_to_ticks(ability.cast_time)
	state.cast_requested_tick = requested_tick
	state.cast_start_tick = sim_tick
	state.cast_finish_tick = sim_tick + state.cast_total_ticks
	state.cast_lock_tick = _compute_lock_tick(ability, state.cast_start_tick, state.cast_finish_tick)
	state.cast_resolve_tick = _compute_resolve_tick(ability, state.cast_start_tick, state.cast_finish_tick)
	state.cast_impact_tick = state.cast_finish_tick + _seconds_to_ticks(AbilityConstants.IMPACT_DELAY_DURATION)
	state.cast_locked = state.cast_lock_tick <= state.cast_start_tick
	_active_scheduled_use = ScheduledAbilityUse.create(
			source_entity_id,
			ability_id,
			target,
			requested_tick,
			state.cast_start_tick,
			state.cast_lock_tick,
			state.cast_resolve_tick,
			state.cast_finish_tick,
			state.cast_impact_tick,
			request_id)
	_scheduled_uses.append(_active_scheduled_use)

	_apply_gcd(ability)
	state.anim_lock_remaining = AbilityConstants.ANIMATION_LOCK_DURATION
	_apply_internal_cooldown_if_needed(ability)
	_log_ability("Start casting", sim_tick, ability_id, source_entity_id, {
		"request": request_id,
		"requested": requested_tick,
		"start": state.cast_start_tick,
		"lock": state.cast_lock_tick,
		"start_locked": state.cast_locked,
		"resolve": state.cast_resolve_tick,
		"finish": state.cast_finish_tick,
		"impact": state.cast_impact_tick,
	})

	return [
		EntityEvents.ability_started(
				source_entity_id,
				ability_id,
				request_id,
				_event_target_entity_id(target),
				_event_ground_position(target),
				ability.cast_time)
	]


func _complete_cast(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if not state.is_casting():
		return []

	var source_entity_id := state.cast_source_entity_id
	var request_id := state.cast_request_id
	var ability_id := state.cast_ability_id
	var _target := state.cast_target
	var requested_tick := state.cast_requested_tick
	var start_tick := state.cast_start_tick
	var lock_tick := state.cast_lock_tick
	var resolve_tick := state.cast_resolve_tick
	var finish_tick := state.cast_finish_tick
	var impact_tick := state.cast_impact_tick
	var ability := _get_cast_ability(ability_id, context)
	if ability == null or not has_resources_for(ability):
		var cancel_reason := AbilityConstants.CANCEL_INVALID
		if ability != null and not has_resources_for(ability):
			cancel_reason = AbilityConstants.CANCEL_INSUFFICIENT_RESOURCES
		if _active_scheduled_use != null:
			_active_scheduled_use.canceled = true
			_active_scheduled_use = null
		state.clear_cast()
		return [
			EntityEvents.ability_canceled(source_entity_id, ability_id, cancel_reason, request_id)
		]

	spend_resources_for(ability)
	_apply_cooldown(ability)
	_recent_completed_requests[request_id] = {
		"ability_id": ability_id,
		"cooldown_group": StringName(ability.cooldown_group),
		"impact_tick": impact_tick,
	}
	_log_ability("Complete ability", sim_tick, ability_id, source_entity_id, {
		"request": request_id,
		"requested": requested_tick,
		"start": start_tick,
		"lock": lock_tick,
		"resolve": resolve_tick,
		"finish": finish_tick,
		"impact": impact_tick,
	})
	var events: Array[EntityEvents] = [
		EntityEvents.ability_finished(source_entity_id, ability_id, request_id)
	]
	_active_scheduled_use = null
	state.clear_cast()
	return events


func _get_cast_ability(ability_id: int, context: AbilityExecutionContext) -> AbilityResource:
	if context == null:
		return null
	return AbilityDB.get_ability(ability_id)


func _queue_ability(
		ability_id: int,
		target: AbilityTargetSpec,
		requested_tick: int,
		request_id: int) -> void:
	state.queued_source_entity_id = _get_source_entity_id()
	state.queued_request_id = request_id
	state.queued_ability_id = ability_id
	state.queued_target = target
	state.queued_requested_tick = requested_tick


func _try_dequeue_ability(sim_tick: int, context: AbilityExecutionContext) -> Array[EntityEvents]:
	if not state.has_queued() or context == null:
		return []
	if state.is_casting() or is_animation_locked():
		return []

	var ability_id := state.queued_ability_id
	var target := state.queued_target
	var ability := AbilityDB.get_ability(ability_id)
	if ability != null and ability.uses_gcd and is_on_gcd():
		return []

	var validation := can_use_ability(ability, target, context, false)
	var source_entity_id := state.queued_source_entity_id
	var request_id := state.queued_request_id
	var requested_tick := state.queued_requested_tick
	state.clear_queued()
	if not validation.ok:
		_log_ability("Reject queued ability", sim_tick, ability_id, source_entity_id, {
			"request": request_id,
			"requested": requested_tick,
			"reason": validation.reason,
			"cancel_reason": validation.cancel_reason,
		})
		return [
			EntityEvents.ability_canceled(
					source_entity_id,
					ability_id,
					validation.cancel_reason,
					request_id)
		]

	var events := _start_cast(sim_tick, request_id, ability_id, target, requested_tick, ability)
	if ability.cast_time <= 0.0:
		events.append_array(_complete_cast(sim_tick, context))
	return events


func _should_queue_ability(sim_tick: int) -> bool:
	return _can_queue_now(true, sim_tick)


func _can_queue_now(allow_queue: bool, sim_tick: int) -> bool:
	if not allow_queue:
		return false
	if state.is_casting():
		return _in_cast_queue_window(sim_tick)
	if is_on_gcd():
		return _in_gcd_queue_window()
	return false


func _in_cast_queue_window(sim_tick: int) -> bool:
	if state.cast_total_ticks <= 0:
		return false
	var remaining_ticks := maxi(0, state.cast_finish_tick - sim_tick)
	return remaining_ticks <= int(ceil(float(state.cast_total_ticks) * AbilityConstants.ABILITY_QUEUE_WINDOW))


func _in_gcd_queue_window() -> bool:
	return state.gcd_remaining <= AbilityConstants.GCD_DURATION * AbilityConstants.ABILITY_QUEUE_WINDOW


func _apply_gcd(ability: AbilityResource) -> void:
	if ability != null and ability.uses_gcd:
		state.gcd_remaining = AbilityConstants.GCD_DURATION


func _apply_cooldown(ability: AbilityResource) -> void:
	if ability == null:
		return
	cooldowns.start(ability.get_ability_id(), ability.cooldown, StringName(ability.cooldown_group))


func _apply_internal_cooldown_if_needed(ability: AbilityResource) -> void:
	if ability == null or ability.cast_time > 0.0:
		return
	cooldowns.start(
			ability.get_ability_id(),
			AbilityConstants.INTERNAL_COOLDOWN_DURATION,
			StringName(ability.cooldown_group))


func _get_source_entity_id(context: AbilityExecutionContext = null) -> int:
	if context != null and context.source_entity_id > 0:
		return context.source_entity_id
	if entity != null and "id" in entity:
		return int(entity.id)
	return 0


func _get_entity_by_id(entity_id: int, context: AbilityExecutionContext) -> Node:
	if entity_id <= 0 or context == null or context.target_resolver == null:
		return null
	if context.target_resolver.has_method("get_entity_by_id"):
		return context.target_resolver.get_entity_by_id(entity_id)
	return null


func _get_all_entities(context: AbilityExecutionContext) -> Array[Node]:
	var entities: Array[Node] = []
	if context == null or context.target_resolver == null or not context.target_resolver.has_method("get_all_entities"):
		return entities
	var resolved = context.target_resolver.get_all_entities()
	if resolved is Array:
		for candidate in resolved:
			if candidate is Node:
				entities.append(candidate)
	return entities


func _resolve_aoe_targets(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> Array[Node]:
	match ability.aoe_shape:
		AbilityResource.AoeShape.CIRCLE:
			return _resolve_circle_targets(ability, _get_aoe_center(target, context), context)
		AbilityResource.AoeShape.CONE:
			return _resolve_cone_targets(ability, target, context)
		_:
			return _empty_targets()


func _resolve_ground_targets(
		ability: AbilityResource,
		ground_position: Vector3,
		context: AbilityExecutionContext) -> Array[Node]:
	if ability == null or ability.aoe_shape == AbilityResource.AoeShape.NONE:
		return _empty_targets()
	return _resolve_aoe_targets(ability, AbilityTargetSpec.ground(ground_position), context)


func _resolve_circle_targets(
		ability: AbilityResource,
		center: Vector3,
		context: AbilityExecutionContext) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var targets: Array[Node] = []
	for candidate in _get_valid_targets_for(ability, context):
		if _get_entity_position(candidate).distance_to(center) <= radius:
			targets.append(candidate)
	return targets


func _resolve_cone_targets(
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var source_position := _get_entity_position(entity)
	var forward := _get_cone_forward(target)
	if forward == Vector3.ZERO:
		return _empty_targets()

	var targets: Array[Node] = []
	for candidate in _get_valid_targets_for(ability, context):
		var offset := _get_entity_position(candidate) - source_position
		offset.y = 0.0
		if offset == Vector3.ZERO or offset.length() > radius:
			continue
		if forward.angle_to(offset.normalized()) <= PI * 0.25:
			targets.append(candidate)
	return targets


func _get_aoe_center(target: AbilityTargetSpec, context: AbilityExecutionContext) -> Vector3:
	if target == null:
		return _get_entity_position(entity)
	match target.kind:
		AbilityTargetSpec.Kind.GROUND:
			return target.ground_position
		AbilityTargetSpec.Kind.ENTITY:
			return _get_entity_position(_get_entity_by_id(target.entity_id, context))
		_:
			return _get_entity_position(entity)


func _get_cone_forward(target: AbilityTargetSpec) -> Vector3:
	var source_position := _get_entity_position(entity)
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		var toward_ground := target.ground_position - source_position
		toward_ground.y = 0.0
		return toward_ground.normalized() if toward_ground != Vector3.ZERO else Vector3.ZERO
	if entity is Entity:
		var angle := (entity as Entity).face_angle
		return Vector3(-sin(angle), 0.0, -cos(angle)).normalized()
	return Vector3.ZERO


func _get_aoe_radius(ability: AbilityResource) -> float:
	if ability == null:
		return 0.0
	if ability.aoe_radius > 0.0:
		return ability.aoe_radius
	return ability.range


func _get_valid_targets_for(ability: AbilityResource, context: AbilityExecutionContext) -> Array[Node]:
	var targets: Array[Node] = []
	for candidate in _get_all_entities(context):
		if _is_valid_target(candidate, ability, context):
			targets.append(candidate)
	return targets


func _is_valid_target(target_entity: Node, ability: AbilityResource, context: AbilityExecutionContext) -> bool:
	if entity == null or target_entity == null or ability == null:
		return false
	if ability.target_type == AbilityResource.TargetType.SELF:
		return entity == target_entity
	if _is_combat_target_type(ability.target_type):
		return _is_valid_combat_target(target_entity, ability, context)
	return true


func _is_valid_combat_target(
		target_entity: Node,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> bool:
	if target_entity == null or ability == null:
		return false
	var target_mob := _get_mob_for(target_entity)
	if target_mob == null or not target_mob.is_alive():
		return false
	match ability.target_type:
		AbilityResource.TargetType.SELF:
			return entity == target_entity
		AbilityResource.TargetType.OTHER_ENEMY:
			return mob != null and mob.is_hostile_to(target_entity)
		AbilityResource.TargetType.OTHER_FRIEND:
			return mob == null or mob.is_friendly_to(target_entity)
		AbilityResource.TargetType.OTHER_ANY:
			return entity != target_entity
		_:
			return true


func _get_mob_for(target_entity: Node) -> Mob:
	if target_entity == null:
		return null
	if target_entity.has_node("%Mob"):
		return target_entity.get_node("%Mob") as Mob
	return null


func _get_entity_position(target_entity: Node) -> Vector3:
	if target_entity == null:
		return Vector3.ZERO
	if target_entity is Entity:
		return (target_entity as Entity).get_position()
	if target_entity is Node3D:
		return target_entity.global_position
	return Vector3.ZERO


func _single_target(target_entity: Node) -> Array[Node]:
	var targets: Array[Node] = []
	if target_entity != null:
		targets.append(target_entity)
	return targets


func _empty_targets() -> Array[Node]:
	var targets: Array[Node] = []
	return targets


func _is_combat_target_type(target_type: int) -> bool:
	return target_type == AbilityResource.TargetType.OTHER_ENEMY or \
			target_type == AbilityResource.TargetType.OTHER_FRIEND or \
			target_type == AbilityResource.TargetType.OTHER_ANY


func _seconds_to_ticks(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return int(ceil(seconds * float(Globals.TICK_RATE)))


func _compute_resolve_tick(ability: AbilityResource, start_tick: int, finish_tick: int) -> int:
	if ability == null:
		return start_tick
	return maxi(start_tick, finish_tick - maxi(0, ability.resolve_lead_ticks))


func _compute_lock_tick(ability: AbilityResource, start_tick: int, finish_tick: int) -> int:
	if ability == null or ability.cast_lock_time <= 0.0:
		return start_tick
	return mini(finish_tick, start_tick + _seconds_to_ticks(ability.cast_lock_time))


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


func _log_ability(
		label: String,
		tick: int,
		ability_id: int,
		entity_id: int,
		details: Dictionary = {}) -> void:
	var source_tag := "[ABILITY_LOCAL]"
	if multiplayer != null and multiplayer.multiplayer_peer != null and multiplayer.is_server():
		source_tag = "[ABILITY_SERVER]"
	var message := "%s %s %s %s entity=%d ability=%s" % [
		_format_tick_prefix(tick),
		_get_log_prefix(),
		source_tag,
		label,
		entity_id,
		ability_id]
	for key in details:
		message += " %s=%s" % [key, str(details[key])]
	print(message)


func _get_log_prefix() -> String:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		if multiplayer.is_server():
			return "[SERVER]"
		return "[PLAYER %d]" % multiplayer.get_unique_id()
	return "[SERVER]"


func _format_tick_prefix(tick: int) -> String:
	return "[TICK %d | (%s)]" % [tick, _timestamp()]


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
