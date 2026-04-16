class_name AbilityState
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0

var cast_ability_id: StringName = &""
var cast_target: AbilityTargetSpec = null
var cast_total: float = 0.0
var cast_remaining: float = 0.0
var cast_requested_tick: int = 0
var cast_start_tick: int = 0

var queued_ability_id: StringName = &""
var queued_target: AbilityTargetSpec = null
var queued_requested_tick: int = 0


func is_casting() -> bool:
	return false


func has_queued() -> bool:
	return false


func clear_cast() -> void:
	pass


func clear_queued() -> void:
	pass
