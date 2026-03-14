class_name Player
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@export_range(2.0, 20.0) var Speed = 5.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5

# When set, this player runs physics from the input source and sends to the server.
@export var input_source: Node

# When set, position (and future properties) are driven by server snapshots via interpolation.
@export var interpolator: Interpolator

var _network: Node

func _ready() -> void:
	if input_source != null:
		_network = get_node_or_null("%Network")

func _physics_process(delta: float) -> void:
	if input_source == null:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input_source.jump_pressed and is_on_floor():
		velocity.y = JumpVelocity
	if input_source.movement != Vector3.ZERO:
		velocity.x = input_source.movement.x * Speed
		velocity.z = input_source.movement.z * Speed
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)
	move_and_slide()
	if _network:
		_network.send_input(input_source.movement.x, input_source.movement.z, input_source.jump_pressed, global_position)

func on_entity_diff(entity: Proto.EntityState) -> void:
	if interpolator == null:
		return
	interpolator.push_snapshot({
		"global_position": Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	})
