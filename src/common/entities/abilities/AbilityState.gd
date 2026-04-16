class_name AbilityState
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0

var cast_source_entity_id: int = 0
var cast_ability_id: StringName = &""
var cast_target: AbilityTargetSpec = null
var cast_total: float = 0.0
var cast_remaining: float = 0.0
var cast_requested_tick: int = 0
var cast_start_tick: int = 0

var queued_source_entity_id: int = 0
var queued_ability_id: StringName = &""
var queued_target: AbilityTargetSpec = null
var queued_requested_tick: int = 0


func is_casting() -> bool:
	return cast_ability_id != &""


func has_queued() -> bool:
	return queued_ability_id != &""


func clear_cast() -> void:
	cast_source_entity_id = 0
	cast_ability_id = &""
	cast_target = null
	cast_total = 0.0
	cast_remaining = 0.0
	cast_requested_tick = 0
	cast_start_tick = 0


func clear_queued() -> void:
	queued_source_entity_id = 0
	queued_ability_id = &""
	queued_target = null
	queued_requested_tick = 0
