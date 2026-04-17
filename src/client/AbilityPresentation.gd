class_name AbilityPresentation
extends Node

var _owner: Node = null
var _predicted_ability_id: StringName = &""
var _predicted_requested_tick: int = -1
var _predicted_target_entity_id: int = 0
var _prediction_confirmed := false


func _ready() -> void:
	_owner = get_parent()


func predict_ability_started(
		ability_id: StringName,
		target_entity_id: int,
		requested_tick: int) -> void:
	if ability_id == &"":
		return
	_predicted_ability_id = ability_id
	_predicted_requested_tick = requested_tick
	_predicted_target_entity_id = target_entity_id
	_prediction_confirmed = false
	_log_ability("Start casting (local)", requested_tick, ability_id)


func confirm_ability_started(ability_id: StringName, requested_tick: int) -> void:
	if not _matches_prediction(ability_id, requested_tick):
		return
	_prediction_confirmed = true


func reject_ability_started(ability_id: StringName, requested_tick: int, reason: int) -> void:
	if not _matches_prediction(ability_id, requested_tick):
		return
	_clear_prediction()


func on_authoritative_ability_started(event, event_tick: int) -> void:
	var ability_id := StringName(event.get_ability_id())
	if _has_active_prediction() and _matches_active_prediction(ability_id):
		return
	_log_ability("Start casting (remote player)", event_tick, ability_id)


func on_authoritative_ability_completed(event, event_tick: int) -> void:
	var ability_id := StringName(event.get_ability_id())
	var label := "Complete ability (local)" if _matches_active_prediction(ability_id) else "Complete ability (remote player)"
	_log_ability(label, event_tick, ability_id)
	if _matches_active_prediction(ability_id):
		_clear_prediction()


func on_authoritative_ability_canceled(event, _event_tick: int) -> void:
	var ability_id := StringName(event.get_ability_id())
	if _matches_active_prediction(ability_id):
		_clear_prediction()


func _matches_prediction(ability_id: StringName, requested_tick: int) -> bool:
	return _predicted_ability_id == ability_id and _predicted_requested_tick == requested_tick


func _has_active_prediction() -> bool:
	return _predicted_ability_id != &""


func _matches_active_prediction(ability_id: StringName) -> bool:
	return _predicted_ability_id == ability_id


func _get_owner_entity_id() -> int:
	if _owner != null and "id" in _owner:
		return int(_owner.id)
	return 0


func _get_client_id() -> int:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		return multiplayer.get_unique_id()
	return 0


func _log_ability(label: String, tick: int, ability_id: StringName) -> void:
	print("[ABILITY] %s tick=%d time=%s client=%d entity=%d ability=%s" % [
		label,
		tick,
		_timestamp(),
		_get_client_id(),
		_get_owner_entity_id(),
		ability_id])


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]


func _clear_prediction() -> void:
	_predicted_ability_id = &""
	_predicted_requested_tick = -1
	_predicted_target_entity_id = 0
	_prediction_confirmed = false
