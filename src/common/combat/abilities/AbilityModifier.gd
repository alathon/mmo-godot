class_name AbilityModifier
extends Resource

enum TargetType {
	ABILITY_ID,
	ABILITY_GROUP_TAG,
}

@export var target_type: TargetType = TargetType.ABILITY_ID
@export var target_value: StringName = &""

# Multiplier formulas. null means no modification (treated as 1.0 by the server).
# For a flat multiplier set base to the desired value with no components.
# For a stat-scaled multiplier add StatComponents (e.g. base=1.0, intelligence*-0.01).
@export_group("Multipliers")
@export var cast_time_multiplier: ValueFormula
@export var resource_cost_multiplier: ValueFormula
@export var range_multiplier: ValueFormula
@export var damage_multiplier: ValueFormula
@export var heal_multiplier: ValueFormula

@export_group("Structural")
@export var added_effects: Array[AbilityEffect] = []
@export var removed_effect_ids: Array[StringName] = []
