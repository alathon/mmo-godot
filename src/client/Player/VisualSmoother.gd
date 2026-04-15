class_name VisualSmoother
extends Node3D

## Smooths the visual representation of the local player towards
## the current PhysicsBody position.
##
## The visual node will have top_level = true set so it can be positioned independently.
##
## Reads physics position, input, and speed from the parent Player node.

@export var Body: PhysicsBody

## The smoothed position. External systems (e.g. camera) can read this.
var smooth_position: Vector3 = Vector3.ZERO

var _prev_position: Vector3 = Vector3.ZERO
var _curr_position: Vector3 = Vector3.ZERO
var _prev_rotation_y: float = 0.0
var _curr_rotation_y: float = 0.0

func _physics_process(_delta: float) -> void:
	if Body == null:
		return
	_prev_position = _curr_position
	_curr_position = Body.global_position
	_prev_rotation_y = _curr_rotation_y
	_curr_rotation_y = Body.rotation.y

func _ready() -> void:
	top_level = true

func _process(_delta: float) -> void:
	if Body == null:
		return
	var fraction: float = Engine.get_physics_interpolation_fraction()
	smooth_position = _prev_position.lerp(_curr_position, fraction)
	_sync(fraction)

func _sync(fraction: float) -> void:
	global_position = smooth_position
	global_rotation.y = lerp_angle(_prev_rotation_y, _curr_rotation_y, fraction)
