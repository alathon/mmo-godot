class_name AbilityModifier
extends Resource

enum TargetType {
	ABILITY_ID,
	ABILITY_GROUP_TAG,
}

@export var target_type: TargetType = TargetType.ABILITY_ID
@export var target_value: StringName = &""
@export var mod: AbilityMod
