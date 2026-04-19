class_name ScheduledAbilityUse
extends RefCounted

var source_entity_id: int = 0
var request_id: int = 0
var ability_id: int = 0
var target: AbilityTargetSpec = null
var requested_tick: int = 0
var start_tick: int = 0
var lock_tick: int = 0
var resolve_tick: int = 0
var finish_tick: int = 0
var impact_tick: int = 0
var canceled: bool = false
var resolved: bool = false
var early_applied: bool = false
var resolved_use: RefCounted = null


static func create(
		source_id: int,
		impact_ability_id: int,
		target_spec: AbilityTargetSpec,
		original_requested_tick: int,
		original_start_tick: int,
		scheduled_lock_tick: int,
		scheduled_resolve_tick: int,
		finished_tick: int,
		scheduled_impact_tick: int,
		request_id: int = 0) -> ScheduledAbilityUse:
	var use := ScheduledAbilityUse.new()
	use.source_entity_id = source_id
	use.request_id = request_id
	use.ability_id = impact_ability_id
	use.target = target_spec
	use.requested_tick = original_requested_tick
	use.start_tick = original_start_tick
	use.lock_tick = scheduled_lock_tick
	use.resolve_tick = scheduled_resolve_tick
	use.finish_tick = finished_tick
	use.impact_tick = scheduled_impact_tick
	return use
