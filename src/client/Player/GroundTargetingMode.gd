class_name GroundTargetingMode
extends Node

@onready var _camera: Camera3D = $/root/Root/CameraPivot/SpringArm3D/Camera
@onready var _input_source: LocalInput = %LocalInput

var active: bool = false

func capture_primary_click(screen_position: Vector2) -> bool:
	if not active:
		return false
	_input_source.capture_primary_click(screen_position)
	return true

func consume_target_spec(input: Dictionary) -> AbilityTargetSpec:
	if not active:
		return null
	if not bool(input.get("primary_click_pressed", false)):
		return null
	return _build_ground_target_spec(input.get("primary_click_position", Vector2.ZERO) as Vector2)

func build_target_spec_at_cursor() -> AbilityTargetSpec:
	if not active:
		return null
	return _build_ground_target_spec(get_viewport().get_mouse_position())

func _build_ground_target_spec(screen_position: Vector2) -> AbilityTargetSpec:
	var ground_position = _raycast_ground_position(screen_position)
	if ground_position == null:
		return null
	return AbilityTargetSpec.ground(ground_position)

func _raycast_ground_position(screen_position: Vector2):
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse_pos)
	var direction := _camera.project_ray_normal(mouse_pos)

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 10000.0
	)
	query.collision_mask = 1 << 1 # only layer 2

	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	return hit.position
