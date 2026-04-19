class_name ResolvedAbilityEffectSnapshot
extends RefCounted

enum Kind {
	DAMAGE,
	HEAL,
	STATUS,
}

enum Phase {
	IMPACT,
	EARLY,
}

var kind: Kind = Kind.DAMAGE
var phase: Phase = Phase.IMPACT
var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: StringName = &""
var hit_type: int = 0
var amount: int = 0
var status_effect_id: StringName = &""
var duration: float = 0.0
var is_debuff: bool = false
var aggro_modifier: float = 1.0


static func damage(
		source_id: int,
		target_id: int,
		resolved_ability_id: StringName,
		resolved_amount: int,
		resolved_aggro_modifier: float,
		resolved_hit_type: int = 0) -> ResolvedAbilityEffectSnapshot:
	var effect := ResolvedAbilityEffectSnapshot.new()
	effect.kind = Kind.DAMAGE
	effect.source_entity_id = source_id
	effect.target_entity_id = target_id
	effect.ability_id = resolved_ability_id
	effect.amount = resolved_amount
	effect.aggro_modifier = resolved_aggro_modifier
	effect.hit_type = resolved_hit_type
	return effect


static func heal(
		source_id: int,
		target_id: int,
		resolved_ability_id: StringName,
		resolved_amount: int,
		resolved_aggro_modifier: float,
		resolved_hit_type: int = 0) -> ResolvedAbilityEffectSnapshot:
	var effect := ResolvedAbilityEffectSnapshot.new()
	effect.kind = Kind.HEAL
	effect.source_entity_id = source_id
	effect.target_entity_id = target_id
	effect.ability_id = resolved_ability_id
	effect.amount = resolved_amount
	effect.aggro_modifier = resolved_aggro_modifier
	effect.hit_type = resolved_hit_type
	return effect


static func status(
		source_id: int,
		target_id: int,
		resolved_ability_id: StringName,
		status_id: StringName,
		resolved_duration: float,
		resolved_is_debuff: bool,
		resolved_hit_type: int = 0) -> ResolvedAbilityEffectSnapshot:
	var effect := ResolvedAbilityEffectSnapshot.new()
	effect.kind = Kind.STATUS
	effect.source_entity_id = source_id
	effect.target_entity_id = target_id
	effect.ability_id = resolved_ability_id
	effect.status_effect_id = status_id
	effect.duration = resolved_duration
	effect.is_debuff = resolved_is_debuff
	effect.hit_type = resolved_hit_type
	return effect
