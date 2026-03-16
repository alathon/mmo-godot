extends Node3D

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)
@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 2.0, 0)

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

func _process(delta: float):
	if target != null:
		global_position.x = target.global_position.x + offset.x
		global_position.y = target.global_position.y + offset.y
		global_position.z = target.global_position.z + offset.z

func _request_mouse_restore():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().warp_mouse(_mouse_position_when_hidden)
