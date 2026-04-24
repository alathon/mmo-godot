class_name LocalAbilityController
extends Node

@onready var _ability_manager: AbilityManager = %AbilityManager
@onready var _entity_state: EntityState = %EntityState
@onready var _event_gateway: EventGateway = $/root/Root/Services/EventGateway
@onready var _api: BackendAPI = $/root/Root/Services/BackendAPI

var _pending_requests: Dictionary = {}
var _pending_input_ability_id: int = 0
var _next_request_id: int = 1

@export var correct_cast_timing_on_ack: bool = false

func set_input(ability_id: int) -> void:
	_pending_input_ability_id = ability_id

func try_activate_from_input(ability_id: int, current_tick: int) -> LocalAbilityRequestResult:
	if ability_id <= 0:
		return null

	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		return null
	if ability.target_type == AbilityResource.TargetType.GROUND:
		return null

	return activate_ability(ability_id, _build_target_spec_from_input(ability), current_tick)

func try_activate_from_hotbar(ability_id: int, current_tick: int) -> Dictionary:
	var result := {
		"accepted": false,
		"cooldown": 0.0,
		"request_id": -1
	}

	if ability_id <= 0:
		return result

	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		return result

	result.cooldown = _hotbar_button_cooldown(ability)

	var target := _build_target_spec_from_input(ability)
	var activation_result := activate_ability(ability_id, target, current_tick)
	result.accepted = activation_result.accepted
	result.request_id = activation_result.request_id
	return result

func _hotbar_button_cooldown(ability: AbilityResource) -> float:
	if ability != null and ability.cooldown > 0.0:
		return ability.cooldown
	return 0.0

func activate_ability(
		ability_id: int,
		target: AbilityTargetSpec,
		current_tick: int) -> LocalAbilityRequestResult:
	var result = LocalAbilityRequestResult.new()
	result.request_id = get_next_request_id()
	result.ability_id = ability_id
	result.target = target

	var decision = _ability_manager.evaluate_activation(result.request_id, ability_id, target, current_tick)
	if decision.is_rejected():
		result.reject_reason = decision.reject_reason
		return result

	if not _send_ability_use_request(result, current_tick):
		result.reject_reason = AbilityConstants.CANCEL_INVALID
		return result

	_pending_requests[result.request_id] = {
		"ability_id": ability_id,
		"target": target,
		"requested_tick": current_tick,
	}

	result.accepted = true
	
	if decision.is_started():
		result.game_events = _transitions_to_game_events(
				_ability_manager.start_cast(result.request_id, ability_id, target, current_tick))
	
	_submit_game_events(result.game_events)
	return result

func tick(current_tick: int) -> void:
	_submit_game_events(_tick_transitions(current_tick))

func _send_ability_use_request(result: LocalAbilityRequestResult, current_tick: int) -> bool:
	if result == null or _api == null:
		return false
	return _api.send_ability_use_request(
			result.request_id,
			result.ability_id,
			current_tick,
			result.get_target_entity_id(),
			result.get_ground_position())

func on_queue_ack(request_id: int, earliest_activate_tick: int) -> void:
	var pending = _pending_requests.get(request_id, null)
	if pending == null:
		return

	_ability_manager.queue_request(
			request_id,
			int(pending.get("ability_id", 0)),
			pending.get("target", null),
			earliest_activate_tick)


func on_started_ack(request_id: int, start_tick: int, resolve_tick: int, finish_tick: int, impact_tick: int):
	if has_active_cast_request(request_id) and correct_cast_timing_on_ack:
		_ability_manager.correct_cast_timing(
				request_id,
				start_tick,
				resolve_tick,
				finish_tick,
				impact_tick)
	elif _pending_requests.has(request_id) and start_tick > NetworkTime.tick:
		on_queue_ack(request_id, start_tick)

func on_request_rejected(request_id: int, cancel_reason: int, current_tick: int) -> void:
	if get_request_ability_id(request_id) <= 0:
		return
	_pending_requests.erase(request_id)
	if _ability_manager.has_queued_request(request_id):
		_ability_manager.clear_queued_request(request_id)
	if _ability_manager.has_active_cast_request(request_id):
		_ability_manager.cancel_current_cast(cancel_reason, current_tick)
	_event_gateway.clear_request_tracking(request_id)


func on_cast_canceled(request_id: int, cancel_reason: int, current_tick: int) -> void:
	_pending_requests.erase(request_id)
	if _ability_manager.has_queued_request(request_id):
		_ability_manager.clear_queued_request(request_id)
	if _ability_manager.has_active_cast_request(request_id):
		_ability_manager.cancel_current_cast(cancel_reason, current_tick)


func has_pending_request(request_id: int) -> bool:
	return _pending_requests.has(request_id)


func has_active_cast_request(request_id: int) -> bool:
	return _ability_manager.has_active_cast_request(request_id)


func get_request_ability_id(request_id: int) -> int:
	var pending = _pending_requests.get(request_id, null)
	if pending != null:
		return int(pending.get("ability_id", -1))
	return -1


func clear_request_tracking(request_id: int) -> void:
	_pending_requests.erase(request_id)
	if _ability_manager != null:
		_ability_manager.clear_queued_request(request_id)


func get_next_request_id() -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	return request_id


func _build_target_spec_from_input(ability: AbilityResource) -> AbilityTargetSpec:
	if ability == null:
		return null

	match ability.target_type:
		AbilityResource.TargetType.SELF:
			return null
		AbilityResource.TargetType.GROUND:
			return null
		_:
			if _entity_state == null:
				return null
			var target_id := _entity_state.get_target_id()
			if target_id > 0:
				return AbilityTargetSpec.entity(target_id)
			return null


func _tick_transitions(current_tick: int) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	for transition in _ability_manager.tick(current_tick):
		if transition.type == AbilityTransition.Type.QUEUED_REQUEST_READY:
			events.append_array(_retry_queued_request(transition, current_tick))
			continue
		events.append_array(_transitions_to_game_events([transition]))
	return events


func _submit_game_events(events: Array[GameEvent]) -> void:
	if _event_gateway == null:
		return
	for game_event in events:
		_event_gateway.submit_client_game_event(game_event)


func _retry_queued_request(transition: AbilityTransition, current_tick: int) -> Array[GameEvent]:
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
	for transition in transitions:
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
	if target.kind == AbilityTargetSpec.Kind.ENTITY:
		return target.entity_id
	return -1


func _event_ground_position(target: AbilityTargetSpec) -> Vector3:
	if target.kind == AbilityTargetSpec.Kind.GROUND:
		return target.ground_position
	return Vector3.ZERO
