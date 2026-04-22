class_name EventGateway
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

const TRACKED_EVENT_TYPES := [
	GameEvent.Type.ABILITY_USE_STARTED,
	GameEvent.Type.ABILITY_USE_FINISHED,
	GameEvent.Type.ABILITY_USE_IMPACT,
]
const REQUEST_TTL_TICKS := 20 * Globals.TICK_RATE
const SOURCE_SERVER := &"server"
const SOURCE_CLIENT := &"client"

signal event_emitted(event: GameEvent)

var _predicted_requests: Dictionary = {}


func submit_client_game_event(event: GameEvent) -> void:
	if event == null:
		return
	_submit_game_event(event, SOURCE_CLIENT)


func submit_server_game_event(event: GameEvent) -> bool:
	if event == null:
		return false
	return _submit_game_event(event, SOURCE_SERVER)


func submit_server_proto_event(event) -> bool:
	if event == null:
		return false

	var translated := _translate_world_event(event)
	if translated == null:
		return false
	var game_event := _to_game_event(translated, int(event.get_tick()))
	if game_event == null:
		return true

	return _submit_game_event(game_event, SOURCE_SERVER)


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
	if event.has_damage_taken():
		var payload = event.get_damage_taken()
		return EntityEvents.damage_taken(
				payload.get_source_entity_id(),
				payload.get_target_entity_id(),
				payload.get_ability_id(),
				payload.get_amount())
	if event.has_healing_received():
		var payload = event.get_healing_received()
		return EntityEvents.healing_received(
				payload.get_source_entity_id(),
				payload.get_target_entity_id(),
				payload.get_ability_id(),
				payload.get_amount())
	if event.has_buff_applied():
		var payload = event.get_buff_applied()
		return EntityEvents.buff_applied(
				payload.get_source_entity_id(),
				payload.get_target_entity_id(),
				payload.get_ability_id(),
				payload.get_status_id(),
				payload.get_remaining_duration())
	if event.has_debuff_applied():
		var payload = event.get_debuff_applied()
		return EntityEvents.debuff_applied(
				payload.get_source_entity_id(),
				payload.get_target_entity_id(),
				payload.get_ability_id(),
				payload.get_status_id(),
				payload.get_remaining_duration())
	if event.has_status_effect_removed():
		var payload = event.get_status_effect_removed()
		return EntityEvents.status_effect_removed(
				payload.get_entity_id(),
				payload.get_status_id(),
				payload.get_remove_reason())
	if event.has_combat_started():
		var payload = event.get_combat_started()
		return EntityEvents.combat_started(
				payload.get_entity_id(),
				payload.get_source_entity_id())
	if event.has_combat_ended():
		var payload = event.get_combat_ended()
		return EntityEvents.combat_ended(payload.get_entity_id())
	if event.has_combatant_died():
		var payload = event.get_combatant_died()
		return EntityEvents.combatant_died(
				payload.get_entity_id(),
				payload.get_killer_entity_id())
	return null


func _submit_game_event(event: GameEvent, source: StringName) -> bool:
	if event == null:
		return false
	_prune(event.tick)
	if source == SOURCE_CLIENT:
		_track_predicted_request(event)
	elif source == SOURCE_SERVER and _consume_suppression(event):
		return true
	event_emitted.emit(event)
	return true


func _track_predicted_request(event: GameEvent) -> void:
	var request_id := _get_request_id(event)
	if request_id <= 0 or event.type != GameEvent.Type.ABILITY_USE_STARTED:
		return
	_predicted_requests[request_id] = {
		"source_entity_id": _get_source_entity_id(event),
		"ability_id": _get_ability_id(event),
		"event_types": TRACKED_EVENT_TYPES.duplicate(),
		"tick": event.tick,
	}


func _consume_suppression(event: GameEvent) -> bool:
	var request_id := _get_request_id(event)
	if event == null or request_id <= 0:
		return false
	var tracked_value = _predicted_requests.get(request_id, null)
	if not tracked_value is Dictionary:
		return false
	var tracked := tracked_value as Dictionary
	if int(tracked.get("source_entity_id", 0)) != _get_source_entity_id(event):
		return false
	if int(tracked.get("ability_id", 0)) != _get_ability_id(event):
		return false
	var tracked_types = tracked.get("event_types", []) as Array
	if not tracked_types.has(event.type):
		return false
	tracked_types.erase(event.type)
	if tracked_types.is_empty():
		_predicted_requests.erase(request_id)
	else:
		tracked["event_types"] = tracked_types
		_predicted_requests[request_id] = tracked
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
	match event.type:
		EntityEvents.Type.ABILITY_USE_STARTED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.ABILITY_USE_STARTED,
					AbilityUseStartedGameEventData.from_entity_event(event))
		EntityEvents.Type.ABILITY_USE_CANCELED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.ABILITY_USE_CANCELED,
					AbilityUseCanceledGameEventData.from_entity_event(event))
		EntityEvents.Type.ABILITY_USE_FINISHED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.ABILITY_USE_FINISHED,
					AbilityUseSimpleGameEventData.from_entity_event(event))
		EntityEvents.Type.ABILITY_USE_IMPACT:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.ABILITY_USE_IMPACT,
					AbilityUseSimpleGameEventData.from_entity_event(event))
		EntityEvents.Type.DAMAGE_TAKEN:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.DAMAGE_TAKEN,
					DamageTakenGameEventData.from_entity_event(event))
		EntityEvents.Type.HEALING_RECEIVED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.HEALING_RECEIVED,
					HealingReceivedGameEventData.from_entity_event(event))
		EntityEvents.Type.BUFF_APPLIED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.BUFF_APPLIED,
					StatusAppliedGameEventData.from_entity_event(event))
		EntityEvents.Type.DEBUFF_APPLIED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.DEBUFF_APPLIED,
					StatusAppliedGameEventData.from_entity_event(event))
		EntityEvents.Type.STATUS_EFFECT_REMOVED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.STATUS_EFFECT_REMOVED,
					StatusEffectRemovedGameEventData.from_entity_event(event))
		EntityEvents.Type.COMBAT_STARTED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.COMBAT_STARTED,
					CombatEventGameEventData.from_entity_event(event))
		EntityEvents.Type.COMBAT_ENDED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.COMBAT_ENDED,
					CombatEventGameEventData.from_entity_event(event))
		EntityEvents.Type.COMBATANT_DIED:
			return GameEvent.create(
					event_tick,
					GameEvent.Type.COMBATANT_DIED,
					CombatEventGameEventData.from_entity_event(event))
		_:
			return null


func _get_request_id(event: GameEvent) -> int:
	return int(event.data.request_id)


func _get_source_entity_id(event: GameEvent) -> int:
	return int(event.data.source_entity_id)


func _get_ability_id(event: GameEvent) -> int:
	return int(event.data.ability_id)
