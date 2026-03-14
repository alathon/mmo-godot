class_name LocalPlayer
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _network := %Network
@export var input: LocalInput

@export_range(2.0, 20.0) var Speed = 5.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if input.jump_pressed and is_on_floor():
		velocity.y = JumpVelocity

	if input.movement != Vector3.ZERO:
		velocity.x = input.movement.x * Speed
		velocity.z = input.movement.z * Speed
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)

	move_and_slide()

	_network.send_input(input.movement.x, input.movement.z, input.jump_pressed, global_position)

# TODO: For now do nothing.
func on_entity_diff(entity: Proto.EntityState):
	pass
