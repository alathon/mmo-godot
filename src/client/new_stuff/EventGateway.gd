class_name EventGateway
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

const TRACKED_EVENT_TYPES := [
	EntityEvents.Type.ABILITY_USE_STARTED,
	EntityEvents.Type.ABILITY_USE_FINISHED,
	EntityEvents.Type.ABILITY_USE_IMPACT,
]
const REQUEST_TTL_TICKS := 20 * Globals.TICK_RATE

signal ability_event_ready(event: EntityEvents, event_tick: int)
signal ability_resolved_ready(resolved: Proto.AbilityUseResolved)
signal event_emitted(event: GameEvent)

var _predicted_requests: Dictionary = {}


func submit_predicted_event(event: EntityEvents, event_tick: int) -> void:
	if event == null:
		return
	_prune(event_tick)
	if event.request_id > 0 and event.type == EntityEvents.Type.ABILITY_USE_STARTED:
		_predicted_requests[event.request_id] = {
			"source_entity_id": event.source_entity_id,
			"ability_id": event.ability_id,
			"event_types": TRACKED_EVENT_TYPES.duplicate(),
			"tick": event_tick,
		}
	var game_event := _to_game_event(event, event_tick)
	if game_event != null:
		event_emitted.emit(game_event)
		return
	ability_event_ready.emit(event, event_tick)


func submit_world_event(event) -> bool:
	if event == null:
		return false
	var event_tick := int(event.get_tick())
	_prune(event_tick)

	var translated := _translate_world_event(event)
	if translated == null:
		return false
	if _consume_suppression(translated):
		return true

	var game_event := _to_game_event(translated, event_tick)
	if game_event != null:
		event_emitted.emit(game_event)
		return true

	ability_event_ready.emit(translated, event_tick)
	return true


func submit_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	if resolved == null:
		return
	ability_resolved_ready.emit(resolved)


func clear_request_tracking(request_id: int) -> void:
	if request_id <= 0:
		return
	_predicted_requests.erase(request_id)


func _translate_world_event(event) -> EntityEvents:
	if event.has_ability_use_started():
		var payload = event.get_ability_use_started()
		return EntityEvents.ability_started(
				payload.get_source_entity_id(),
				payload.get_ability_id(),
				payload.get_request_id(),
				payload.get_target_entity_id(),
				Vector3(payload.get_ground_x(), payload.get_ground_y(), payload.get_ground_z()),
				payload.get_cast_time())
	if event.has_ability_use_canceled():
		var payload = event.get_ability_use_canceled()
		return EntityEvents.ability_canceled(
				payload.get_source_entity_id(),
				payload.get_ability_id(),
				payload.get_cancel_reason(),
				payload.get_request_id())
	if event.has_ability_use_finished():
		var payload = event.get_ability_use_finished()
		return EntityEvents.ability_finished(
				payload.get_source_entity_id(),
				payload.get_ability_id(),
				payload.get_request_id())
	if event.has_ability_use_impact():
		var payload = event.get_ability_use_impact()
		return EntityEvents.ability_impact(
				payload.get_source_entity_id(),
				payload.get_ability_id(),
				payload.get_request_id())
	return null


func _consume_suppression(event: EntityEvents) -> bool:
	if event == null or event.request_id <= 0:
		return false
	var tracked_value = _predicted_requests.get(event.request_id, null)
	if not tracked_value is Dictionary:
		return false
	var tracked := tracked_value as Dictionary
	if int(tracked.get("source_entity_id", 0)) != event.source_entity_id:
		return false
	if int(tracked.get("ability_id", 0)) != event.ability_id:
		return false
	var tracked_types = tracked.get("event_types", []) as Array
	if not tracked_types.has(event.type):
		return false
	tracked_types.erase(event.type)
	if tracked_types.is_empty():
		_predicted_requests.erase(event.request_id)
	else:
		tracked["event_types"] = tracked_types
		_predicted_requests[event.request_id] = tracked
	return true


func _prune(current_tick: int) -> void:
	if current_tick <= 0 or _predicted_requests.is_empty():
		return
	var expired: Array[int] = []
	for request_id in _predicted_requests.keys():
		var tracked := _predicted_requests[request_id] as Dictionary
		var tracked_tick := int(tracked.get("tick", 0))
		if tracked_tick > 0 and current_tick - tracked_tick > REQUEST_TTL_TICKS:
			expired.append(int(request_id))
	for request_id in expired:
		_predicted_requests.erase(request_id)


func _to_game_event(event: EntityEvents, event_tick: int) -> GameEvent:
	if event == null:
		return null
	match event.type:
		EntityEvents.Type.ABILITY_USE_STARTED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.ABILITY_USE_STARTED,
					AbilityUseStartedGameEventData.from_entity_event(event))
		_:
			return null
