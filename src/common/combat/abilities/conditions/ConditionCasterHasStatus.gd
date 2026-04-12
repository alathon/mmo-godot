class_name ConditionCasterHasStatus
extends ConditionResource

@export var status_id: StringName = &""


# caster must implement has_status(id: StringName) -> bool
func evaluate(caster: Node, target: Node) -> bool:
	var result: bool = caster.has_status(status_id)
	return result != negate
