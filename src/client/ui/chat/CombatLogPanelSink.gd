class_name CombatLogPanelSink
extends RefCounted

var _owner: Node = null


func _init(owner: Node = null) -> void:
	_owner = owner


func write_entry(entry) -> void:
	if entry == null:
		return
	if _owner == null or not is_instance_valid(_owner):
		return
	if _owner.has_method("append_entry"):
		_owner.append_entry(entry)
