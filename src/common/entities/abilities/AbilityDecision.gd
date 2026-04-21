class_name AbilityDecision
extends RefCounted

enum Outcome {
	REJECTED,
	QUEUED,
	STARTED,
}

var outcome: Outcome = Outcome.REJECTED
var request_id: int = 0
var ability_id: int = 0
var target: AbilityTargetSpec = null
var requested_tick: int = 0
var earliest_activate_tick: int = 0
var reject_reason: int = AbilityConstants.CANCEL_INVALID


func is_rejected() -> bool:
	return outcome == Outcome.REJECTED


func is_queued() -> bool:
	return outcome == Outcome.QUEUED


func is_started() -> bool:
	return outcome == Outcome.STARTED
