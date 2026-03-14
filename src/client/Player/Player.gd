class_name Player
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@export_range(2.0, 20.0) var Speed = 5.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5

# When set, this player runs physics from the input source and sends to the server.
# When null, position is driven by on_entity_diff (remote player interpolation).
@export var input_source: Node

var _network: Node

var _interp_from: Vector3
var _interp_to: Vector3
var _interp_t: float = 0.0

func _ready() -> void:
	_interp_from = global_position
	_interp_to = global_position
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

func _process(delta: float) -> void:
	if input_source != null:
		return
	_interp_t += delta
	global_position = _interp_from.lerp(_interp_to, clamp(_interp_t / Globals.TICK_INTERVAL, 0.0, 1.0))

func on_entity_diff(entity: Proto.EntityState) -> void:
	if input_source != null:
		return
	_interp_from = global_position
	_interp_to = Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	_interp_t = 0.0
