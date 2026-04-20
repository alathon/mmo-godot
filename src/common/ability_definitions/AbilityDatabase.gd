class_name AbilityDatabase
extends Node

const ABILITIES_DIR: String = "res://resources/abilities/"

var _abilities_by_id: Dictionary = {} # int -> AbilityResource
var _abilities_by_key: Dictionary = {} # StringName -> AbilityResource
var _status_db: StatusDatabase = StatusDatabase.new()

func _ready():
	load_all()

func load_all() -> void:
	_abilities_by_id.clear()
	_abilities_by_key.clear()
	_status_db.load_all()
	var dir := DirAccess.open(ABILITIES_DIR)
	if dir == null:
		push_error("AbilityDatabase: could not open %s" % ABILITIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			_load_file(ABILITIES_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_status_db.register_embedded_statuses_from_abilities(_abilities_by_id.values())
	if not _status_db.validate_ability_references(_abilities_by_id.values()):
		push_error("AbilityDatabase: status validation failed")


func get_ability(ability_id: int) -> AbilityResource:
	return get_ability_by_id(ability_id)


func get_ability_by_id(ability_id: int) -> AbilityResource:
	return _abilities_by_id.get(ability_id, null)


func get_ability_by_key(ability_key: StringName) -> AbilityResource:
	return _abilities_by_key.get(ability_key, null)


func get_ability_name(ability_id: int) -> String:
	var ability := get_ability_by_id(ability_id)
	if ability == null:
		return ""
	return ability.get_ability_name()


func get_status_by_id(status_id: int) -> StatusResource:
	return _status_db.get_status_by_id(status_id)


func get_status_name(status_id: int) -> String:
	return _status_db.get_status_name(status_id)


func get_all() -> Array: # Array[AbilityResource]
	return _abilities_by_id.values()


func _load_file(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		push_error("AbilityDatabase: could not load %s" % path)
		return
	if not res is AbilityResource:
		push_error("AbilityDatabase: resource at %s is not an AbilityResource" % path)
		return
	var ability := res as AbilityResource
	var ability_id := ability.get_ability_id()
	if ability_id <= 0:
		push_error("AbilityDatabase: ability at %s has invalid ability_id=%d" % [path, ability_id])
		return
	if ability.get_ability_name().strip_edges() == "":
		push_error("AbilityDatabase: ability at %s has empty ability_name" % path)
		return
	if _abilities_by_id.has(ability_id):
		push_error("AbilityDatabase: duplicate ability_id=%d at %s" % [ability_id, path])
		return
	var ability_key := ability.get_ability_key()
	if ability_key == &"":
		push_error("AbilityDatabase: ability at %s has empty ability key" % path)
		return
	if _abilities_by_key.has(ability_key):
		push_error("AbilityDatabase: duplicate ability key '%s' at %s" % [ability_key, path])
		return
	if not _validate_target_selector_usage(ability, path):
		return
	_abilities_by_id[ability_id] = ability
	_abilities_by_key[ability_key] = ability


func _validate_target_selector_usage(ability: AbilityResource, path: String) -> bool:
	var selector_ids: Dictionary = {}
	for selector in ability.target_selectors:
		if selector == null:
			continue
		var selector_id: StringName = selector.selector_id
		if selector_id == &"":
			push_error("AbilityDatabase: selector with empty selector_id in %s" % path)
			return false
		if selector_ids.has(selector_id):
			push_error("AbilityDatabase: duplicate selector_id '%s' in %s" % [selector_id, path])
			return false
		selector_ids[selector_id] = true

	var has_selectors := not selector_ids.is_empty()
	if not _validate_effect_selector_references(ability.effects, selector_ids, has_selectors, path):
		return false
	for conditional_effect in ability.conditional_effects:
		if conditional_effect == null or conditional_effect.mod == null:
			continue
		if not _validate_effect_selector_references(conditional_effect.mod.added_effects, selector_ids, has_selectors, path):
			return false
	return true


func _validate_effect_selector_references(
		effects: Array,
		selector_ids: Dictionary,
		has_selectors: bool,
		path: String) -> bool:
	for effect in effects:
		if effect == null:
			continue
		var selector_id: StringName = effect.target_selector_id
		if selector_id != &"":
			if not has_selectors:
				push_error("AbilityDatabase: effect selector_id '%s' used without selectors in %s" % [selector_id, path])
				return false
			if not selector_ids.has(selector_id):
				push_error("AbilityDatabase: unknown selector_id '%s' in %s" % [selector_id, path])
				return false
		if effect is ApplyStatusEffect:
			var apply_status := effect as ApplyStatusEffect
			if not _validate_effect_selector_references(apply_status.tick_effects, selector_ids, has_selectors, path):
				return false
		elif effect is ConsumeStacksEffect:
			var consume_stacks := effect as ConsumeStacksEffect
			if not _validate_effect_selector_references(consume_stacks.per_stack_effects, selector_ids, has_selectors, path):
				return false
	return true
