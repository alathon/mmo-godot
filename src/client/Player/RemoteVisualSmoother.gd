class_name RemoteVisualSmoother
extends Node3D

## Visual container for remote entities.
## Positioned by RemoteInterpolator via interpolated snapshots.
## top_level = true so the parent's transform doesn't affect us.
var velocity: Vector3 = Vector3.ZERO
var _is_on_floor: bool = true

var face_angle: float:
	get:
		return rotation.y
	set(value):
		rotation.y = value

func _ready() -> void:
	top_level = true
