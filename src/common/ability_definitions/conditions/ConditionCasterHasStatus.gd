class_name ConditionCasterHasStatus
extends ConditionResource

@export var status_id: int = 0


# caster must implement has_status(id: int) -> bool
func evaluate(caster: Node, target: Node) -> bool:
	var result: bool = caster.has_status(status_id)
	return result != negate
