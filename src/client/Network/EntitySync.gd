class_name EntitySync 
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@export_range(1.0, 20.0) var CORRECTION_THRESHOLD = 5.0
@export var enabled = true

@onready var _target = get_parent()

var _last_server_pos = Vector3.ZERO

func on_entity_diff(entity: Proto.EntityState) -> void:
	if !enabled:
		pass

	_last_server_pos.x = entity.get_pos_x()
	_last_server_pos.y = entity.get_pos_y()
	_last_server_pos.z = entity.get_pos_z()
	_target.set_target_position(_last_server_pos)
	#_apply_correction()

func _apply_correction() -> void:
	if _target.global_position.distance_to(_last_server_pos) > CORRECTION_THRESHOLD:
		print("[CLIENT] server correction: %.2f units, snapping" % _target.global_position.distance_to(_last_server_pos))
		_target.global_position = _last_server_pos
