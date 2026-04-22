class_name PlayerNew
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var body: CharacterBody3D = %Body
@onready var csp: CSP = %CSP
@onready var modelRoot: VisualSmoother = %Model
@onready var entity_state: EntityState = %EntityState
@onready var ability_manager: AbilityManager = %AbilityManager
@onready var animation_controller = %CharacterAnimationController

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
		modelRoot.Body = body

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

	
	var anim_tree: AnimationTree = new_model.get_node("%AnimationTree") as AnimationTree
	_animationTree = anim_tree
	_animationPlayer = new_model.get_node("%AnimationPlayer") as AnimationPlayer
	animation_controller.bind_model(_animationTree, _animationPlayer, self)

func on_server_position(pos: Vector3, vel: Vector3, rot: float, tick: int):
	if frozen:
		return

	csp.setPendingServerTick(tick, pos, vel, rot)

func apply_world_state(state: Proto.ServerEntityState):
	entity_state.on_world_state(state)

func on_game_event(event: GameEvent) -> void:
	entity_state.on_game_event(event)
	animation_controller.on_game_event(event)

func capture_primary_click(pos):
	return false # TODO: This method shouldn't be here..

func clear_target():
	return # TODO: Shouldn't be here.

func set_target_entity_id(_entity_id: int):
	return # TODO: Shouldn't be here
