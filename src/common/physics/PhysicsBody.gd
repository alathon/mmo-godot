class_name PhysicsBody
extends CharacterBody3D

@onready var _physics_debug: MeshInstance3D = %PhysicsDebug

## Show a translucent red capsule at the physics body position.
@export var ShowPhysicsDebug: bool = false:
	set(v):
		ShowPhysicsDebug = v
		if _physics_debug:
			_physics_debug.visible = v

@export_range(2.0, 20.0) var Speed = 10.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5
@export_range(1.0, 30.0) var TurnSpeed = 10.0

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

func simulate(input: Dictionary, delta: float) -> void:
	velocity += get_gravity() * delta  # always; move_and_slide zeroes it on floor contact

	if input.get("jump_pressed", false) and is_on_floor():
		velocity.y = JumpVelocity

	var ix: float = input.get("input_x", 0.0)
	var iz: float = input.get("input_z", 0.0)
	var movement := Vector3(ix, 0.0, iz)

	if movement != Vector3.ZERO:
		velocity.x = movement.x * Speed
		velocity.z = movement.z * Speed
		var target_y := atan2(-movement.x, -movement.z)
		rotation.y = lerp_angle(rotation.y, target_y, delta * TurnSpeed)
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
