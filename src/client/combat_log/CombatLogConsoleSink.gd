class_name CombatLogConsoleSink
extends RefCounted

var _owner: Node = null


func _init(owner: Node = null) -> void:
	_owner = owner


func write_entry(entry) -> void:
	if entry == null:
		return
	print("%s %s [COMBAT_LOG] category=%s message=%s" % [
		_format_tick_prefix(entry.tick),
		_get_log_prefix(),
		String(entry.category),
		entry.message,
	])


func _get_log_prefix() -> String:
	var client_id := 0
	if _owner != null and is_instance_valid(_owner):
		client_id = _owner.multiplayer.get_unique_id()
	return "[PLAYER %d]" % client_id


func _format_tick_prefix(tick: int) -> String:
	return "[TICK %d | (%s)]" % [tick, _timestamp()]


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
