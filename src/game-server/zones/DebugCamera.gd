extends Camera3D

@export var move_speed: float = 20.0
@export var fast_multiplier: float = 3.0
@export var rotate_sensitivity: float = 0.003

var _rotating: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_rotating = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _rotating else Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and _rotating:
		rotate_y(-event.relative.x * rotate_sensitivity)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * rotate_sensitivity)

func _process(delta: float) -> void:
	var speed := move_speed * (fast_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= global_basis.z
	if Input.is_key_pressed(KEY_S): dir += global_basis.z
	if Input.is_key_pressed(KEY_A): dir -= global_basis.x
	if Input.is_key_pressed(KEY_D): dir += global_basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir != Vector3.ZERO:
		global_position += dir.normalized() * speed * delta
