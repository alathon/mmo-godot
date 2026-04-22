class_name BotInput
extends LocalInput

var _timer := 0.0
var _direction_hold := 2.0  # seconds per direction

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func _on_before_tick_loop(tick: int) -> void:
	_timer -= Globals.TICK_INTERVAL
	if _timer <= 0.0:
		_timer = randf_range(1.0, _direction_hold)
		if randf() < 0.3:
			movement = Vector3.ZERO
		else:
			var angle := randf() * TAU
			movement = Vector3(cos(angle), 0, sin(angle))

func getInput() -> Dictionary:
	return {
		"input_x": movement.x,
		"input_z": movement.z,
		"jump_pressed": jump_pressed,
		"ability_id": 0,
		"primary_click_pressed": false,
		"primary_click_position": Vector2.ZERO,
	}
