class_name ConditionTargetHpBelow
extends ConditionResource

# Fraction of max HP (0.0 - 1.0). e.g. 0.2 = below 20% HP.
@export_range(0.0, 1.0) var threshold: float = 0.2


# target must implement get_hp_percent() -> float
func evaluate(caster: Node, target: Node) -> bool:
	var result: bool = target.get_hp_percent() < threshold
	return result != negate
