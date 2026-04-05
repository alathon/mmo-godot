class_name MobCombatState
extends Node

## Per-entity combat timing state — shared between server and client.
## Server: written authoritatively by CombatManager each tick.
## Client: written predictively on ability use; reconciled via AbilityUseAccepted/Rejected
##         and CombatTickEvents.

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0
var target_entity_id: int = 0

# Active cast
var cast_ability_id: String = ""
var cast_target_entity_id: int = 0
var cast_ground_pos: Vector3 = Vector3.ZERO
var cast_total: float = 0.0      # original cast_time, used for queue-window calculation
var cast_remaining: float = 0.0  # counts down to 0
var cast_requested_tick: int = 0
var cast_start_tick: int = 0

# Queued ability (waiting for current cast or GCD to finish)
var queued_ability_id: String = ""
var queued_target_entity_id: int = 0
var queued_ground_pos: Vector3 = Vector3.ZERO
var queued_requested_tick: int = 0


func is_casting() -> bool:
	return cast_ability_id != ""


func has_queued() -> bool:
	return queued_ability_id != ""


func clear_cast() -> void:
	cast_ability_id = ""
	cast_target_entity_id = 0
	cast_ground_pos = Vector3.ZERO
	cast_total = 0.0
	cast_remaining = 0.0
	cast_requested_tick = 0
	cast_start_tick = 0


func clear_queued() -> void:
	queued_ability_id = ""
	queued_target_entity_id = 0
	queued_ground_pos = Vector3.ZERO
	queued_requested_tick = 0
