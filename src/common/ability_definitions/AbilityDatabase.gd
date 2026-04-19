class_name AbilityDatabase

const ABILITIES_DIR: String = "res://resources/abilities/"

var _abilities_by_id: Dictionary = {} # int -> AbilityResource
var _abilities_by_key: Dictionary = {} # StringName -> AbilityResource


func load_all() -> void:
	_abilities_by_id.clear()
	_abilities_by_key.clear()
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
	_abilities_by_id[ability_id] = ability
	_abilities_by_key[ability_key] = ability
