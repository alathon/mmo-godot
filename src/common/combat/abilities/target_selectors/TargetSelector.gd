class_name TargetSelector
extends Resource

enum TargetFilter {
	ENEMIES,
	ALLIES,
	ANY,
}

@export var selector_id: StringName = &""
@export var allow_caster: bool = false
@export var allow_target: bool = false
