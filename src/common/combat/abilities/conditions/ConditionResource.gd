class_name ConditionResource
extends Resource

@export var negate: bool = false


# Override in subclasses.
# caster and target are server-side entity nodes.
func evaluate(caster: Node, target: Node) -> bool:
	push_error("ConditionResource.evaluate() not implemented in %s" % resource_path)
	return false
