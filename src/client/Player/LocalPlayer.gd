class_name LocalPlayer
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _camera := %Camera as Camera3D
@onready var _network := %Network

@export_range(2.0, 20.0) var Speed = 5.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var jump_pressed := Input.is_action_just_pressed("jump") and is_on_floor()
	if jump_pressed:
		velocity.y = JumpVelocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction := (_camera.global_basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0
	direction = direction.normalized()

	if direction:
		velocity.x = direction.x * Speed
		velocity.z = direction.z * Speed
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)

	move_and_slide()

	_network.send_input(direction.x, direction.z, jump_pressed, global_position)

# TODO: For now do nothing.
func on_entity_diff(entity: Proto.EntityState):
	pass
