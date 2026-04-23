extends Node

const HOTBAR_SLOT_SCRIPT_PATH := "res://src/client/hotbars/HotbarSlot.gd"

signal slot_changed(slot)
signal bar_changed(bar_id: StringName)

var _bars: Dictionary = {}


func ensure_bar(
		bar_id: StringName,
		size: int,
		binding_prefix: StringName = &"hotbar") -> void:
	var existing: Array = _bars.get(bar_id, [])
	if existing.size() >= size:
		return

	var slots: Array = existing.duplicate()
	for slot_index in range(existing.size(), size):
		var binding_id := StringName("%s.%s.slot_%d" % [
			String(binding_prefix),
			String(bar_id),
			slot_index + 1,
		])
		var slot: Variant = load(HOTBAR_SLOT_SCRIPT_PATH).new()
		slot.bar_id = bar_id
		slot.slot_index = slot_index
		slot.slot_id = load(HOTBAR_SLOT_SCRIPT_PATH).call("make_slot_id", bar_id, slot_index)
		slot.binding_id = binding_id
		slots.append(slot)
	_bars[bar_id] = slots
	bar_changed.emit(bar_id)


func has_bar(bar_id: StringName) -> bool:
	return _bars.has(bar_id)


func get_slot(bar_id: StringName, slot_index: int):
	var slots: Array = _bars.get(bar_id, [])
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]


func get_slot_by_id(slot_id: StringName):
	for bar_slots_value in _bars.values():
		var bar_slots: Array = bar_slots_value
		for slot in bar_slots:
			if slot.slot_id == slot_id:
				return slot
	return null


func get_slots(bar_id: StringName) -> Array:
	var slots: Array = _bars.get(bar_id, [])
	return slots.duplicate()


func set_slot(slot) -> void:
	if slot == null:
		return
	ensure_bar(slot.bar_id, slot.slot_index + 1)
	var slots: Array = _bars.get(slot.bar_id, [])
	slots[slot.slot_index] = slot
	_bars[slot.bar_id] = slots
	slot_changed.emit(slot)
	bar_changed.emit(slot.bar_id)


func set_slot_ability(bar_id: StringName, slot_index: int, ability_id: int):
	ensure_bar(bar_id, slot_index + 1)
	var slot: Variant = get_slot(bar_id, slot_index)
	if slot == null:
		return null
	slot.assign_ability(ability_id)
	slot_changed.emit(slot)
	bar_changed.emit(bar_id)
	return slot


func clear_slot(bar_id: StringName, slot_index: int) -> void:
	var slot: Variant = get_slot(bar_id, slot_index)
	if slot == null:
		return
	slot.clear_content()
	slot_changed.emit(slot)
	bar_changed.emit(bar_id)
