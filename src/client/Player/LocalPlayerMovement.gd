extends Node

@onready var _camera := $"../Entities/LocalPlayer/CameraPivot/SpringArm3D/Camera" as Camera3D
@onready var _network := %Network
@onready var _player := %LocalPlayer as CharacterBody3D

@export_range(2.0, 20.0) var Speed = 5.0
@export_range(4.5, 10.0) var JumpVelocity = 4.5

func _physics_process(delta: float) -> void:
	if not _player.is_on_floor():
		_player.velocity += _player.get_gravity() * delta

	var jump_pressed := Input.is_action_just_pressed("jump") and _player.is_on_floor()
	if jump_pressed:
		_player.velocity.y = JumpVelocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var direction := (_camera.global_basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0
	direction = direction.normalized()

	if direction:
		_player.velocity.x = direction.x * Speed
		_player.velocity.z = direction.z * Speed
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0, Speed)
		_player.velocity.z = move_toward(_player.velocity.z, 0, Speed)

	_player.move_and_slide()

	#_network.send_input(direction.x, direction.z, jump_pressed, _player.global_position)
