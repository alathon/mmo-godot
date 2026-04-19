class_name RemoteEntityBody
extends Node3D

var velocity: Vector3 = Vector3.ZERO
var _is_on_floor: bool = true

var face_angle: float:
	get:
		return rotation.y
	set(value):
		rotation.y = value


func is_on_floor() -> bool:
	return _is_on_floor
