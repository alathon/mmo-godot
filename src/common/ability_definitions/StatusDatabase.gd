class_name StatusDatabase
extends RefCounted

const STATUSES_DIR: String = "res://resources/statuses/"

var _statuses_by_id: Dictionary = {} # int -> StatusResource


func clear() -> void:
	_statuses_by_id.clear()


func load_all() -> void:
	clear()
	var dir := DirAccess.open(STATUSES_DIR)
	if dir == null:
		push_error("StatusDatabase: could not open %s" % STATUSES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			_load_file(STATUSES_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func register_embedded_statuses_from_abilities(abilities: Array) -> void:
	for ability in abilities:
		if ability == null:
			continue
		var ability_key: StringName = ability.get_ability_key()
		var ability_label := "%s(id=%d)" % [ability_key, ability.get_ability_id()]
		_register_embedded_statuses_in_effects(ability.effects, ability_label)
		for conditional_effect in ability.conditional_effects:
			if conditional_effect == null or conditional_effect.mod == null:
				continue
			_register_embedded_statuses_in_effects(conditional_effect.mod.added_effects, ability_label)


func validate_ability_references(abilities: Array) -> bool:
	var ok := true
	for ability in abilities:
		if ability == null:
			continue
		var ability_key: StringName = ability.get_ability_key()
		var ability_label := "%s(id=%d)" % [ability_key, ability.get_ability_id()]
		ok = _validate_effect_references(ability.effects, ability_label) and ok
		for conditional_effect in ability.conditional_effects:
			if conditional_effect == null:
				continue
			if conditional_effect.condition is ConditionCasterHasStatus:
				var condition := conditional_effect.condition as ConditionCasterHasStatus
				if not _is_valid_referenced_status_id(condition.status_id):
					push_error("StatusDatabase: invalid ConditionCasterHasStatus.status_id=%d in %s" % [
						condition.status_id,
						ability_label,
					])
					ok = false
			if conditional_effect.mod != null:
				ok = _validate_effect_references(conditional_effect.mod.added_effects, ability_label) and ok
	return ok


func get_status_by_id(status_id: int) -> StatusResource:
	return _statuses_by_id.get(status_id, null)


func get_status_name(status_id: int) -> String:
	var status := get_status_by_id(status_id)
	if status == null:
		return ""
	return status.status_name


func has_status(status_id: int) -> bool:
	return _statuses_by_id.has(status_id)


func _load_file(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		push_error("StatusDatabase: could not load %s" % path)
		return
	if not res is StatusResource:
		push_error("StatusDatabase: resource at %s is not a StatusResource" % path)
		return
	_register_status(res as StatusResource, path)


func _validate_effect_references(effects: Array, ability_label: String) -> bool:
	var ok := true
	for effect in effects:
		if effect == null:
			continue
		if effect is ApplyStatusEffect:
			var apply_status := effect as ApplyStatusEffect
			var status_id := apply_status.get_status_id()
			if not _is_valid_referenced_status_id(status_id):
				push_error("StatusDatabase: invalid ApplyStatusEffect status_id=%d in %s" % [status_id, ability_label])
				ok = false
			ok = _validate_effect_references(apply_status.tick_effects, ability_label) and ok
		elif effect is ConsumeStacksEffect:
			var consume_stacks := effect as ConsumeStacksEffect
			if not _is_valid_referenced_status_id(consume_stacks.status_id):
				push_error("StatusDatabase: invalid ConsumeStacksEffect.status_id=%d in %s" % [
					consume_stacks.status_id,
					ability_label,
				])
				ok = false
			ok = _validate_effect_references(consume_stacks.per_stack_effects, ability_label) and ok
	return ok


func _is_valid_referenced_status_id(status_id: int) -> bool:
	return status_id > 0 and _statuses_by_id.has(status_id)


func _register_embedded_statuses_in_effects(effects: Array, ability_label: String) -> void:
	for effect in effects:
		if effect == null:
			continue
		if effect is ApplyStatusEffect:
			var apply_status := effect as ApplyStatusEffect
			if apply_status.status != null:
				_register_status(apply_status.status, "%s embedded status" % ability_label)
			_register_embedded_statuses_in_effects(apply_status.tick_effects, ability_label)
		elif effect is ConsumeStacksEffect:
			var consume_stacks := effect as ConsumeStacksEffect
			_register_embedded_statuses_in_effects(consume_stacks.per_stack_effects, ability_label)


func _register_status(status: StatusResource, source_label: String) -> void:
	if status == null:
		return
	var status_id := status.status_id
	if status_id <= 0:
		push_error("StatusDatabase: invalid status_id=%d in %s" % [status_id, source_label])
		return
	if status.status_name.strip_edges() == "":
		push_error("StatusDatabase: empty status_name in %s" % source_label)
		return
	if _statuses_by_id.has(status_id):
		var existing := _statuses_by_id[status_id] as StatusResource
		if existing == status:
			return
		if existing != null and existing.status_name == status.status_name:
			return
		push_error("StatusDatabase: duplicate status_id=%d in %s" % [status_id, source_label])
		return
	_statuses_by_id[status_id] = status
