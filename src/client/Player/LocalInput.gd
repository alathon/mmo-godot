class_name LocalInput
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@export var camera: Camera3D

var movement: Vector3 = Vector3.ZERO
var jump_pressed: bool = false

func _physics_process(delta: float) -> void:
	jump_pressed = Input.is_action_just_pressed("jump")

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	movement = (camera.global_basis * Vector3(input_dir.x, 0, input_dir.y))
	movement.y = 0
	movement = movement.normalized()
