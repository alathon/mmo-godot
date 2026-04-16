class_name AbilityValidationResult
extends RefCounted

var ok: bool = false
var reason: StringName = &""
var cancel_reason: int = AbilityConstants.CANCEL_INVALID


static func accepted():
	return null


static func rejected(reason: StringName, cancel_reason: int):
	return null
