class_name RemotePlayer
extends CharacterBody3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var entitySync = %EntitySync

var _from_position: Vector3
var _to_position: Vector3
var _interp_time: float = 0.0

func _ready() -> void:
	_from_position = global_position
	_to_position = global_position

func set_target_position(pos: Vector3) -> void:
	_from_position = global_position
	_to_position = pos
	_interp_time = 0.0

func _process(delta: float) -> void:
	_interp_time += delta
	var t = clamp(_interp_time / Globals.TICK_INTERVAL, 0.0, 1.0)
	global_position = _from_position.lerp(_to_position, t)

func on_entity_diff(entity: Proto.EntityState) -> void:
	entitySync.on_entity_diff(entity)
