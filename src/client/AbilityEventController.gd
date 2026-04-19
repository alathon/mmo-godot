class_name AbilityEventController
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _owner: Node = null
var _ability_db: AbilityDatabase = AbilityDatabase.new()


func _ready() -> void:
	_owner = get_parent()
	_ability_db.load_all()


func on_predicted_ability_started(prediction: Dictionary) -> void:
	if prediction.is_empty():
		return
	var ability_id := int(prediction.get("ability_id", 0))
	if ability_id <= 0:
		return
	_log_ability("Local action: predicted cast start", int(prediction.get("requested_tick", 0)), ability_id, {
		"request": int(prediction.get("request_id", 0)),
		"target": int(prediction.get("target_entity_id", 0)),
		"requested": int(prediction.get("requested_tick", 0)),
		"predicted_start": int(prediction.get("start_tick", 0)),
	})


func on_authoritative_ability_started(event, event_tick: int) -> void:
	pass


func on_authoritative_ability_completed(event, event_tick: int) -> void:
	pass


func on_authoritative_ability_canceled(event, event_tick: int) -> void:
	pass


func on_authoritative_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	if resolved == null:
		return
	_log_ability(_get_resolved_label(), resolved.get_resolve_tick(), resolved.get_ability_id(), {
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


func _get_resolved_label() -> String:
	return "Received Packet.ability_resolved"


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
	var ability_name := _ability_db.get_ability_name(ability_id)
	var message := "%s %s [ABILITY] %s client=%d entity=%d ability_id=%d ability_name=%s" % [
		_format_tick_prefix(tick),
		_get_log_prefix(),
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
