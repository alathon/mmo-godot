extends Node3D

const CLICK_DRAG_THRESHOLD_PX := 6.0

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)
@export var offset: Vector3 = Vector3(0, 2.0, 0)
@export var _target: Node3D

@onready var _zone_container: ZoneContainer = $/root/Root/ZoneContainer
@onready var _game_manager: GameManager = $/root/Root/Services/GameManager
@onready var _world_input_service: WorldInputService = $/root/Root/Services/WorldInputService

var _mouse_position_when_hidden = Vector2.ZERO
var _left_click_position: Vector2 = Vector2.ZERO
var _left_drag_delta: Vector2 = Vector2.ZERO
var _left_pressed: bool = false
var _left_dragging: bool = false
var _right_click_position: Vector2 = Vector2.ZERO
var _right_drag_delta: Vector2 = Vector2.ZERO
var _right_pressed: bool = false
var _right_dragging: bool = false

func _ready() -> void:
	_zone_container.zone_before_unloading.connect(func(_id): _target = null)
	_game_manager.local_player_spawned.connect(func(p): _target = p.get_node("%Model"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_left_click_or_drag(event.position)
			else:
				_end_left_click_or_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_begin_right_click_or_drag(event.position)
			else:
				_end_right_click_or_drag()

	if event is InputEventMouseMotion:
		if _right_pressed and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_update_right_drag(event.screen_relative)
		elif _left_pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_left_drag(event.screen_relative)

func _process(_delta: float):
	if _target != null:
		# Follow visual_position (smoothed) when available, so the camera
		# isn't affected by tick-rate jitter from clock stretching.
		var pos: Vector3 = _target.global_position
		global_position.x = pos.x + offset.x
		global_position.y = pos.y + offset.y
		global_position.z = pos.z + offset.z

func _request_mouse_restore():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().warp_mouse(_mouse_position_when_hidden)


func _begin_left_click_or_drag(screen_position: Vector2) -> void:
	_left_pressed = true
	_left_dragging = false
	_left_drag_delta = Vector2.ZERO
	_left_click_position = screen_position


func _end_left_click_or_drag() -> void:
	if not _left_pressed:
		return
	var should_select: bool = not _left_dragging
	var select_position: Vector2 = _world_input_service.get_targeting_screen_position() if _left_dragging else _left_click_position
	_left_pressed = false
	_left_dragging = false
	_left_drag_delta = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_world_input_service.end_virtual_mouse()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		call_deferred("_request_mouse_restore")
	if should_select:
		_world_input_service.handle_primary_click(select_position)


func _begin_right_click_or_drag(screen_position: Vector2) -> void:
	_right_pressed = true
	_right_dragging = false
	_right_drag_delta = Vector2.ZERO
	_right_click_position = screen_position


func _end_right_click_or_drag() -> void:
	if not _right_pressed:
		return
	var should_cancel: bool = not _right_dragging
	var click_position: Vector2 = _right_click_position
	_right_pressed = false
	_right_dragging = false
	_right_drag_delta = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_world_input_service.end_virtual_mouse()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		call_deferred("_request_mouse_restore")
	if should_cancel:
		_world_input_service.handle_secondary_click(click_position)


func _update_left_drag(relative: Vector2) -> void:
	_left_drag_delta += relative
	if not _left_dragging and _left_drag_delta.length() >= CLICK_DRAG_THRESHOLD_PX:
		_left_dragging = true
		_capture_mouse_for_drag(_left_click_position)
	if _left_dragging:
		_world_input_service.update_virtual_mouse(relative)
		_rotate_from_mouse_motion(relative)


func _update_right_drag(relative: Vector2) -> void:
	_right_drag_delta += relative
	if not _right_dragging and _right_drag_delta.length() >= CLICK_DRAG_THRESHOLD_PX:
		_right_dragging = true
		_capture_mouse_for_drag(_right_click_position)
	if _right_dragging:
		_world_input_service.update_virtual_mouse(relative)
		_rotate_from_mouse_motion(relative)


func _capture_mouse_for_drag(restore_position: Vector2) -> void:
	_mouse_position_when_hidden = restore_position
	_world_input_service.begin_virtual_mouse(restore_position)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _rotate_from_mouse_motion(relative: Vector2) -> void:
	rotation.x -= relative.y * mouse_sensitivity
	# Prevent camera from rotating too far up/down
	rotation.x = clampf(rotation.x, -tilt_limit, tilt_limit)
	rotation.y += -relative.x * mouse_sensitivity
