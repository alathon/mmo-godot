class_name Player
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@export_range(2.0, 20.0) var Speed = 10.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5
@export_range(1.0, 30.0) var TurnSpeed = 10.0

# When set, this player runs physics from the input source and sends to the server.
@export var input_source: Node

# When set, position (and future properties) are driven by server snapshots via interpolation.
@export var interpolator: RemoteInterpolator

var _network: Node

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

func _ready() -> void:
	if input_source != null:
		_network = get_node_or_null("%Network")
		NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
		NetworkTime.on_tick.connect(_on_network_tick)
	else:
		set_physics_process(false)

func _on_before_tick_loop() -> void:
	pass

#func _physics_process(delta: float):
	#print("Delta %s | PhysicsFactor %s" % [delta, NetworkTime.physics_factor])
	#if not is_on_floor():
		#velocity += get_gravity() * delta
	#if input_source.jump_pressed and is_on_floor():
		#velocity.y = JumpVelocity
	#if input_source.movement != Vector3.ZERO:
		#velocity.x = input_source.movement.x * Speed
		#velocity.z = input_source.movement.z * Speed
		#var target_y := atan2(-input_source.movement.x, -input_source.movement.z)
		#rotation.y = lerp_angle(rotation.y, target_y, delta * TurnSpeed)
	#else:
		#velocity.x = move_toward(velocity.x, 0, Speed)
		#velocity.z = move_toward(velocity.z, 0, Speed)
#
	#velocity *= NetworkTime.physics_factor
	#
	#print("\tVelocity: %s" % velocity)
	#move_and_slide()
	#velocity /= NetworkTime.physics_factor
#
	#if _network:
		#_network.send_input(input_source.movement.x, input_source.movement.z, input_source.jump_pressed, global_position, rotation.y)
		#
func _on_network_tick(delta: float, _tick: int) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input_source.jump_pressed and is_on_floor():
		velocity.y = JumpVelocity
	if input_source.movement != Vector3.ZERO:
		velocity.x = input_source.movement.x * Speed
		velocity.z = input_source.movement.z * Speed
		var target_y := atan2(-input_source.movement.x, -input_source.movement.z)
		rotation.y = lerp_angle(rotation.y, target_y, delta * TurnSpeed)
	else:
		velocity.x = move_toward(velocity.x, 0, Speed)
		velocity.z = move_toward(velocity.z, 0, Speed)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	if _network:
		_network.send_input(input_source.movement.x, input_source.movement.z, input_source.jump_pressed, global_position, rotation.y)

func on_entity_diff(entity: Proto.EntityState, tick: int) -> void:
	if interpolator == null:
		return
	interpolator.push_snapshot(tick, {
		"global_position": Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z()),
		"face_angle": entity.get_rot_y(),
	})
