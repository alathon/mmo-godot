class_name AbilityResource
extends Resource

enum TargetType {
	SELF,
	OTHER_ENEMY,
	OTHER_FRIEND,
	OTHER_ANY,
	GROUND,
}

enum AoeShape {
	NONE,
	CIRCLE,
	CONE,
}

enum HitType {
	PHYSICAL,
	MAGICAL,
}

@export var display_name: String = ""
@export var group_tag: StringName = &""     # e.g. "fire_spell", "melee_attack"; used by AbilityModifier targeting
@export var tags: PackedStringArray = []
@export var hit_type: HitType = HitType.MAGICAL
@export var target_type: TargetType = TargetType.OTHER_ENEMY
@export var cast_time: float = 0.0
@export var range: float = 0.0
@export var uses_gcd: bool = true
@export var cooldown: float = 0.0
@export var cooldown_group: String = ""     # "" = no group
@export var mana_cost: int = 0
@export var stamina_cost: int = 0
@export var energy_cost: int = 0
@export var effects: Array[AbilityEffect] = []
@export var conditional_effects: Array[ConditionalEffect] = []

@export_group("AOE")
@export var aoe_shape: AoeShape = AoeShape.NONE
@export var aoe_radius: float = 0.0


# The canonical ability ID is the resource filename without extension.
func get_ability_id() -> StringName:
	return StringName(resource_path.get_file().get_basename())
