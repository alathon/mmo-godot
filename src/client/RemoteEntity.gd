class_name RemoteEntity
extends Node3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _interpolator: RemoteInterpolator = %RemoteInterpolator

var last_server_tick_received: int = -1
var last_server_tick_processed: int = -1

var last_server_pos: Vector3
var last_server_rot: float

var id: int

func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func on_entity_position_diff(entity: Proto.EntityPosition, tick: int) -> void:
	last_server_tick_received = tick
	
	last_server_pos = Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	last_server_rot = entity.get_rot_y()

	_interpolator.push_snapshot(tick, {
		"global_position": last_server_pos,
		"face_angle": last_server_rot,
	})

func _on_before_tick_loop(tick: int) -> void:
	if last_server_tick_received == -1 or last_server_tick_processed == last_server_tick_received:
		return
	
	last_server_tick_processed = last_server_tick_received
	global_position = last_server_pos
	rotation.y = last_server_rot
