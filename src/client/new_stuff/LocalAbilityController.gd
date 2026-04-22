class_name LocalAbilityController
extends RefCounted

var _ability_manager: AbilityManager = null
var _pending_requests: Dictionary = {}
var _next_request_id: int = 1


func setup(ability_manager: AbilityManager, target_resolver) -> void:
	_ability_manager = ability_manager
	if _ability_manager != null:
		_ability_manager.set_target_resolver(target_resolver)


func activate_ability(
		ability_id: int,
		target: AbilityTargetSpec,
		current_tick: int) -> LocalAbilityRequestResult:
	var result = LocalAbilityRequestResult.new()
	if _ability_manager == null:
		return result

	result.request_id = get_next_request_id()
	result.ability_id = ability_id
	result.target = target

	var decision = _ability_manager.evaluate_activation(result.request_id, ability_id, target, current_tick)
	if decision.is_rejected():
		result.reject_reason = decision.reject_reason
		return result

	_pending_requests[result.request_id] = {
		"ability_id": ability_id,
		"target": target,
	}

	result.accepted = true
	result.should_send_to_server = true
	if decision.is_started():
		result.game_events = _transitions_to_game_events(
				_ability_manager.start_cast(result.request_id, ability_id, target, current_tick))
	return result


func tick(current_tick: int) -> Array[GameEvent]:
	if _ability_manager == null:
		return []

	var events: Array[GameEvent] = []
	for transition in _ability_manager.tick(current_tick):
		if transition == null:
			continue
		if transition.type == AbilityTransition.Type.QUEUED_REQUEST_READY:
			events.append_array(_retry_queued_request(transition, current_tick))
			continue
		events.append_array(_transitions_to_game_events([transition]))
	return events


func on_queue_ack(request_id: int, earliest_activate_tick: int) -> void:
	if _ability_manager == null or request_id <= 0:
		return
	var pending = _pending_requests.get(request_id, null)
	if not pending is Dictionary:
		return
	_ability_manager.queue_request(
			request_id,
			int((pending as Dictionary).get("ability_id", 0)),
			(pending as Dictionary).get("target", null) as AbilityTargetSpec,
			earliest_activate_tick)


func on_started_ack(
		request_id: int,
		start_tick: int,
		resolve_tick: int,
		finish_tick: int,
		impact_tick: int) -> void:
	if _ability_manager == null:
		return
	_ability_manager.correct_cast_timing(request_id, start_tick, resolve_tick, finish_tick, impact_tick)


func on_rejected(request_id: int, cancel_reason: int, current_tick: int) -> Array[GameEvent]:
	if _ability_manager == null or request_id <= 0:
		return []

	_pending_requests.erase(request_id)
	if _ability_manager.has_queued_request(request_id):
		_ability_manager.clear_queued_request(request_id)
		return []
	if _ability_manager.has_active_cast_request(request_id):
		return _transitions_to_game_events(_ability_manager.cancel_current_cast(cancel_reason, current_tick))
	return []


func has_pending_request(request_id: int) -> bool:
	return _pending_requests.has(request_id)


func has_active_cast_request(request_id: int) -> bool:
	return _ability_manager != null and _ability_manager.has_active_cast_request(request_id)


func get_request_ability_id(request_id: int) -> int:
	var pending = _pending_requests.get(request_id, null)
	if pending is Dictionary:
		return int((pending as Dictionary).get("ability_id", 0))
	return 0


func clear_request_tracking(request_id: int) -> void:
	_pending_requests.erase(request_id)
	if _ability_manager != null:
		_ability_manager.clear_queued_request(request_id)


func get_next_request_id() -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	return request_id


func _retry_queued_request(transition: AbilityTransition, current_tick: int) -> Array[GameEvent]:
	if _ability_manager == null or transition == null:
		return []

	var decision = _ability_manager.evaluate_activation(
			transition.request_id,
			transition.ability_id,
			transition.target,
			current_tick)
	match decision.outcome:
		AbilityDecision.Outcome.STARTED:
			_ability_manager.clear_queued_request(transition.request_id)
			return _transitions_to_game_events(
					_ability_manager.start_cast(
							transition.request_id,
							transition.ability_id,
							transition.target,
							current_tick))
		AbilityDecision.Outcome.QUEUED:
			_ability_manager.queue_request(
					transition.request_id,
					transition.ability_id,
					transition.target,
					decision.earliest_activate_tick)
			return []
		_:
			_ability_manager.clear_queued_request(transition.request_id)
			_pending_requests.erase(transition.request_id)
			return []


func _transitions_to_game_events(transitions: Array) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	for transition_value in transitions:
		var transition := transition_value as AbilityTransition
		if transition == null:
			continue
		match transition.type:
			AbilityTransition.Type.CAST_STARTED:
				events.append(GameEvent.create(
						transition.tick,
						GameEvent.Type.ABILITY_USE_STARTED,
						AbilityUseStartedGameEventData.create(
								transition.source_entity_id,
								transition.ability_id,
								transition.request_id,
								_event_target_entity_id(transition.target),
								_event_ground_position(transition.target),
								transition.cast_time)))
			AbilityTransition.Type.CAST_FINISHED:
				_ability_manager.commit_cast_costs(transition.request_id)
				events.append(GameEvent.create(
						transition.tick,
						GameEvent.Type.ABILITY_USE_FINISHED,
						AbilityUseSimpleGameEventData.create(
								transition.source_entity_id,
								transition.ability_id,
								transition.request_id)))
			AbilityTransition.Type.CAST_IMPACT_DUE:
				events.append(GameEvent.create(
						transition.tick,
						GameEvent.Type.ABILITY_USE_IMPACT,
						AbilityUseSimpleGameEventData.create(
								transition.source_entity_id,
								transition.ability_id,
								transition.request_id)))
			AbilityTransition.Type.CAST_CANCELED:
				events.append(GameEvent.create(
						transition.tick,
						GameEvent.Type.ABILITY_USE_CANCELED,
						AbilityUseCanceledGameEventData.create(
								transition.source_entity_id,
								transition.ability_id,
								transition.cancel_reason,
								transition.request_id)))
			_:
				pass
	return events


func _event_target_entity_id(target: AbilityTargetSpec) -> int:
	if target != null and target.kind == AbilityTargetSpec.Kind.ENTITY:
		return target.entity_id
	return 0


func _event_ground_position(target: AbilityTargetSpec) -> Vector3:
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return target.ground_position
	return Vector3.ZERO
