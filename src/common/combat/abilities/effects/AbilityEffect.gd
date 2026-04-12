class_name AbilityEffect
extends Resource

enum TargetNarrower {
	ALL,
	HOSTILE,
	FRIENDLY,
}

@export var effect_id: StringName = &""   # set to allow AbilityModifier to remove this effect by ID
@export var target_narrower: TargetNarrower = TargetNarrower.ALL
