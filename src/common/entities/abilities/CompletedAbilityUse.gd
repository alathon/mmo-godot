class_name CompletedAbilityUse
extends RefCounted

var source_entity_id: int = 0
var ability_id: StringName = &""
var target: AbilityTargetSpec = null
var requested_tick: int = 0
var start_tick: int = 0
var completed_tick: int = 0


static func create(
		source_id: int,
		completed_ability_id: StringName,
		target_spec: AbilityTargetSpec,
		original_requested_tick: int,
		original_start_tick: int,
		finished_tick: int) -> CompletedAbilityUse:
	var completed := CompletedAbilityUse.new()
	completed.source_entity_id = source_id
	completed.ability_id = completed_ability_id
	completed.target = target_spec
	completed.requested_tick = original_requested_tick
	completed.start_tick = original_start_tick
	completed.completed_tick = finished_tick
	return completed