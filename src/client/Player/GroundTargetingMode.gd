class_name GroundTargetingMode
extends Node

@onready var _body: CharacterBody3D = %Body
@onready var _input_source: LocalInput = %LocalInput

var _ability_id: int = 0


func is_active() -> bool:
	return _ability_id > 0


func is_active_for(ability_id: int) -> bool:
	return _ability_id > 0 and _ability_id == ability_id


func get_ability_id() -> int:
	return _ability_id


func activate(ability_id: int) -> void:
	_ability_id = maxi(0, ability_id)


func deactivate() -> void:
	_ability_id = 0


func capture_primary_click(screen_position: Vector2) -> bool:
	if not is_active() or _input_source == null:
		return false
	_input_source.capture_primary_click(screen_position)
	return true


func consume_target_spec(input: Dictionary) -> AbilityTargetSpec:
	if not is_active():
		return null
	if not bool(input.get("primary_click_pressed", false)):
		return null
	return _build_ground_target_spec(input.get("primary_click_position", Vector2.ZERO) as Vector2)


func build_target_spec_at_cursor() -> AbilityTargetSpec:
	if not is_active():
		return null
	return _build_ground_target_spec(get_viewport().get_mouse_position())


func _build_ground_target_spec(screen_position: Vector2) -> AbilityTargetSpec:
	var ground_position = _raycast_ground_position(screen_position)
	if ground_position == null:
		return null
	return AbilityTargetSpec.ground(ground_position)


func _raycast_ground_position(screen_position: Vector2):
	if _input_source == null or _input_source.camera == null or _body == null:
		return null
	var origin := _input_source.camera.project_ray_origin(screen_position)
	var direction := _input_source.camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0)
	query.exclude = [_body.get_rid()]
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.get("position", null)
