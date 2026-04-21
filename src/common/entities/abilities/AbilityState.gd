class_name AbilityStateOld
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0

var cast_source_entity_id: int = 0
var cast_request_id: int = 0
var cast_ability_id: int = 0
var cast_target: AbilityTargetSpec = null
var cast_total: float = 0.0
var cast_total_ticks: int = 0
var cast_requested_tick: int = 0
var cast_start_tick: int = 0
var cast_lock_tick: int = 0
var cast_resolve_tick: int = 0
var cast_finish_tick: int = 0
var cast_impact_tick: int = 0
var cast_locked: bool = false

var queued_source_entity_id: int = 0
var queued_request_id: int = 0
var queued_ability_id: int = 0
var queued_target: AbilityTargetSpec = null
var queued_requested_tick: int = 0


func is_casting() -> bool:
	return cast_ability_id > 0


func has_queued() -> bool:
	return queued_ability_id > 0


func clear_cast() -> void:
	cast_source_entity_id = 0
	cast_request_id = 0
	cast_ability_id = 0
	cast_target = null
	cast_total = 0.0
	cast_total_ticks = 0
	cast_requested_tick = 0
	cast_start_tick = 0
	cast_lock_tick = 0
	cast_resolve_tick = 0
	cast_finish_tick = 0
	cast_impact_tick = 0
	cast_locked = false


func clear_queued() -> void:
	queued_source_entity_id = 0
	queued_request_id = 0
	queued_ability_id = 0
	queued_target = null
	queued_requested_tick = 0
