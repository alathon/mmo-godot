class_name AbilityDatabase

const ABILITIES_DIR: String = "res://resources/abilities/"

var _abilities: Dictionary = {} # StringName -> AbilityResource


func load_all() -> void:
	_abilities.clear()
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


func get_ability(id: StringName) -> AbilityResource:
	return _abilities.get(id, null)


func get_all() -> Array: # Array[AbilityResource]
	return _abilities.values()


func _load_file(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		push_error("AbilityDatabase: could not load %s" % path)
		return
	if not res is AbilityResource:
		push_error("AbilityDatabase: resource at %s is not an AbilityResource" % path)
		return
	var ability := res as AbilityResource
	var id := ability.get_ability_id()
	if id == &"":
		push_error("AbilityDatabase: ability at %s has no filename-derived ID" % path)
		return
	_abilities[id] = ability
