class_name CombatLogManager
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

signal entry_created(entry)

@export var max_entries: int = 200
@export var console_output_enabled: bool = true

@onready var _game_manager = %GameManager

var _entries: Array = []
var _sinks: Array[RefCounted] = []
var _enabled: bool = true
var _connected_controllers: Dictionary = {}
var _scheduled_entries: Array[CombatLogEntry] = []


func _ready() -> void:
	if console_output_enabled:
		add_sink(CombatLogConsoleSink.new(self))
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
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
	game_manager.local_player_spawned.connect(_on_entity_spawned)
	game_manager.remote_player_spawned.connect(_on_entity_spawned)
	if game_manager.has_method("get_local_player"):
		var local_player = game_manager.get_local_player()
		if local_player != null:
			_connect_entity_ability_controller(local_player)
	if game_manager.has_method("get_remote_players"):
		for player in game_manager.get_remote_players():
			_connect_entity_ability_controller(player)


func _on_entity_spawned(entity) -> void:
	_connect_entity_ability_controller(entity)


func _connect_entity_ability_controller(entity) -> void:
	if entity == null or not entity.has_method("get_ability_event_controller"):
		return
	var controller = entity.get_ability_event_controller()
	if controller == null or _connected_controllers.has(controller):
		return
	_connected_controllers[controller] = true
	controller.ability_started.connect(_on_ability_started)
	controller.ability_canceled.connect(_on_ability_canceled)
	controller.ability_resolved.connect(_on_ability_resolved)


func _on_before_tick_loop(tick: int) -> void:
	if not _enabled:
		return
	_flush_scheduled_entries(tick)


func _on_entity_event_received(event) -> void:
	if not _enabled or event == null:
		return
	var entry: CombatLogEntry = _entry_from_world_state_event(event)
	_publish_entry(entry)


func _on_ability_use_rejected(rejection) -> void:
	if not _enabled or rejection == null:
		return
	var request_id: int = rejection.get_request_id()
	var ability_id: int = _game_manager.get_local_predicted_ability_id_for_request(request_id) if _game_manager != null else 0
	var ability_text := _ability_name_for_effect(ability_id) if ability_id > 0 else "cast"
	var entry: CombatLogEntry = _new_entry(
		0,
		&"cast",
		"Your %s failed: %s." % [ability_text, _cancel_reason_text(rejection.get_cancel_reason())],
		&"warning")
	entry.source_entity_id = _game_manager.get_local_player_id() if _game_manager != null else 0
	entry.ability_id = ability_id
	entry.message = "%s (request %d)" % [entry.message.trim_suffix("."), request_id]
	entry.raw_event = rejection
	_publish_entry(entry)


func _on_ability_started(event, event_tick: int) -> void:
	if not _enabled or event == null:
		return
	var entry := _entry_from_ability_started(event, event_tick)
	_publish_entry(entry)


func _on_ability_canceled(event, event_tick: int) -> void:
	if not _enabled or event == null:
		return
	var entry := _entry_from_ability_canceled(event, event_tick)
	_publish_entry(entry)


func _on_ability_resolved(resolved) -> void:
	if not _enabled or resolved == null:
		return
	for entry in _entries_from_resolved_effects(
			resolved,
			resolved.get_resolve_tick(),
			Proto.ResolvedAbilityEffectPhase.RESOLVED_EFFECT_EARLY):
		_publish_entry(entry)
	var impact_entries := _entries_from_resolved_effects(
			resolved,
			resolved.get_impact_tick(),
			Proto.ResolvedAbilityEffectPhase.RESOLVED_EFFECT_IMPACT)
	if impact_entries.is_empty():
		return
	var current_tick := int(NetworkTime.tick)
	if resolved.get_impact_tick() <= current_tick:
		for entry in impact_entries:
			_publish_entry(entry)
		return
	for entry in impact_entries:
		_scheduled_entries.append(entry)


func _entry_from_world_state_event(event) -> CombatLogEntry:
	var tick: int = event.get_tick()
	var primary_entity_id: int = _event_entity_id(event)
	var entity_ids: Array = _event_entity_ids(event)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var primary_is_local: bool = _is_local_id(primary_entity_id)
	var primary_name: String = _entity_name(entity_names, primary_entity_id, primary_is_local)
	if event.has_ability_use_started():
		return null
	if event.has_ability_use_canceled():
		return null
	if event.has_ability_use_finished():
		return null
	if event.has_ability_use_impact():
		return null
	if event.has_damage_taken():
		var payload = event.get_damage_taken()
		if _should_ignore_local_outgoing_effect(payload.get_source_entity_id()):
			return null
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
		if _should_ignore_local_outgoing_effect(payload.get_source_entity_id()):
			return null
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
		if _should_ignore_local_outgoing_effect(payload.get_source_entity_id()):
			return null
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
		if _should_ignore_local_outgoing_effect(payload.get_source_entity_id()):
			return null
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


func _entry_from_ability_started(event, event_tick: int) -> CombatLogEntry:
	var source_entity_id := _ability_event_source_entity_id(event)
	var target_entity_id := _ability_event_target_entity_id(event)
	var ability_id := _ability_event_ability_id(event)
	var entity_ids: Array = []
	_append_entity_id(entity_ids, source_entity_id)
	_append_entity_id(entity_ids, target_entity_id)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var source_is_local := _is_local_id(source_entity_id)
	var source_name := _entity_name(entity_names, source_entity_id, source_is_local)
	var entry: CombatLogEntry = _new_entry(
			event_tick,
			&"cast",
			"%s %s casting %s." % [
				source_name,
				_verb_for_subject(source_is_local, "start", "starts"),
				_ability_name(ability_id),
			])
	entry.source_entity_id = source_entity_id
	entry.target_entity_id = target_entity_id
	entry.ability_id = ability_id
	entry.raw_event = event
	return entry


func _entry_from_ability_canceled(event, event_tick: int) -> CombatLogEntry:
	var source_entity_id := _ability_event_source_entity_id(event)
	var ability_id := _ability_event_ability_id(event)
	var entity_ids: Array = []
	_append_entity_id(entity_ids, source_entity_id)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var source_is_local := _is_local_id(source_entity_id)
	var source_name := _entity_name(entity_names, source_entity_id, source_is_local)
	var entry: CombatLogEntry = _new_entry(
			event_tick,
			&"cast",
			"%s %s casting %s: %s." % [
				source_name,
				_verb_for_subject(source_is_local, "stop", "stops"),
				_ability_name(ability_id),
				_cancel_reason_text(_ability_event_cancel_reason(event)),
			],
			&"warning")
	entry.source_entity_id = source_entity_id
	entry.ability_id = ability_id
	entry.raw_event = event
	return entry


func _entries_from_resolved_effects(resolved, event_tick: int, phase: int) -> Array[CombatLogEntry]:
	var entries: Array[CombatLogEntry] = []
	if resolved == null:
		return entries
	var entity_ids: Array = []
	var source_entity_id := _source_entity_id_for_resolved(resolved)
	_append_entity_id(entity_ids, source_entity_id)
	for effect in resolved.get_effects():
		if effect.get_phase() != phase:
			continue
		_append_entity_id(entity_ids, effect.get_target_entity_id())
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var source_name := _entity_name(entity_names, source_entity_id, _is_local_id(source_entity_id))
	for effect in resolved.get_effects():
		if effect.get_phase() != phase:
			continue
		var entry := _entry_from_resolved_effect(resolved, effect, event_tick, source_entity_id, source_name, entity_names)
		if entry != null:
			entries.append(entry)
	return entries


func _entry_from_resolved_effect(
		resolved,
		effect,
		event_tick: int,
		source_entity_id: int,
		source_name: String,
		entity_names: Dictionary) -> CombatLogEntry:
	var ability_id = resolved.get_ability_id()
	var target_entity_id = effect.get_target_entity_id()
	var target_is_local := _is_local_id(target_entity_id)
	var target_name := _entity_name(entity_names, target_entity_id, target_is_local)
	match effect.get_kind():
		Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_DAMAGE:
			var damage_entry: CombatLogEntry = _new_entry(
					event_tick,
					&"damage",
					"%s %s %s for %d." % [
						_possessive_entity_name(source_name, _is_local_id(source_entity_id)),
						_ability_name_for_effect(ability_id),
						_verb_for_target_hit(_entity_object_name(entity_names, target_entity_id)),
						int(effect.get_amount()),
					],
					&"important")
			damage_entry.source_entity_id = source_entity_id
			damage_entry.target_entity_id = target_entity_id
			damage_entry.ability_id = ability_id
			damage_entry.amount = int(effect.get_amount())
			damage_entry.raw_event = resolved
			return damage_entry
		Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_HEAL:
			var heal_entry: CombatLogEntry = _new_entry(
					event_tick,
					&"healing",
					"%s %s %s for %d." % [
						_possessive_entity_name(source_name, _is_local_id(source_entity_id)),
						_ability_name_for_effect(ability_id),
						_verb_for_target_heal(_entity_object_name(entity_names, target_entity_id)),
						int(effect.get_amount()),
					])
			heal_entry.source_entity_id = source_entity_id
			heal_entry.target_entity_id = target_entity_id
			heal_entry.ability_id = ability_id
			heal_entry.amount = int(effect.get_amount())
			heal_entry.raw_event = resolved
			return heal_entry
		Proto.ResolvedAbilityEffectKind.RESOLVED_EFFECT_STATUS:
			var category: StringName = &"debuff" if effect.get_is_debuff() else &"buff"
			var message := "%s %s %s from %s." % [
				target_name,
				_verb_for_subject(target_is_local, "suffer", "suffers") if effect.get_is_debuff() else _verb_for_subject(target_is_local, "gain", "gains"),
				_status_name(effect.get_status_id()),
				_ability_name(ability_id),
			]
			var status_entry: CombatLogEntry = _new_entry(
					event_tick,
					category,
					message,
					&"warning" if effect.get_is_debuff() else &"info")
			status_entry.source_entity_id = source_entity_id
			status_entry.target_entity_id = target_entity_id
			status_entry.ability_id = ability_id
			status_entry.status_id = effect.get_status_id()
			status_entry.raw_event = resolved
			return status_entry
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


func _should_ignore_local_outgoing_effect(source_entity_id: int) -> bool:
	return source_entity_id > 0 and _is_local_id(source_entity_id)


func _ability_event_source_entity_id(event) -> int:
	if event == null:
		return 0
	if event.has_method("get_source_entity_id"):
		return int(event.get_source_entity_id())
	if event is EntityEvents:
		return int(event.source_entity_id)
	return 0


func _ability_event_target_entity_id(event) -> int:
	if event == null:
		return 0
	if event.has_method("get_target_entity_id"):
		return int(event.get_target_entity_id())
	if event is EntityEvents:
		return int(event.target_entity_id)
	return 0


func _ability_event_ability_id(event) -> int:
	if event == null:
		return 0
	if event.has_method("get_ability_id"):
		return int(event.get_ability_id())
	if event is EntityEvents:
		return int(event.ability_id)
	return 0


func _ability_event_cancel_reason(event) -> int:
	if event == null:
		return 0
	if event.has_method("get_cancel_reason"):
		return int(event.get_cancel_reason())
	if event is EntityEvents:
		return int(event.cancel_reason)
	return 0


func _event_entity_id(event) -> int:
	if event == null:
		return 0
	if event.has_ability_use_started():
		return event.get_ability_use_started().get_source_entity_id()
	if event.has_ability_use_canceled():
		return event.get_ability_use_canceled().get_source_entity_id()
	if event.has_ability_use_finished():
		return event.get_ability_use_finished().get_source_entity_id()
	if event.has_ability_use_impact():
		return event.get_ability_use_impact().get_source_entity_id()
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
	elif event.has_ability_use_finished():
		_append_entity_id(ids, event.get_ability_use_finished().get_source_entity_id())
	elif event.has_ability_use_impact():
		_append_entity_id(ids, event.get_ability_use_impact().get_source_entity_id())
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
	var ability_name: String = AbilityDB.get_ability_name(ability_id)
	if ability_name != "":
		return ability_name
	return "Ability %d" % ability_id


func _ability_name_for_effect(ability_id: int) -> String:
	return _ability_name(ability_id).to_lower()


func _status_name(status_id: int) -> String:
	var status_name: String = AbilityDB.get_status_name(status_id)
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
		5:
			return "insufficient resources"
		_:
			return "canceled"


func _source_entity_id_for_resolved(resolved) -> int:
	if resolved == null or _game_manager == null:
		return 0
	return _game_manager.get_local_player_id()


func _flush_scheduled_entries(current_tick: int) -> void:
	if _scheduled_entries.is_empty():
		return
	var pending: Array[CombatLogEntry] = []
	for entry in _scheduled_entries:
		if entry == null:
			continue
		if entry.tick > current_tick:
			pending.append(entry)
			continue
		_publish_entry(entry)
	_scheduled_entries = pending
