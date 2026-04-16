class_name AbilityValidationResult
extends RefCounted

var ok: bool = false
var reason: StringName = &""
var cancel_reason: int = AbilityConstants.CANCEL_INVALID


static func accepted():
	var result := AbilityValidationResult.new()
	result.ok = true
	return result


static func rejected(reason: StringName, cancel_reason: int):
	var result := AbilityValidationResult.new()
	result.ok = false
	result.reason = reason
	result.cancel_reason = cancel_reason
	return result
