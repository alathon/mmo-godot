@abstract
class_name Entity
extends Node

var id: int = 0
var is_local: bool = false

var face_angle: float:
	get:
		return _get_face_angle()
	set(value):
		_set_face_angle(value)


func get_visual() -> Node3D:
	var model := get_node_or_null("%Model") as Node3D
	if model != null:
		return model
	return get_node_or_null("%Visual") as Node3D


func get_position() -> Vector3:
	var body := get_node_or_null("%Body") as Node3D
	if body != null:
		return body.global_position
	var visual := get_visual()
	if visual == null:
		push_error("Entity has no visual node and no body node")
		return Vector3.ZERO
	return visual.global_position


@abstract
func _get_face_angle() -> float


@abstract
func _set_face_angle(value: float) -> void
