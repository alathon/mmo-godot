class_name AbilityUseResolvedGameEventData
extends RefCounted

const Proto = preload("res://src/common/proto/packets.gd")

var ability_id: int = 0
var source_entity_id: int = 0
var start_tick: int = 0
var request_id: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0
var effects: Array = []


static func from_proto(resolved: Proto.AbilityUseResolved) -> AbilityUseResolvedGameEventData:
	var data := AbilityUseResolvedGameEventData.new()
	data.ability_id = int(resolved.get_ability_id())
	data.start_tick = int(resolved.get_start_tick())
	data.request_id = int(resolved.get_request_id())
	data.resolve_tick = int(resolved.get_resolve_tick())
	data.finish_tick = int(resolved.get_finish_tick())
	data.impact_tick = int(resolved.get_impact_tick())
	data.effects = resolved.get_effects()
	return data
