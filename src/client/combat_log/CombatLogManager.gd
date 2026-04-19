class_name CombatLogManager
extends Node

signal entry_created(entry)

@export var max_entries: int = 200
@export var console_output_enabled: bool = true

@onready var _game_manager = %GameManager

var _entries: Array = []
var _sinks: Array[RefCounted] = []
var _ability_db: AbilityDatabase = AbilityDatabase.new()
var _enabled: bool = true


func _ready() -> void:
	_ability_db.load_all()
	if console_output_enabled:
		add_sink(CombatLogConsoleSink.new())
	if _game_manager != null:
		_connect_game_manager(_game_manager)


func add_sink(sink: RefCounted) -> void:
	if sink == null or _sinks.has(sink):
		return
	_sinks.append(sink)


func remove_sink(sink: RefCounted) -> void:
	_sinks.erase(sink)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func get_recent_entries(limit: int = 50) -> Array:
	if limit <= 0 or _entries.is_empty():
		return []
	var start := maxi(0, _entries.size() - limit)
	return _entries.slice(start, _entries.size())


func _connect_game_manager(game_manager) -> void:
	game_manager.entity_event_received.connect(_on_entity_event_received)
	game_manager.ability_use_rejected.connect(_on_ability_use_rejected)


func _on_entity_event_received(event) -> void:
	if not _enabled or event == null:
		return
	var entry: CombatLogEntry = _entry_from_world_state_event(event)
	_publish_entry(entry)


func _on_ability_use_rejected(rejection) -> void:
	if not _enabled or rejection == null:
		return
	var ability_id: int = rejection.get_ability_id()
	var entry: CombatLogEntry = _new_entry(
		rejection.get_requested_tick(),
		&"cast",
		"%s failed: %s." % [
			_ability_name(ability_id),
			_cancel_reason_text(rejection.get_reason()),
		],
		&"warning")
	entry.source_entity_id = _game_manager.get_local_player_id() if _game_manager != null else 0
	entry.ability_id = ability_id
	entry.raw_event = rejection
	_publish_entry(entry)


func _entry_from_world_state_event(event) -> CombatLogEntry:
	var tick: int = event.get_tick()
	var primary_entity_id: int = _event_entity_id(event)
	var entity_ids: Array = _event_entity_ids(event)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var primary_is_local: bool = _is_local_id(primary_entity_id)
	var primary_name: String = _entity_name(entity_names, primary_entity_id, primary_is_local)
	if event.has_ability_use_started():
		var payload = event.get_ability_use_started()
		var ability_name := _ability_name(payload.get_ability_id())
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"cast",
			"%s %s casting %s." % [
				primary_name,
				_verb_for_subject(primary_is_local, "start", "starts"),
				ability_name,
			])
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_target_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.raw_event = payload
		return entry
	if event.has_ability_use_canceled():
		var payload = event.get_ability_use_canceled()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"cast",
			"%s %s casting %s: %s." % [
				primary_name,
				_verb_for_subject(primary_is_local, "stop", "stops"),
				_ability_name(payload.get_ability_id()),
				_cancel_reason_text(payload.get_cancel_reason()),
			],
			&"warning")
		entry.source_entity_id = payload.get_source_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.raw_event = payload
		return entry
	if event.has_ability_use_completed():
		return null
	if event.has_damage_taken():
		var payload = event.get_damage_taken()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"damage",
			"%s %s %s for %d." % [
				_possessive_entity_name(primary_name, primary_is_local),
				_ability_name_for_effect(payload.get_ability_id()),
				_verb_for_target_hit(_entity_object_name(entity_names, payload.get_target_entity_id())),
				int(round(payload.get_amount())),
			],
			&"important")
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_target_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.amount = int(round(payload.get_amount()))
		entry.raw_event = payload
		return entry
	if event.has_healing_received():
		var payload = event.get_healing_received()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"healing",
			"%s %s %s for %d." % [
				_possessive_entity_name(primary_name, primary_is_local),
				_ability_name_for_effect(payload.get_ability_id()),
				_verb_for_target_heal(_entity_object_name(entity_names, payload.get_target_entity_id())),
				int(round(payload.get_amount())),
			])
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_target_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.amount = int(round(payload.get_amount()))
		entry.raw_event = payload
		return entry
	if event.has_buff_applied():
		var payload = event.get_buff_applied()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"buff",
			"%s %s %s from %s." % [
				primary_name,
				_verb_for_subject(primary_is_local, "gain", "gains"),
				_status_name(payload.get_status_id()),
				_ability_name(payload.get_ability_id()),
			])
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_target_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.status_id = payload.get_status_id()
		entry.raw_event = payload
		return entry
	if event.has_debuff_applied():
		var payload = event.get_debuff_applied()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"debuff",
			"%s %s %s from %s." % [
				primary_name,
				_verb_for_subject(primary_is_local, "suffer", "suffers"),
				_status_name(payload.get_status_id()),
				_ability_name(payload.get_ability_id()),
			],
			&"warning")
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_target_entity_id()
		entry.ability_id = payload.get_ability_id()
		entry.status_id = payload.get_status_id()
		entry.raw_event = payload
		return entry
	if event.has_status_effect_removed():
		var payload = event.get_status_effect_removed()
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"status",
			"%s %s %s." % [
				primary_name,
				_verb_for_subject(primary_is_local, "lose", "loses"),
				_status_name(payload.get_status_id()),
			])
		entry.target_entity_id = payload.get_entity_id()
		entry.status_id = payload.get_status_id()
		entry.raw_event = payload
		return entry
	if event.has_combat_started():
		var payload = event.get_combat_started()
		var entry: CombatLogEntry = _new_entry(tick, &"combat", "%s enters combat." % primary_name)
		entry.source_entity_id = payload.get_source_entity_id()
		entry.target_entity_id = payload.get_entity_id()
		entry.raw_event = payload
		return entry
	if event.has_combat_ended():
		var payload = event.get_combat_ended()
		var entry: CombatLogEntry = _new_entry(tick, &"combat", "%s leaves combat." % primary_name)
		entry.target_entity_id = payload.get_entity_id()
		entry.raw_event = payload
		return entry
	if event.has_combatant_died():
		var payload = event.get_combatant_died()
		var killer_name := _entity_name(entity_names, payload.get_killer_entity_id(), _is_local_id(payload.get_killer_entity_id())) if payload.get_killer_entity_id() > 0 else "Unknown"
		var entry: CombatLogEntry = _new_entry(
			tick,
			&"death",
			"%s dies. Killer: %s." % [
				primary_name,
				killer_name,
			],
			&"important")
		entry.source_entity_id = payload.get_killer_entity_id()
		entry.target_entity_id = payload.get_entity_id()
		entry.raw_event = payload
		return entry
	return null


func _publish_entry(entry) -> void:
	if entry == null or entry.message == "":
		return
	_entries.append(entry)
	if _entries.size() > max_entries:
		_entries.remove_at(0)
	entry_created.emit(entry)
	for sink in _sinks:
		if sink != null and sink.has_method("write_entry"):
			sink.write_entry(entry)


func _new_entry(
		entry_tick: int,
		entry_category: StringName,
		entry_message: String,
		entry_severity: StringName = &"info") -> CombatLogEntry:
	var entry := CombatLogEntry.new()
	entry.tick = entry_tick
	entry.category = entry_category
	entry.message = entry_message
	entry.severity = entry_severity
	return entry


func _entity_name(entity_names: Dictionary, entity_id: int, is_local: bool) -> String:
	if entity_id <= 0:
		return "Unknown"
	if is_local:
		return "You"
	return str(entity_names.get(entity_id, str(entity_id)))


func _entity_object_name(entity_names: Dictionary, entity_id: int) -> String:
	if _is_local_id(entity_id):
		return "you"
	return _entity_name(entity_names, entity_id, false)


func _possessive_entity_name(entity_name: String, is_local: bool) -> String:
	if is_local:
		return "Your"
	return "%s's" % entity_name


func _verb_for_subject(is_local: bool, local_verb: String, remote_verb: String) -> String:
	if is_local:
		return local_verb
	return remote_verb


func _verb_for_target_hit(target_name: String) -> String:
	return "hits %s" % target_name


func _verb_for_target_heal(target_name: String) -> String:
	return "heals %s" % target_name


func _is_local_id(entity_id: int) -> bool:
	return entity_id > 0 and entity_id == multiplayer.get_unique_id()


func _event_entity_id(event) -> int:
	if event == null:
		return 0
	if event.has_ability_use_started():
		return event.get_ability_use_started().get_source_entity_id()
	if event.has_ability_use_canceled():
		return event.get_ability_use_canceled().get_source_entity_id()
	if event.has_ability_use_completed():
		return event.get_ability_use_completed().get_source_entity_id()
	if event.has_damage_taken():
		return event.get_damage_taken().get_source_entity_id()
	if event.has_healing_received():
		return event.get_healing_received().get_source_entity_id()
	if event.has_buff_applied():
		return event.get_buff_applied().get_target_entity_id()
	if event.has_debuff_applied():
		return event.get_debuff_applied().get_target_entity_id()
	if event.has_status_effect_removed():
		return event.get_status_effect_removed().get_entity_id()
	if event.has_combat_started():
		return event.get_combat_started().get_entity_id()
	if event.has_combat_ended():
		return event.get_combat_ended().get_entity_id()
	if event.has_combatant_died():
		return event.get_combatant_died().get_entity_id()
	return 0


func _event_entity_ids(event) -> Array:
	var ids: Array = []
	if event == null:
		return ids
	if event.has_ability_use_started():
		var payload = event.get_ability_use_started()
		_append_entity_id(ids, payload.get_source_entity_id())
		_append_entity_id(ids, payload.get_target_entity_id())
	elif event.has_ability_use_canceled():
		_append_entity_id(ids, event.get_ability_use_canceled().get_source_entity_id())
	elif event.has_ability_use_completed():
		_append_entity_id(ids, event.get_ability_use_completed().get_source_entity_id())
	elif event.has_damage_taken():
		var payload = event.get_damage_taken()
		_append_entity_id(ids, payload.get_source_entity_id())
		_append_entity_id(ids, payload.get_target_entity_id())
	elif event.has_healing_received():
		var payload = event.get_healing_received()
		_append_entity_id(ids, payload.get_source_entity_id())
		_append_entity_id(ids, payload.get_target_entity_id())
	elif event.has_buff_applied():
		var payload = event.get_buff_applied()
		_append_entity_id(ids, payload.get_source_entity_id())
		_append_entity_id(ids, payload.get_target_entity_id())
	elif event.has_debuff_applied():
		var payload = event.get_debuff_applied()
		_append_entity_id(ids, payload.get_source_entity_id())
		_append_entity_id(ids, payload.get_target_entity_id())
	elif event.has_status_effect_removed():
		_append_entity_id(ids, event.get_status_effect_removed().get_entity_id())
	elif event.has_combat_started():
		var payload = event.get_combat_started()
		_append_entity_id(ids, payload.get_entity_id())
		_append_entity_id(ids, payload.get_source_entity_id())
	elif event.has_combat_ended():
		_append_entity_id(ids, event.get_combat_ended().get_entity_id())
	elif event.has_combatant_died():
		var payload = event.get_combatant_died()
		_append_entity_id(ids, payload.get_entity_id())
		_append_entity_id(ids, payload.get_killer_entity_id())
	return ids


func _append_entity_id(ids: Array, entity_id: int) -> void:
	if entity_id > 0 and not ids.has(entity_id):
		ids.append(entity_id)


func _ability_name(ability_id: int) -> String:
	var ability_name: String = _ability_db.get_ability_name(ability_id)
	if ability_name != "":
		return ability_name
	return "Ability %d" % ability_id


func _ability_name_for_effect(ability_id: int) -> String:
	return _ability_name(ability_id).to_lower()


func _status_name(status_id: int) -> String:
	var status_name: String = _ability_db.get_status_name(status_id)
	if status_name != "":
		return status_name
	return "Status %d" % status_id


func _cancel_reason_text(reason: int) -> String:
	match reason:
		0:
			return "moved"
		1:
			return "interrupted"
		2:
			return "stunned"
		3:
			return "target died"
		4:
			return "invalid target"
		_:
			return "canceled"
