class_name RemotePlayer
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

var _from_position: Vector3
var _to_position: Vector3
var _interp_time: float = 0.0
var _last_server_pos: Vector3

func _ready() -> void:
	_from_position = global_position
	_to_position = global_position
	_last_server_pos = global_position

func set_target_position(pos: Vector3) -> void:
	_from_position = global_position
	_to_position = pos
	_interp_time = 0.0

func _process(delta: float) -> void:
	_interp_time += delta
	var t = clamp(_interp_time / Globals.TICK_INTERVAL, 0.0, 1.0)
	global_position = _from_position.lerp(_to_position, t)

func on_entity_diff(entity: Proto.EntityState) -> void:
	_last_server_pos.x = entity.get_pos_x()
	_last_server_pos.y = entity.get_pos_y()
	_last_server_pos.z = entity.get_pos_z()
	set_target_position(_last_server_pos)
