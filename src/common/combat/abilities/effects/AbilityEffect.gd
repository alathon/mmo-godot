class_name AbilityEffect
extends Resource

enum TargetNarrower {
	ALL,
	HOSTILE,
	FRIENDLY,
}

@export var effect_id: StringName = &""        # set to allow AbilityModifier to remove this effect by ID
@export var tags: PackedStringArray = []
@export_range(1, 100) var proc_chance: float = 100.0   # percentage chance to apply; 100 = guaranteed
@export var target_narrower: TargetNarrower = TargetNarrower.ALL
@export var target_selector_id: StringName = &""       # if set, applies to targets from this selector instead of the primary target
