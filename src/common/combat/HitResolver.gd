class_name HitResolver
extends RefCounted

enum HitResult {
	HIT = 0,
	MISS = 1,
	DODGE = 2,
	CRIT = 3,
	BLOCK = 4,
	CRIT_BLOCK = 5,
}


func resolve_hit(_ability: AbilityResource, _caster_stats: Dictionary, _target_stats: Stats) -> HitResult:
	# Placeholder until combat stats include hit, crit, dodge, block, and resist values.
	return HitResult.HIT


func did_land(hit_result: HitResult) -> bool:
	return hit_result != HitResult.MISS and hit_result != HitResult.DODGE