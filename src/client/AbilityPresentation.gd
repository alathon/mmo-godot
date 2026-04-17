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
	print("[ABILITY_PRESENTATION] client=%d entity=%d predict ability=%s requested_tick=%d target=%d" % [
		_get_client_id(), _get_owner_entity_id(), ability_id, requested_tick, target_entity_id])


func confirm_ability_started(ability_id: StringName, requested_tick: int) -> void:
	if not _matches_prediction(ability_id, requested_tick):
		return
	_prediction_confirmed = true
	print("[ABILITY_PRESENTATION] client=%d entity=%d confirm ability=%s requested_tick=%d" % [
		_get_client_id(), _get_owner_entity_id(), ability_id, requested_tick])


func reject_ability_started(ability_id: StringName, requested_tick: int, reason: int) -> void:
	if not _matches_prediction(ability_id, requested_tick):
		return
	print("[ABILITY_PRESENTATION] client=%d entity=%d reject ability=%s requested_tick=%d reason=%d" % [
		_get_client_id(), _get_owner_entity_id(), ability_id, requested_tick, reason])
	_clear_prediction()


func on_authoritative_ability_started(event) -> void:
	var ability_id := StringName(event.get_ability_id())
	if _has_active_prediction() and _matches_active_prediction(ability_id):
		print("[ABILITY_PRESENTATION] client=%d entity=%d authoritative_start matched_prediction ability=%s" % [
			_get_client_id(), _get_owner_entity_id(), ability_id])
		return
	print("[ABILITY_PRESENTATION] client=%d entity=%d authoritative_start ability=%s source=%d cast_time=%.2f" % [
		_get_client_id(),
		_get_owner_entity_id(),
		ability_id,
		event.get_source_entity_id(),
		event.get_cast_time()])


func on_authoritative_ability_completed(event) -> void:
	var ability_id := StringName(event.get_ability_id())
	print("[ABILITY_PRESENTATION] client=%d entity=%d complete ability=%s source=%d" % [
		_get_client_id(), _get_owner_entity_id(), ability_id, event.get_source_entity_id()])
	if _matches_active_prediction(ability_id):
		_clear_prediction()


func on_authoritative_ability_canceled(event) -> void:
	var ability_id := StringName(event.get_ability_id())
	print("[ABILITY_PRESENTATION] client=%d entity=%d cancel ability=%s source=%d reason=%d" % [
		_get_client_id(),
		_get_owner_entity_id(),
		ability_id,
		event.get_source_entity_id(),
		event.get_cancel_reason()])
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


func _clear_prediction() -> void:
	_predicted_ability_id = &""
	_predicted_requested_tick = -1
	_predicted_target_entity_id = 0
	_prediction_confirmed = false
