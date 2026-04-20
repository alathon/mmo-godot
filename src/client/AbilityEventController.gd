class_name AbilityEventController
extends Node

const Proto = preload("res://src/common/proto/packets.gd")
const LOCAL_REQUEST_TTL_TICKS := 20 * Globals.TICK_RATE

signal ability_started(event, event_tick)
signal ability_finished(event, event_tick)
signal ability_impact(event, event_tick)
signal ability_canceled(event, event_tick)
signal ability_resolved(resolved)

var _owner: Node = null
var _local_requests: Dictionary = {}


func _ready() -> void:
	_owner = get_parent()


func add_local_request(request_id: int, entity_id: int, ability_id: int, started_tick: int) -> void:
	if request_id <= 0 or entity_id <= 0 or ability_id <= 0:
		return
	_local_requests[request_id] = {
		"entity_id": entity_id,
		"ability_id": ability_id,
		"tick": started_tick,
	}
	_prune_local_requests(started_tick)
	_log_ability("Track local request", started_tick, ability_id, {
		"request": request_id,
		"tracked_entity": entity_id,
	})


func on_ability_started(event, event_tick: int) -> void:
	_prune_local_requests(event_tick)
	if should_ignore_request_event(event, event_tick, false, true):
		return
	_log_event_emit("Emit ability_started", event, event_tick)
	ability_started.emit(event, event_tick)


func on_ability_finished(event, event_tick: int) -> void:
	_prune_local_requests(event_tick)
	if should_ignore_request_event(event, event_tick, false, true):
		return
	_log_event_emit("Emit ability_finished", event, event_tick)
	ability_finished.emit(event, event_tick)


func on_ability_impact(event, event_tick: int) -> void:
	_prune_local_requests(event_tick)
	if should_ignore_request_event(event, event_tick, true, true):
		return
	_log_event_emit("Emit ability_impact", event, event_tick)
	ability_impact.emit(event, event_tick)
	_mark_request_impact_seen(_event_request_id(event))


func on_ability_canceled(event, event_tick: int) -> void:
	_prune_local_requests(event_tick)
	var request_id := _event_request_id(event)
	if request_id > 0:
		_local_requests.erase(request_id)
	_log_event_emit("Emit ability_canceled", event, event_tick)
	ability_canceled.emit(event, event_tick)


func on_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	if resolved == null:
		return
	_prune_local_requests(resolved.get_resolve_tick())
	var request_id := resolved.get_request_id()
	_log_ability(_get_resolved_label(), resolved.get_resolve_tick(), resolved.get_ability_id(), {
		"request": request_id,
		"start": resolved.get_start_tick(),
		"resolve": resolved.get_resolve_tick(),
		"finish": resolved.get_finish_tick(),
		"impact": resolved.get_impact_tick(),
		"effects": resolved.get_effects().size(),
		"damage_effects": _count_effects(resolved, Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_DAMAGE),
		"damage_amount": _sum_amounts(resolved, Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_DAMAGE),
		"heal_effects": _count_effects(resolved, Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_HEAL),
		"heal_amount": _sum_amounts(resolved, Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_HEAL),
		"status_effects": _count_effects(resolved, Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_STATUS),
	})
	if request_id > 0:
		_mark_request_resolved_seen(request_id)
		_log_ability("Emit ability_resolved", resolved.get_resolve_tick(), resolved.get_ability_id(), {
			"request": request_id,
			"source": _get_owner_entity_id(),
		})
	ability_resolved.emit(resolved)


func _get_resolved_label() -> String:
	return "Received ability_resolved"


func should_ignore_request_event(
		event,
		event_tick: int,
		consume: bool = false,
		log_decision: bool = false) -> bool:
	var request_id := _packet_request_id(event)
	if request_id <= 0:
		return false
	var tracked_value = _local_requests.get(request_id, null)
	var tracked: Dictionary = tracked_value if tracked_value is Dictionary else {}
	if tracked.is_empty():
		return false
	var entity_id := int(tracked.get("entity_id", 0))
	var ability_id := int(tracked.get("ability_id", 0))
	if _event_source_entity_id(event) != entity_id:
		return false
	if _event_ability_id(event) != ability_id:
		return false
	if consume:
		_mark_request_impact_seen(request_id)
	if log_decision:
		_log_ability("Ignore local request event", event_tick, ability_id, {
			"request": request_id,
			"source": entity_id,
		})
	return true


func _prune_local_requests(current_tick: int) -> void:
	if current_tick <= 0 or _local_requests.is_empty():
		return
	var expired: Array = []
	for request_id in _local_requests:
		var tracked := _local_requests[request_id] as Dictionary
		var tracked_tick := int(tracked.get("tick", 0))
		if tracked_tick > 0 and current_tick - tracked_tick > LOCAL_REQUEST_TTL_TICKS:
			expired.append(request_id)
	for request_id in expired:
		_local_requests.erase(request_id)


func _event_request_id(event) -> int:
	if event != null and event.has_method("get_request_id"):
		return int(event.get_request_id())
	if event is EntityEvents:
		return int(event.request_id)
	return 0


func _packet_request_id(event) -> int:
	if event != null and event.has_method("get_request_id"):
		return int(event.get_request_id())
	return 0


func _mark_request_impact_seen(request_id: int) -> void:
	if request_id <= 0:
		return
	var tracked_value = _local_requests.get(request_id, null)
	if not tracked_value is Dictionary:
		return
	var tracked := tracked_value as Dictionary
	tracked["impact_seen"] = true


func _mark_request_resolved_seen(request_id: int) -> void:
	if request_id <= 0:
		return
	var tracked_value = _local_requests.get(request_id, null)
	if not tracked_value is Dictionary:
		return
	var tracked := tracked_value as Dictionary
	tracked["resolved_seen"] = true


func _event_source_entity_id(event) -> int:
	if event != null and event.has_method("get_source_entity_id"):
		return int(event.get_source_entity_id())
	if event is EntityEvents:
		return int(event.source_entity_id)
	return 0


func _event_ability_id(event) -> int:
	if event != null and event.has_method("get_ability_id"):
		return int(event.get_ability_id())
	if event is EntityEvents:
		return int(event.ability_id)
	return 0


func _is_local_owner() -> bool:
	return _owner != null and "is_local" in _owner and bool(_owner.is_local)


func _get_owner_entity_id() -> int:
	if _owner != null and "id" in _owner:
		return int(_owner.id)
	return 0


func _get_client_id() -> int:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		return multiplayer.get_unique_id()
	return 0


func _log_ability(
		label: String,
		tick: int,
		ability_id: int,
		details: Dictionary = {}) -> void:
	var ability_name := AbilityDB.get_ability_name(ability_id)
	var source_tag := _get_source_tag(label)
	var message := "%s %s %s %s client=%d entity=%d ability_id=%d ability_name=%s" % [
		_format_tick_prefix(tick),
		_get_log_prefix(),
		source_tag,
		label,
		_get_client_id(),
		_get_owner_entity_id(),
		ability_id,
		ability_name
	]
	for key in details:
		message += " %s=%s" % [key, str(details[key])]
	print(message)


func _get_log_prefix() -> String:
	return "[PLAYER %d]" % _get_client_id()


func _get_source_tag(label: String) -> String:
	if label.begins_with("Received "):
		return "[PACKET_RX]"
	if label.begins_with("Track ") or label.begins_with("Ignore "):
		return "[ABILITY_LOCAL]"
	if label.begins_with("Emit "):
		return "[ABILITY_EMIT]"
	return "[ABILITY_EVENT]"


func _log_event_emit(label: String, event, event_tick: int) -> void:
	var ability_id := _event_ability_id(event)
	_log_ability(label, event_tick, ability_id, {
		"request": _event_request_id(event),
		"source": _event_source_entity_id(event),
	})


func _format_tick_prefix(tick: int) -> String:
	return "[TICK %d | (%s)]" % [tick, _timestamp()]


func _count_effects(resolved: Proto.AbilityUseResolved, kind: int) -> int:
	var count := 0
	for effect in resolved.get_effects():
		if effect.get_kind() == kind:
			count += 1
	return count


func _sum_amounts(resolved: Proto.AbilityUseResolved, kind: int) -> int:
	var amount := 0
	for effect in resolved.get_effects():
		if effect.get_kind() == kind:
			amount += effect.get_amount()
	return amount


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
