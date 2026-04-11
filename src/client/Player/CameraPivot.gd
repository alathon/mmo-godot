extends Node3D

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)
@export var offset: Vector3 = Vector3(0, 2.0, 0)
@export var _target: Node3D

@onready var _zone_container: ZoneContainer = $/root/Root/ZoneContainer
@onready var _game_manager: GameManager = $/root/Root/Services/GameManager

var _mouse_position_when_hidden = Vector2.ZERO

func _ready() -> void:
	_zone_container.zone_before_unloading.connect(func(_id): _target = null)
	_game_manager.local_player_spawned.connect(func(p): _target = p.get_node("%VisualSmoother"))

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
