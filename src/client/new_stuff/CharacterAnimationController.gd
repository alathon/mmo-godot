extends Node

var animation_tree: AnimationTree
var animation_player: AnimationPlayer

func bind_model(new_animation_tree: AnimationTree, new_animation_player: AnimationPlayer, expression_base_node: Node) -> void:
	animation_tree = new_animation_tree
	animation_player = new_animation_player
	animation_tree.advance_expression_base_node = animation_tree.get_path_to(expression_base_node)
	animation_tree.active = true


func on_entity_event(_event: EntityEvents, _event_tick: int) -> void:
	return


func on_ability_resolved(_resolved) -> void:
	return
