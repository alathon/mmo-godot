class_name VisualSmoother
extends Node3D

## Smooths the visual representation of the local player towards
## the current PhysicsBody position.
##
## The visual node will have top_level = true set so it can be positioned independently.
##
## Reads physics position, input, and speed from the parent Player node.

## How fast the visual corrects toward the physics position (per second).
## Higher = snappier but lets more tick-rate jitter through.
## Lower = smoother but visual can drift further from physics.
@export_range(1.0, 30.0) var correction_rate: float = 20.0

@export var Body: PhysicsBody

## The smoothed position. External systems (e.g. camera) can read this.
var smooth_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	top_level = true

func _process(delta: float) -> void:
	if Body == null:
		return

	smooth_position = smooth_position.lerp(Body.global_position, correction_rate * delta)

	_sync()

func _sync() -> void:
	global_position = smooth_position
	global_rotation.y = Body.rotation.y
