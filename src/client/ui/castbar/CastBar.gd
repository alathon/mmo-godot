class_name CastBar
extends Control

@onready var progress: TextureProgressBar = $Progress
@onready var ability_name: Label = $AbilityName
@onready var time_left: Label = $TimeLeft

var _duration: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	clear_cast()


func _process(delta: float) -> void:
	if not visible:
		return

	_elapsed = minf(_elapsed + delta, _duration)
	progress.value = _elapsed
	time_left.text = _format_time(maxf(0.0, _duration - _elapsed))

	if _elapsed >= _duration:
		clear_cast()


func start_cast(display_name: String, duration: float) -> void:
	if duration <= 0.0:
		clear_cast()
		return

	_duration = duration
	_elapsed = 0.0
	progress.min_value = 0.0
	progress.max_value = duration
	progress.value = 0.0
	ability_name.text = display_name
	time_left.text = _format_time(duration)
	visible = true


func clear_cast() -> void:
	_duration = 0.0
	_elapsed = 0.0
	progress.value = 0.0
	ability_name.text = ""
	time_left.text = ""
	visible = false


func _format_time(time: float) -> String:
	return "%3.1f" % time
