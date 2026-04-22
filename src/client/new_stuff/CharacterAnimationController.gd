extends Node

const CAST_START_ONE_SHOT_REQUEST_PATH := "parameters/CastStartOneShot/request"
const CAST_START_TIME_SCALE_PATH := "parameters/CastStartTimeScale/scale"
const CAST_FINISH_ONE_SHOT_REQUEST_PATH := "parameters/CastFinishOneShot/request"
const CAST_FINISH_TIME_SCALE_PATH := "parameters/CastFinishTimeScale/scale"
const CAST_START_ANIMATION_NAME := &"Spell2"
const CAST_FINISH_ANIMATION_NAME := &"Spell1"
const DEFAULT_CAST_FINISH_DURATION := 0.6

var animation_tree: AnimationTree
var animation_player: AnimationPlayer
var _has_cast_start_one_shot: bool = false
var _has_cast_finish_one_shot: bool = false
var _cast_start_clip_length: float = 0.0
var _cast_finish_clip_length: float = 0.0
var _finish_windows_by_request: Dictionary = {}

func bind_model(new_animation_tree: AnimationTree, new_animation_player: AnimationPlayer, expression_base_node: Node) -> void:
	animation_tree = new_animation_tree
	animation_player = new_animation_player
	animation_tree.advance_expression_base_node = animation_tree.get_path_to(expression_base_node)
	animation_tree.active = true
	_has_cast_start_one_shot = _has_animation_tree_parameter(CAST_START_ONE_SHOT_REQUEST_PATH)
	_has_cast_finish_one_shot = _has_animation_tree_parameter(CAST_FINISH_ONE_SHOT_REQUEST_PATH)
	_cast_start_clip_length = _get_animation_length(CAST_START_ANIMATION_NAME)
	_cast_finish_clip_length = _get_animation_length(CAST_FINISH_ANIMATION_NAME)
	_finish_windows_by_request.clear()


func on_game_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			_fire_cast_start_animation(event.data as AbilityUseStartedGameEventData)
		GameEvent.Type.ABILITY_USE_FINISHED:
			_fire_cast_finish_animation(event.data as AbilityUseSimpleGameEventData)
		GameEvent.Type.ABILITY_USE_CANCELED:
			_finish_windows_by_request.erase(int(event.data.request_id))
			_fade_out_cast_animations()
		GameEvent.Type.ABILITY_USE_RESOLVED:
			var resolved = event.data as AbilityUseResolvedGameEventData
			_finish_windows_by_request[resolved.request_id] = _ticks_to_seconds(
					resolved.impact_tick - resolved.finish_tick)


func _fire_cast_start_animation(event: AbilityUseStartedGameEventData) -> void:
	if not _has_cast_start_one_shot:
		return

	var duration := event.cast_time
	if duration <= 0.0:
		duration = _cast_start_clip_length
	_set_time_scale(CAST_START_TIME_SCALE_PATH, _cast_start_clip_length, duration)
	_request_one_shot(CAST_START_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _fire_cast_finish_animation(event: AbilityUseSimpleGameEventData) -> void:
	if not _has_cast_finish_one_shot:
		return

	var duration: float = _finish_windows_by_request.get(event.request_id, DEFAULT_CAST_FINISH_DURATION)
	_finish_windows_by_request.erase(event.request_id)
	_set_time_scale(CAST_FINISH_TIME_SCALE_PATH, _cast_finish_clip_length, duration)
	_request_one_shot(CAST_FINISH_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _fade_out_cast_animations() -> void:
	if _has_cast_start_one_shot:
		_request_one_shot(CAST_START_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if _has_cast_finish_one_shot:
		_request_one_shot(CAST_FINISH_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _request_one_shot(parameter_path: String, request: int) -> void:
	animation_tree.set(parameter_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE)
	animation_tree.set(parameter_path, request)


func _set_time_scale(parameter_path: String, clip_length: float, duration: float) -> void:
	if not _has_animation_tree_parameter(parameter_path):
		return
	if clip_length <= 0.0 or duration <= 0.0:
		animation_tree.set(parameter_path, 1.0)
		return
	animation_tree.set(parameter_path, clip_length / duration)


func _get_animation_length(animation_name: StringName) -> float:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return 0.0
	return animation_player.get_animation(animation_name).length


func _ticks_to_seconds(tick_count: int) -> float:
	if tick_count <= 0:
		return DEFAULT_CAST_FINISH_DURATION
	return float(tick_count) / Globals.TICK_RATE


func _has_animation_tree_parameter(parameter_name: String) -> bool:
	for property in animation_tree.get_property_list():
		if property.name == parameter_name:
			return true
	return false
