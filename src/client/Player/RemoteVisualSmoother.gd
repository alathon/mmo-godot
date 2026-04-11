class_name RemoteVisualSmoother
extends Node3D

## Visual container for remote entities.
## Positioned by RemoteInterpolator via interpolated snapshots.
## top_level = true so the parent's transform doesn't affect us.

var face_angle: float:
	set(value):
		face_angle = value
		rotation.y = value

func _ready() -> void:
	top_level = true
