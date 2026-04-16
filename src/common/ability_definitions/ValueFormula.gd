class_name ValueFormula
extends Resource

@export var base: float = 0.0
@export var components: Array[StatComponent] = []


# stats: Dictionary[StatComponent.StatType, float]
func evaluate(stats: Dictionary) -> float:
	var result: float = base
	for component in components:
		result += stats.get(component.stat, 0.0) * component.coefficient
	return result
