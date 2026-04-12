class_name ConditionTargetHasTag
extends ConditionResource

@export var tag: String = ""


# target must implement has_tag(tag: String) -> bool
func evaluate(caster: Node, target: Node) -> bool:
	var result: bool = target.has_tag(tag)
	return result != negate
