class_name RemoteBody
extends Node3D

# This RemoteBody needs to be API-compliant with things from CharacterBody3D
# so that other things can 'treat it' similar. Which means we need:
# - face_angle
# - velocity
# - is_on_ground()

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

var velocity: Vector3
var _is_on_floor: bool = true

func is_on_floor() -> bool:
	return _is_on_floor
