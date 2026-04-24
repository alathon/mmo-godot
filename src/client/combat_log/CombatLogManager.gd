class_name CombatLogManager
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

signal entry_created(entry)

@export var max_entries: int = 200
@export var console_output_enabled: bool = true

@onready var _game_manager = %GameManager
@onready var _event_gateway: EventGateway = %EventGateway

var _entries: Array = []
var _sinks: Array[RefCounted] = []
var _enabled: bool = true
var _scheduled_entries: Array[CombatLogEntry] = []


func _ready() -> void:
	if console_output_enabled:
		add_sink(CombatLogConsoleSink.new(self))
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
	if _event_gateway != null:
		_connect_event_gateway(_event_gateway)


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


func _connect_event_gateway(event_gateway: EventGateway) -> void:
	event_gateway.event_emitted.connect(_on_game_event_emitted)


func _on_before_tick_loop(tick: int) -> void:
	if not _enabled:
		return
	_flush_scheduled_entries(tick)


func _on_game_event_emitted(event: GameEvent) -> void:
	if not _enabled or event == null:
		return
	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			_publish_entry(_entry_from_ability_started(event.data as AbilityUseStartedGameEventData, event.tick))
		GameEvent.Type.ABILITY_USE_CANCELED:
			_publish_entry(_entry_from_ability_canceled(event.data as AbilityUseCanceledGameEventData, event.tick))
		GameEvent.Type.ABILITY_USE_RESOLVED:
			var resolved = event.data as AbilityUseResolvedGameEventData
			for entry in _entries_from_resolved_effects(
					resolved,
					resolved.resolve_tick,
					Proto.ResolvedAbilityEffectPhase.RESOLVED_EFFECT_EARLY):
				_publish_entry(entry)
			var impact_entries := _entries_from_resolved_effects(
					resolved,
					resolved.impact_tick,
					Proto.ResolvedAbilityEffectPhase.RESOLVED_EFFECT_IMPACT)
			if impact_entries.is_empty():
				return
			var current_tick := int(NetworkTime.tick)
			if resolved.impact_tick <= current_tick:
				for entry in impact_entries:
					_publish_entry(entry)
				return
			for entry in impact_entries:
				_scheduled_entries.append(entry)
		_:
			_publish_entry(_entry_from_game_event(event))


func _entry_from_game_event(event: GameEvent) -> CombatLogEntry:
	var tick: int = event.tick
	var primary_entity_id: int = _game_event_entity_id(event)
	var entity_ids: Array = _game_event_entity_ids(event)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var primary_is_local: bool = _is_local_id(primary_entity_id)
	var primary_name: String = _entity_name(entity_names, primary_entity_id, primary_is_local)
	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED, GameEvent.Type.ABILITY_USE_CANCELED, GameEvent.Type.ABILITY_USE_FINISHED, GameEvent.Type.ABILITY_USE_IMPACT, GameEvent.Type.ABILITY_USE_RESOLVED:
			return null
		GameEvent.Type.DAMAGE_TAKEN:
			var data := event.data as DamageTakenGameEventData
			if _should_ignore_local_outgoing_effect(data.source_entity_id):
				return null
			var damage_entry: CombatLogEntry = _new_entry(
				tick,
				&"damage",
				"%s %s %s for %d." % [
					_possessive_entity_name(primary_name, primary_is_local),
					_ability_name_for_effect(data.ability_id),
					_verb_for_target_hit(_entity_object_name(entity_names, data.target_entity_id)),
					int(round(data.amount)),
				],
				&"important")
			damage_entry.source_entity_id = data.source_entity_id
			damage_entry.target_entity_id = data.target_entity_id
			damage_entry.ability_id = data.ability_id
			damage_entry.amount = int(round(data.amount))
			damage_entry.raw_event = event
			return damage_entry
		GameEvent.Type.HEALING_RECEIVED:
			var healing_data := event.data as HealingReceivedGameEventData
			if _should_ignore_local_outgoing_effect(healing_data.source_entity_id):
				return null
			var healing_entry: CombatLogEntry = _new_entry(
				tick,
				&"healing",
				"%s %s %s for %d." % [
					_possessive_entity_name(primary_name, primary_is_local),
					_ability_name_for_effect(healing_data.ability_id),
					_verb_for_target_heal(_entity_object_name(entity_names, healing_data.target_entity_id)),
					int(round(healing_data.amount)),
				])
			healing_entry.source_entity_id = healing_data.source_entity_id
			healing_entry.target_entity_id = healing_data.target_entity_id
			healing_entry.ability_id = healing_data.ability_id
			healing_entry.amount = int(round(healing_data.amount))
			healing_entry.raw_event = event
			return healing_entry
		GameEvent.Type.BUFF_APPLIED:
			var buff_data := event.data as StatusAppliedGameEventData
			if _should_ignore_local_outgoing_effect(buff_data.source_entity_id):
				return null
			var buff_entry: CombatLogEntry = _new_entry(
				tick,
				&"buff",
				"%s %s %s from %s." % [
					primary_name,
					_verb_for_subject(primary_is_local, "gain", "gains"),
					_status_name(buff_data.status_id),
					_ability_name(buff_data.ability_id),
				])
			buff_entry.source_entity_id = buff_data.source_entity_id
			buff_entry.target_entity_id = buff_data.target_entity_id
			buff_entry.ability_id = buff_data.ability_id
			buff_entry.status_id = buff_data.status_id
			buff_entry.raw_event = event
			return buff_entry
		GameEvent.Type.DEBUFF_APPLIED:
			var debuff_data := event.data as StatusAppliedGameEventData
			if _should_ignore_local_outgoing_effect(debuff_data.source_entity_id):
				return null
			var debuff_entry: CombatLogEntry = _new_entry(
				tick,
				&"debuff",
				"%s %s %s from %s." % [
					primary_name,
					_verb_for_subject(primary_is_local, "suffer", "suffers"),
					_status_name(debuff_data.status_id),
					_ability_name(debuff_data.ability_id),
				],
				&"warning")
			debuff_entry.source_entity_id = debuff_data.source_entity_id
			debuff_entry.target_entity_id = debuff_data.target_entity_id
			debuff_entry.ability_id = debuff_data.ability_id
			debuff_entry.status_id = debuff_data.status_id
			debuff_entry.raw_event = event
			return debuff_entry
		GameEvent.Type.STATUS_EFFECT_REMOVED:
			var removed_data := event.data as StatusEffectRemovedGameEventData
			var removed_entry: CombatLogEntry = _new_entry(
				tick,
				&"status",
				"%s %s %s." % [
					primary_name,
					_verb_for_subject(primary_is_local, "lose", "loses"),
					_status_name(removed_data.status_id),
				])
			removed_entry.target_entity_id = removed_data.entity_id
			removed_entry.status_id = removed_data.status_id
			removed_entry.raw_event = event
			return removed_entry
		GameEvent.Type.COMBAT_STARTED:
			var started_data := event.data as CombatEventGameEventData
			var started_entry: CombatLogEntry = _new_entry(
				tick,
				&"combat",
				"%s %s combat." % [
					primary_name,
					_verb_for_subject(primary_is_local, "enter", "enters"),
				])
			started_entry.source_entity_id = started_data.source_entity_id
			started_entry.target_entity_id = started_data.entity_id
			started_entry.raw_event = event
			return started_entry
		GameEvent.Type.COMBAT_ENDED:
			var ended_data := event.data as CombatEventGameEventData
			var ended_entry: CombatLogEntry = _new_entry(
				tick,
				&"combat",
				"%s %s combat." % [
					primary_name,
					_verb_for_subject(primary_is_local, "leave", "leaves"),
				])
			ended_entry.target_entity_id = ended_data.entity_id
			ended_entry.raw_event = event
			return ended_entry
		GameEvent.Type.COMBATANT_DIED:
			var death_data := event.data as CombatEventGameEventData
			var killer_name := _entity_name(entity_names, death_data.killer_entity_id, _is_local_id(death_data.killer_entity_id)) if death_data.killer_entity_id > 0 else "Unknown"
			var death_entry: CombatLogEntry = _new_entry(
				tick,
				&"death",
				"%s dies. Killer: %s." % [
					primary_name,
					killer_name,
				],
				&"important")
			death_entry.source_entity_id = death_data.killer_entity_id
			death_entry.target_entity_id = death_data.entity_id
			death_entry.raw_event = event
			return death_entry
		_:
			return null


func _entry_from_ability_started(data: AbilityUseStartedGameEventData, event_tick: int) -> CombatLogEntry:
	var source_entity_id := data.source_entity_id
	var target_entity_id := data.target_entity_id
	var ability_id := data.ability_id
	var entity_ids: Array = []
	_append_entity_id(entity_ids, source_entity_id)
	_append_entity_id(entity_ids, target_entity_id)
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var source_is_local := _is_local_id(source_entity_id)
	var source_name := _entity_name(entity_names, source_entity_id, source_is_local)
	var ability_name: String = _ability_name(ability_id)
	var message: String = "%s %s %s." % [
		source_name,
		_verb_for_subject(source_is_local, "use", "uses"),
		ability_name,
	]
	if not _is_instant_ability(ability_id):
		message = "%s %s casting %s." % [
			source_name,
			_verb_for_subject(source_is_local, "start", "starts"),
			ability_name,
		]
	var entry: CombatLogEntry = _new_entry(
			event_tick,
			&"cast",
			message)
	entry.source_entity_id = source_entity_id
	entry.target_entity_id = target_entity_id
	entry.ability_id = ability_id
	entry.raw_event = data
	return entry


func _entry_from_ability_canceled(data: AbilityUseCanceledGameEventData, event_tick: int) -> CombatLogEntry:
	var source_entity_id := data.source_entity_id
	var ability_id := data.ability_id
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
				_cancel_reason_text(data.cancel_reason),
			],
			&"warning")
	entry.source_entity_id = source_entity_id
	entry.ability_id = ability_id
	entry.raw_event = data
	return entry


func _entries_from_resolved_effects(resolved: AbilityUseResolvedGameEventData, event_tick: int, phase: int) -> Array[CombatLogEntry]:
	var entries: Array[CombatLogEntry] = []
	if resolved == null:
		return entries
	var entity_ids: Array = []
	var source_entity_id := _source_entity_id_for_resolved(resolved)
	_append_entity_id(entity_ids, source_entity_id)
	for effect in resolved.effects:
		if int(effect.get_phase()) != phase:
			continue
		_append_entity_id(entity_ids, int(effect.get_target_entity_id()))
	var entity_names: Dictionary = _game_manager.get_entity_names(entity_ids) if _game_manager != null else {}
	var source_name := _entity_name(entity_names, source_entity_id, _is_local_id(source_entity_id))
	for effect in resolved.effects:
		if int(effect.get_phase()) != phase:
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
	var ability_id = resolved.ability_id
	var target_entity_id = int(effect.get_target_entity_id())
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
	entry.timestamp_text = _timestamp()
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


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]


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


func _game_event_entity_id(event: GameEvent) -> int:
	if event == null:
		return 0
	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			return int(event.data.source_entity_id)
		GameEvent.Type.ABILITY_USE_CANCELED:
			return int(event.data.source_entity_id)
		GameEvent.Type.ABILITY_USE_FINISHED, GameEvent.Type.ABILITY_USE_IMPACT:
			return int(event.data.source_entity_id)
		GameEvent.Type.DAMAGE_TAKEN:
			return int(event.data.source_entity_id)
		GameEvent.Type.HEALING_RECEIVED:
			return int(event.data.source_entity_id)
		GameEvent.Type.BUFF_APPLIED, GameEvent.Type.DEBUFF_APPLIED:
			return int(event.data.target_entity_id)
		GameEvent.Type.STATUS_EFFECT_REMOVED:
			return int(event.data.entity_id)
		GameEvent.Type.COMBAT_STARTED, GameEvent.Type.COMBAT_ENDED, GameEvent.Type.COMBATANT_DIED:
			return int(event.data.entity_id)
		_:
			return 0


func _game_event_entity_ids(event: GameEvent) -> Array:
	var ids: Array = []
	if event == null:
		return ids
	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			var started := event.data as AbilityUseStartedGameEventData
			_append_entity_id(ids, started.source_entity_id)
			_append_entity_id(ids, started.target_entity_id)
		GameEvent.Type.ABILITY_USE_CANCELED:
			_append_entity_id(ids, (event.data as AbilityUseCanceledGameEventData).source_entity_id)
		GameEvent.Type.ABILITY_USE_FINISHED, GameEvent.Type.ABILITY_USE_IMPACT:
			_append_entity_id(ids, (event.data as AbilityUseSimpleGameEventData).source_entity_id)
		GameEvent.Type.DAMAGE_TAKEN:
			var damage := event.data as DamageTakenGameEventData
			_append_entity_id(ids, damage.source_entity_id)
			_append_entity_id(ids, damage.target_entity_id)
		GameEvent.Type.HEALING_RECEIVED:
			var healing := event.data as HealingReceivedGameEventData
			_append_entity_id(ids, healing.source_entity_id)
			_append_entity_id(ids, healing.target_entity_id)
		GameEvent.Type.BUFF_APPLIED, GameEvent.Type.DEBUFF_APPLIED:
			var status := event.data as StatusAppliedGameEventData
			_append_entity_id(ids, status.source_entity_id)
			_append_entity_id(ids, status.target_entity_id)
		GameEvent.Type.STATUS_EFFECT_REMOVED:
			_append_entity_id(ids, (event.data as StatusEffectRemovedGameEventData).entity_id)
		GameEvent.Type.COMBAT_STARTED:
			var combat_started := event.data as CombatEventGameEventData
			_append_entity_id(ids, combat_started.entity_id)
			_append_entity_id(ids, combat_started.source_entity_id)
		GameEvent.Type.COMBAT_ENDED:
			_append_entity_id(ids, (event.data as CombatEventGameEventData).entity_id)
		GameEvent.Type.COMBATANT_DIED:
			var combat_died := event.data as CombatEventGameEventData
			_append_entity_id(ids, combat_died.entity_id)
			_append_entity_id(ids, combat_died.killer_entity_id)
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


func _is_instant_ability(ability_id: int) -> bool:
	var ability: AbilityResource = AbilityDB.get_ability(ability_id)
	return ability != null and ability.cast_time <= 0.0


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
