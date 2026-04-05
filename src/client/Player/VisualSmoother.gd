class_name VisualSmoother
extends Node3D

## Smooths the visual representation of the local player so that clock-stretch
## induced tick-rate jitter doesn't cause visible speed changes.
##
## Attach to the Visual mesh node (child of the CharacterBody3D).
## The visual node will have top_level = true set so it can be positioned independently.
##
## Reads physics position, input, and speed from the parent Player node.

## How fast the visual corrects toward the physics position (per second).
## Higher = snappier but lets more tick-rate jitter through.
## Lower = smoother but visual can drift further from physics.
@export_range(1.0, 30.0) var correction_rate: float = 10.0

@export var Body: PhysicsBody
@export var InputSource: LocalInput
@export var PlayerNode: Player

## The smoothed position. External systems (e.g. camera) can read this.
var smooth_position: Vector3 = Vector3.ZERO

var _initialized: bool = false

func _ready() -> void:
	top_level = true
	NetworkTime.on_tick_reset.connect(_on_tick_reset)

func _on_tick_reset() -> void:
	_initialized = false

func _process(delta: float) -> void:
	if Body == null:
		return

	if not _initialized:
		smooth_position = Body.global_position
		_initialized = true
		_sync()
		return

	var ix: float = InputSource.movement.x
	var iz: float = InputSource.movement.z
	var has_input := (ix != 0.0 or iz != 0.0) and not PlayerNode.frozen

	if has_input:
		smooth_position.x += ix * Body.Speed * delta
		smooth_position.z += iz * Body.Speed * delta
		smooth_position.y = Body.global_position.y
		smooth_position = smooth_position.lerp(Body.global_position, correction_rate * delta)
	else:
		smooth_position = Body.global_position

	_sync()

func _sync() -> void:
	global_position = smooth_position
	global_rotation.y = Body.rotation.y
