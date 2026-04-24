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

enum VarianceProfile {
	NONE,
	PLUS_MINUS_10_PCT,
	WEIGHTED_LOW_HIGH,
}

@export var ability_id: int = 0
@export var ability_name: String = ""
@export var icon: Texture2D
@export var group_tags: PackedStringArray = []  # e.g. ["fire_spell", "aoe_spell"]; used by AbilityModifier targeting
@export var tags: PackedStringArray = []
@export var hit_type: HitType = HitType.MAGICAL
@export var variance_profile: VarianceProfile = VarianceProfile.NONE
@export var target_type: TargetType = TargetType.OTHER_ENEMY
@export var cast_time: float = 0.0
@export var cast_lock_time: float = -1.0   # seconds of casting before lock engages (cancelable window); <=0 = lock at start
@export var resolve_lead_ticks: int = 8
@export var range: float = 0.0
@export var uses_gcd: bool = true
@export var cooldown: float = 0.0          # recharge time per charge
@export var max_charges: int = 1           # 1 = normal cooldown; >1 = charge-based cooldown
@export var cooldown_group: String = ""     # "" = no group
@export var mana_cost: int = 0
@export var stamina_cost: int = 0
@export var energy_cost: int = 0
@export var effects: Array[AbilityEffect] = []
@export var conditional_effects: Array[ConditionalEffect] = []
@export var target_selectors: Array[TargetSelector] = []

@export_group("AOE")
@export var aoe_shape: AoeShape = AoeShape.NONE
@export var aoe_radius: float = 0.0


func get_ability_id() -> int:
	return ability_id


func get_ability_name() -> String:
	return ability_name


func get_ability_key() -> StringName:
	return StringName(resource_path.get_file().get_basename())
