class_name LocalAbilityPrediction
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _owner: Node = null
var _predicted_request_id: int = 0
var _predicted_ability_id: int = 0
var _predicted_requested_tick: int = -1
var _predicted_target_entity_id: int = 0
var _predicted_start_tick: int = 0
var _predicted_resolve_tick: int = 0
var _predicted_finish_tick: int = 0
var _predicted_impact_tick: int = 0
var _prediction_confirmed := false
var _ability_db: AbilityDatabase = AbilityDatabase.new()


func _ready() -> void:
	_owner = get_parent()
	_ability_db.load_all()


func predict_ability_started(
		request_id: int,
		ability_id: int,
		target_entity_id: int,
		requested_tick: int) -> void:
	if ability_id <= 0:
		return
	_predicted_request_id = request_id
	_predicted_ability_id = ability_id
	_predicted_requested_tick = requested_tick
	_predicted_target_entity_id = target_entity_id
	_predicted_start_tick = requested_tick
	_predicted_resolve_tick = 0
	_predicted_finish_tick = 0
	_predicted_impact_tick = 0
	_prediction_confirmed = false
	_log_ability("Start casting (local)", requested_tick, ability_id, {
		"request": request_id,
		"requested": requested_tick,
		"predicted_start": requested_tick,
	})


func confirm_ability_started(ack: Proto.AbilityUseAccepted) -> void:
	if ack == null or not _matches_prediction(ack.get_request_id()):
		return
	_predicted_start_tick = ack.get_start_tick()
	_predicted_resolve_tick = ack.get_resolve_tick()
	_predicted_finish_tick = ack.get_finish_tick()
	_predicted_impact_tick = ack.get_impact_tick()
	_prediction_confirmed = true
	_log_ability("Ability ACK accepted (local)", _predicted_start_tick, _predicted_ability_id, {
		"request": _predicted_request_id,
		"requested": _predicted_requested_tick,
		"start": _predicted_start_tick,
		"resolve": _predicted_resolve_tick,
		"finish": _predicted_finish_tick,
		"impact": _predicted_impact_tick,
	})


func reject_ability_started(rejection: Proto.AbilityUseRejected) -> void:
	if rejection == null or not _matches_prediction(rejection.get_request_id()):
		return
	_log_ability("Ability ACK rejected (local)", _predicted_start_tick, _predicted_ability_id, {
		"request": rejection.get_request_id(),
		"reason": rejection.get_cancel_reason(),
	})
	_clear_prediction()


func on_authoritative_ability_completed(event, event_tick: int) -> void:
	var ability_id: int = event.get_ability_id()
	if not _matches_active_prediction(ability_id):
		return
	_log_ability("Complete ability (local)", event_tick, ability_id, {
		"request": _predicted_request_id,
		"requested": _predicted_requested_tick,
		"start": _predicted_start_tick,
		"resolve": _predicted_resolve_tick,
		"finish": _predicted_finish_tick,
		"impact": _predicted_impact_tick,
	})
	_clear_prediction()


func on_authoritative_ability_canceled(event, _event_tick: int) -> void:
	var ability_id: int = event.get_ability_id()
	if _matches_active_prediction(ability_id):
		_clear_prediction()


func on_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	if resolved == null:
		return
	_log_ability("Ability resolved (local)", resolved.get_resolve_tick(), resolved.get_ability_id(), {
		"request": resolved.get_request_id(),
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


func get_predicted_ability_id_for_request(request_id: int) -> int:
	if _matches_prediction(request_id):
		return _predicted_ability_id
	return 0


func has_active_prediction_for_ability(ability_id: int) -> bool:
	return _matches_active_prediction(ability_id)


func _matches_prediction(request_id: int) -> bool:
	return request_id > 0 and _predicted_request_id == request_id


func _matches_active_prediction(ability_id: int) -> bool:
	return _predicted_ability_id == ability_id and _predicted_ability_id > 0


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
	var ability_name := _ability_db.get_ability_name(ability_id)
	var message := "[ABILITY] %s tick=%d time=%s client=%d entity=%d ability_id=%d ability_name=%s" % [
		label,
		tick,
		_timestamp(),
		_get_client_id(),
		_get_owner_entity_id(),
		ability_id,
		ability_name
	]
	for key in details:
		message += " %s=%s" % [key, str(details[key])]
	print(message)


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]


func _clear_prediction() -> void:
	_predicted_request_id = 0
	_predicted_ability_id = 0
	_predicted_requested_tick = -1
	_predicted_target_entity_id = 0
	_predicted_start_tick = 0
	_predicted_resolve_tick = 0
	_predicted_finish_tick = 0
	_predicted_impact_tick = 0
	_prediction_confirmed = false
