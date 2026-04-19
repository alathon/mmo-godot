class_name ResolvedAbilityUseSnapshot
extends RefCounted

var source_entity_id: int = 0
var request_id: int = 0
var ability_id: StringName = &""
var requested_tick: int = 0
var start_tick: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0
var effects: Array = []


static func from_scheduled_use(use) -> ResolvedAbilityUseSnapshot:
	var resolved := ResolvedAbilityUseSnapshot.new()
	if use == null:
		return resolved
	resolved.source_entity_id = use.source_entity_id
	resolved.request_id = use.request_id
	resolved.ability_id = use.ability_id
	resolved.requested_tick = use.requested_tick
	resolved.start_tick = use.start_tick
	resolved.resolve_tick = use.resolve_tick
	resolved.finish_tick = use.finish_tick
	resolved.impact_tick = use.impact_tick
	return resolved
