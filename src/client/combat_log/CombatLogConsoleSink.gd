class_name CombatLogConsoleSink
extends RefCounted


func write_entry(entry) -> void:
	if entry == null:
		return
	print("[COMBAT_LOG] tick=%d category=%s message=%s" % [
		entry.tick,
		String(entry.category),
		entry.message,
	])
