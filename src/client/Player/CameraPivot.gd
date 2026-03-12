extends Node3D

@onready var _camera := %Camera as Camera3D

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)

var _mouse_position_when_hidden = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		if event.pressed:
			_mouse_position_when_hidden = get_viewport().get_mouse_position()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			call_deferred("_request_mouse_restore")

	if event is InputEventMouseMotion && event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		rotation.x -= event.screen_relative.y * mouse_sensitivity
		# Prevent camera from rotating too far up/down
		rotation.x = clampf(rotation.x, -tilt_limit, tilt_limit)
		rotation.y += -event.screen_relative.x * mouse_sensitivity

func _request_mouse_restore():
	Input.warp_mouse(_mouse_position_when_hidden)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
