class_name RemotePlayerController
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

var _displacement_velocity: Vector3 = Vector3.ZERO

@onready var _interpolator: RemoteInterpolator = $RemoteInterpolator

var face_angle: float:
	get: return rotation.y
	set(v): rotation.y = v

func _ready() -> void:
	set_physics_process(false)
	NetworkTime.on_tick.connect(_on_displacement_tick)

func on_entity_diff(entity: Proto.EntityState, tick: int) -> void:
	var server_pos := Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	var server_rot := entity.get_rot_y()
	_interpolator.push_snapshot(tick, {
		"global_position": server_pos,
		"face_angle": server_rot,
	})

func apply_displacement(impulse: Vector3) -> void:
	_displacement_velocity += impulse
	_interpolator.set_paused(true)

func _on_displacement_tick(_delta: float, _tick: int) -> void:
	if _displacement_velocity.is_zero_approx():
		return

	velocity = _displacement_velocity * NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	_displacement_velocity *= 0.85
	if _displacement_velocity.length() < 0.01:
		_displacement_velocity = Vector3.ZERO
		_interpolator.set_paused(false)
