class_name DamageResolver
extends RefCounted

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


func resolve_damage(effect: DamageEffect, ability: AbilityResource, caster_stats: Dictionary) -> int:
	return _resolve_amount(effect.formula, ability, caster_stats)


func resolve_heal(effect: HealEffect, ability: AbilityResource, caster_stats: Dictionary) -> int:
	return _resolve_amount(effect.formula, ability, caster_stats)


func _resolve_amount(formula: ValueFormula, ability: AbilityResource, caster_stats: Dictionary) -> int:
	if formula == null:
		return 0

	var amount := formula.evaluate(caster_stats)
	amount *= _roll_variance(ability.variance_profile)
	return maxi(0, int(amount))


func _roll_variance(profile: AbilityResource.VarianceProfile) -> float:
	match profile:
		AbilityResource.VarianceProfile.PLUS_MINUS_10_PCT:
			return _rng.randf_range(0.9, 1.1)
		AbilityResource.VarianceProfile.WEIGHTED_LOW_HIGH:
			return _roll_weighted_low_high()
		_:
			return 1.0


func _roll_weighted_low_high() -> float:
	var edge_bias := sqrt(_rng.randf())
	if _rng.randf() < 0.5:
		return lerpf(1.0, 0.9, edge_bias)
	return lerpf(1.0, 1.1, edge_bias)