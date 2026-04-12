class_name ConditionalEffect
extends Resource

@export var condition: ConditionResource

# Set one or the other, not both.
# applied_modifier: applies an AbilityModifier to this cast if the condition is met.
# added_effects: injects extra effects into this cast if the condition is met.
@export var applied_modifier: AbilityModifier
@export var added_effects: Array[AbilityEffect] = []
