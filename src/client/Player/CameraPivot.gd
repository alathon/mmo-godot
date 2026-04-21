extends Node3D

const CLICK_DRAG_THRESHOLD_PX := 6.0

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)
@export var offset: Vector3 = Vector3(0, 2.0, 0)
@export var _target: Node3D

@onready var _zone_container: ZoneContainer = $/root/Root/ZoneContainer
@onready var _game_manager: GameManager = $/root/Root/Services/GameManager

var _mouse_position_when_hidden = Vector2.ZERO
var _left_click_position := Vector2.ZERO
var _left_drag_delta := Vector2.ZERO
var _left_pressed := false
var _left_dragging := false

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
				_mouse_position_when_hidden = get_viewport().get_mouse_position()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
				call_deferred("_request_mouse_restore")

	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_rotate_from_mouse_motion(event.screen_relative)
		elif _left_pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_left_drag_delta += event.screen_relative
			if not _left_dragging and _left_drag_delta.length() >= CLICK_DRAG_THRESHOLD_PX:
				_left_dragging = true
			if _left_dragging:
				_rotate_from_mouse_motion(event.screen_relative)

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
	_mouse_position_when_hidden = get_viewport().get_mouse_position()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _end_left_click_or_drag() -> void:
	if not _left_pressed:
		return
	var should_select := not _left_dragging
	var select_position := _left_click_position
	_left_pressed = false
	_left_dragging = false
	_left_drag_delta = Vector2.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	call_deferred("_request_mouse_restore")
	if should_select:
		_game_manager.handle_primary_click(select_position)


func _rotate_from_mouse_motion(relative: Vector2) -> void:
	rotation.x -= relative.y * mouse_sensitivity
	# Prevent camera from rotating too far up/down
	rotation.x = clampf(rotation.x, -tilt_limit, tilt_limit)
	rotation.y += -relative.x * mouse_sensitivity
