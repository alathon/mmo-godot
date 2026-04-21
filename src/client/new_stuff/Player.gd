class_name PlayerNew
extends Node

@onready var body: CharacterBody3D = %Body
@onready var csp: CSP = %CSP
@onready var modelRoot: VisualSmoother = %Model

var id: int
var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer

var frozen: bool = true:
	set = set_frozen

func set_frozen(value: bool):
	frozen = value
	if frozen:
		print("[CLIENT] Player frozen")
		body.velocity = Vector3.ZERO
		modelRoot.Body = null # Stop the visual smoother.
		csp._input_history.clear()
		csp._pending_server_tick = -1
	else:
		print("[CLIENT] Player unfrozen")

func set_character_model(name) -> void:
	var new_model = (load("res://assets/entities/character_models/%s.tscn" % name)).instantiate()

	# Check for existing model
	var current_model = modelRoot.get_node_or_null("BaseCharacter")
	if current_model:
		current_model.queue_free()

	print("Setting character model to res://assets/entities/character_models/%s.tscn" % name)
	modelRoot.add_child(new_model)

	# These models start at 0,0,0 and grow upward, while the collision capsule is *centered* at
	# 0,0,0. So offset the y position accordingly so we're not floating in the air.
	new_model.position.y = -1

	# Connect the AnimationTree to the Body (must be relative path from the AnimationTree node)
	var anim_tree: AnimationTree = new_model.get_node("%AnimationTree") as AnimationTree
	anim_tree.advance_expression_base_node = anim_tree.get_path_to(body)
	anim_tree.active = true

	_animationTree = anim_tree
	_animationPlayer = new_model.get_node("%AnimationPlayer") as AnimationPlayer

func on_server_position(pos: Vector3, vel: Vector3, rot: float, tick: int):
	if frozen:
		return

	csp.setPendingServerTick(tick, pos, vel, rot)

func capture_primary_click(pos):
	return false # TODO: This method shouldn't be here..

func clear_target():
	return # TODO: Shouldn't be here.

func set_target_entity_id(_entity_id: int):
	return # TODO: Shouldn't be here
