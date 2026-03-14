class_name LocalInput
extends Node

@export var camera: Camera3D

var movement: Vector3 = Vector3.ZERO
var jump_pressed: bool = false

# Latch: set any time jump is pressed between tick loops, consumed on next tick.
var _jump_latch: bool = false

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_latch = true

func _on_before_tick_loop() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	movement = camera.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	movement.y = 0
	movement = movement.normalized()

	jump_pressed = _jump_latch
	_jump_latch = false
