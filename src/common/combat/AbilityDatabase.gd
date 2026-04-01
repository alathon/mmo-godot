class_name AbilityDatabase

const ABILITIES_DIR: String = "res://src/common/data/abilities/"

var _abilities: Dictionary = {} # id -> AbilityDef


func load_all() -> void:
	_abilities.clear()
	var dir := DirAccess.open(ABILITIES_DIR)
	if dir == null:
		push_error("AbilityDatabase: could not open %s" % ABILITIES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_file(ABILITIES_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func get_ability(id: String) -> AbilityDef:
	return _abilities.get(id, null)


func get_all() -> Array: # Array[AbilityDef]
	return _abilities.values()


func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AbilityDatabase: could not read %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("AbilityDatabase: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return
	var d: Dictionary = json.data
	var ability := AbilityDef.from_dict(d)
	if ability.id == "":
		push_error("AbilityDatabase: ability in %s is missing 'id'" % path)
		return
	_abilities[ability.id] = ability
