class_name VisualSmoother
extends Node3D

## Smooths the visual representation of the local player so that clock-stretch
## induced tick-rate jitter doesn't cause visible speed changes.
##
## Attach to the Visual mesh node (child of the Player CharacterBody3D).
## The node must have top_level = true so it can be positioned independently.
##
## Reads physics position, input, and speed from the parent Player node.

## How fast the visual corrects toward the physics position (per second).
## Higher = snappier but lets more tick-rate jitter through.
## Lower = smoother but visual can drift further from physics.
@export_range(1.0, 30.0) var correction_rate: float = 10.0

## The smoothed position. External systems (e.g. camera) can read this.
var smooth_position: Vector3 = Vector3.ZERO

var _initialized: bool = false

@export var player: Player

func _ready() -> void:
	top_level = true
	NetworkTime.on_tick_reset.connect(_on_tick_reset)

func _on_tick_reset() -> void:
	_initialized = false

func _process(delta: float) -> void:
	if player == null:
		return

	if not _initialized or player.frozen or player.input_source == null:
		smooth_position = player.global_position
		_initialized = true
		_sync()
		return

	var ix: float = player.input_source.movement.x
	var iz: float = player.input_source.movement.z
	var has_input := ix != 0.0 or iz != 0.0

	if has_input:
		smooth_position.x += ix * player.Speed * delta
		smooth_position.z += iz * player.Speed * delta
		smooth_position.y = player.global_position.y
		smooth_position = smooth_position.lerp(player.global_position, correction_rate * delta)
	else:
		smooth_position = player.global_position

	_sync()

func _sync() -> void:
	global_position = smooth_position
	global_rotation.y = player.rotation.y
