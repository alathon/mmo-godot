class_name AbilityUseResult
extends RefCounted

const EntityEvents = preload("res://src/common/EntityEvents.gd")

var accepted: bool = false
var ability_id: StringName = &""
var requested_tick: int = 0
var start_tick: int = 0
var reject_reason: int = AbilityConstants.CANCEL_INVALID
var events: Array[EntityEvents] = []
