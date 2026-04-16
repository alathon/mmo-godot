class_name EntityEventCodec
extends RefCounted

const EntityEvents = preload("res://src/common/EntityEvents.gd")


static func write_tick_events(msg, events: Array[EntityEvents], sim_tick: int) -> void:
	pass


static func write_event(msg, event: EntityEvents, sim_tick: int) -> void:
	pass
