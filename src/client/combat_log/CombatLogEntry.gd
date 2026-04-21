class_name CombatLogEntry
extends RefCounted

var tick: int = 0
var timestamp_text: String = ""
var category: StringName = &"general"
var severity: StringName = &"info"
var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: int = 0
var status_id: int = 0
var amount: int = 0
var message: String = ""
var raw_event: Variant = null


func display_text() -> String:
	if timestamp_text == "":
		return message
	return "[(%s)] %s" % [timestamp_text, message]
