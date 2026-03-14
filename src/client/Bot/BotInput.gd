extends Node

var movement := Vector3.ZERO
var jump_pressed := false

var _timer := 0.0
var _direction_hold := 2.0  # seconds per direction

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.0, _direction_hold)
		var angle = randf() * TAU
		movement = Vector3(cos(angle), 0, sin(angle))
