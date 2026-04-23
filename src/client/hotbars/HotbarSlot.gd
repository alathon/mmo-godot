extends RefCounted

enum ContentKind {
	NONE,
	ABILITY,
	ITEM,
	MACRO,
}

var slot_id: StringName = &""
var bar_id: StringName = &""
var slot_index: int = -1
var binding_id: StringName = &""
var content_kind: ContentKind = ContentKind.NONE
var ability_id: int = 0
var item_id: StringName = &""
var macro_id: StringName = &""

static func make_slot_id(p_bar_id: StringName, p_slot_index: int) -> StringName:
	return StringName("%s.%d" % [String(p_bar_id), p_slot_index])


func is_empty() -> bool:
	return content_kind == ContentKind.NONE


func assign_ability(p_ability_id: int) -> void:
	content_kind = ContentKind.ABILITY
	ability_id = p_ability_id
	item_id = &""
	macro_id = &""


func clear_content() -> void:
	content_kind = ContentKind.NONE
	ability_id = 0
	item_id = &""
	macro_id = &""
