class_name LocalInput
extends Node

@onready var camera: Camera3D = $/root/Root/CameraPivot/SpringArm3D/Camera

var movement: Vector3 = Vector3.ZERO
var jump_pressed: bool = false
var ability_id: int = 0
var primary_click_pressed: bool = false
var primary_click_position: Vector2 = Vector2.ZERO

# Latch: set any time jump is pressed between tick loops, consumed on next tick.
var _jump_latch: bool = false
var _ability_latch: int = 0
var _primary_click_latch: bool = false
var _primary_click_position_latch: Vector2 = Vector2.ZERO

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_latch = true
	if Input.is_action_just_pressed("test_fireball"):
		_ability_latch = 1

func _on_before_tick_loop(tick: int) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if camera:
		movement = camera.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	else:
		movement = Vector3(input_dir.x, 0, input_dir.y)

	movement.y = 0
	movement = movement.normalized()

	jump_pressed = _jump_latch
	_jump_latch = false
	ability_id = _ability_latch
	_ability_latch = 0
	primary_click_pressed = _primary_click_latch
	primary_click_position = _primary_click_position_latch
	_primary_click_latch = false
	_primary_click_position_latch = Vector2.ZERO


func capture_primary_click(screen_position: Vector2) -> void:
	_primary_click_latch = true
	_primary_click_position_latch = screen_position

func getInput() -> Dictionary:
	return {
		"input_x": movement.x,
		"input_z": movement.z,
		"jump_pressed": jump_pressed,
		"ability_id": ability_id,
		"primary_click_pressed": primary_click_pressed,
		"primary_click_position": primary_click_position,
	}
