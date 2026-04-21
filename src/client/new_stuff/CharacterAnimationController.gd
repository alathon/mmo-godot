extends Node

const ACTION_ONE_SHOT_REQUEST_PATH := "parameters/OneShot/request"

var animation_tree: AnimationTree
var animation_player: AnimationPlayer
var _has_action_one_shot: bool = false

func bind_model(new_animation_tree: AnimationTree, new_animation_player: AnimationPlayer, expression_base_node: Node) -> void:
	animation_tree = new_animation_tree
	animation_player = new_animation_player
	animation_tree.advance_expression_base_node = animation_tree.get_path_to(expression_base_node)
	animation_tree.active = true
	_has_action_one_shot = _has_animation_tree_parameter(ACTION_ONE_SHOT_REQUEST_PATH)


func on_entity_event(event: EntityEvents, _event_tick: int) -> void:
	match event.type:
		EntityEvents.Type.ABILITY_USE_STARTED:
			_fire_action_one_shot()
		EntityEvents.Type.ABILITY_USE_CANCELED:
			_fade_out_action_one_shot()


func on_ability_resolved(_resolved) -> void:
	return


func _fire_action_one_shot() -> void:
	if not _has_action_one_shot:
		return

	animation_tree.set(ACTION_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE)
	animation_tree.set(ACTION_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _fade_out_action_one_shot() -> void:
	if not _has_action_one_shot:
		return

	animation_tree.set(ACTION_ONE_SHOT_REQUEST_PATH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _has_animation_tree_parameter(parameter_name: String) -> bool:
	for property in animation_tree.get_property_list():
		if property.name == parameter_name:
			return true
	return false
