class_name ServerPlayer
extends CharacterBody3D

const SPEED = 10.0
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 10.0

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

## Whether this player has ever received input from the client.
## False during clock sync; simulation is skipped until first input arrives.
var has_received_input: bool = false

## Last applied input (re-executed when no new input arrives for a tick).
var last_input := { "input_x": 0.0, "input_z": 0.0, "jump_pressed": false }

func simulate(input: Dictionary, delta: float) -> void:
	var ix: float = input.get("input_x", 0.0)
	var iz: float = input.get("input_z", 0.0)
	var jump: bool = input.get("jump_pressed", false)

	if not is_on_floor():
		velocity += get_gravity() * delta

	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var movement := Vector3(ix, 0.0, iz)
	if movement != Vector3.ZERO:
		velocity.x = movement.x * SPEED
		velocity.z = movement.z * SPEED
		var target_y := atan2(-movement.x, -movement.z)
		rotation.y = lerp_angle(rotation.y, target_y, delta * TURN_SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# physics_factor is 1.0 when Engine.physics_ticks_per_second == TICK_RATE
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	last_input = input.duplicate()
	last_input["jump_pressed"] = false
