class_name Player
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _body: CharacterBody3D = %Body
@onready var _csp: CSP = %CSP
@onready var _input_source: LocalInput = %LocalInput
@onready var _input_batcher: InputBatcher = %InputBatcher
@onready var _visual: VisualSmoother = %VisualSmoother
@onready var _target_state: EntityTargetState = %EntityTarget
@onready var _combat_manager: CombatManager = %CombatManager
@onready var _ability_manager: AbilityManager = %AbilityManager
@onready var _ability_presentation: Node = %AbilityPresentation
@onready var stats: Stats = %Stats

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer
var _debug: bool = false

var frozen: bool = true
var id: int

func set_target_entity_id(entity_id: int) -> void:
	_target_state.set_target_entity_id(entity_id)

func get_target_entity_id() -> int:
	return _target_state.get_target_entity_id()

func apply_world_state(state: Proto.EntityState) -> void:
	if stats != null:
		stats.apply_world_state(state)

func clear_target() -> void:
	_target_state.clear_target()

func _ready() -> void:
	NetworkTime.on_tick.connect(_on_network_tick)

func _on_network_tick(delta: float, current_tick: int) -> void:
	if frozen:
		return

	# Gather input
	var input = _input_source.getInput()

	# Apply ability use
	# ...

	# Apply movement input
	_body.simulate(input, delta)

	# Client-side post-tick stuff.
	_csp.setInputAt(current_tick, input)
	_csp.setPredictionAt(current_tick, { "global_position" = _body.global_position })

	# Batch input for server send.
	if _debug and (input["input_x"] != 0.0 or input["input_z"] != 0.0 or input["jump_pressed"]):
		print("[TRACE:Player %d] t=%s tick=%d input_gathered x=%.2f z=%.2f jump=%s" % [id,
			Globals.ts(), current_tick,
			input["input_x"], input["input_z"], input["jump_pressed"]])
	var ability_id := StringName(input.get("ability_id", ""))
	var target_entity_id := get_target_entity_id()
	if ability_id != &"":
		_ability_presentation.predict_ability_started(ability_id, target_entity_id, current_tick)
	_input_batcher.queue_input(
			input["input_x"],
			input["input_z"],
			input["jump_pressed"],
			_body.rotation.y,
			current_tick,
			input.get("ability_id", ""),
			target_entity_id)

func on_ability_started(event, event_tick: int) -> void:
	_ability_presentation.on_authoritative_ability_started(event, event_tick)

func on_ability_completed(event, event_tick: int) -> void:
	_ability_presentation.on_authoritative_ability_completed(event, event_tick)

func on_ability_canceled(event, event_tick: int) -> void:
	_ability_presentation.on_authoritative_ability_canceled(event, event_tick)

func on_ability_accepted(ack: Proto.AbilityUseAccepted) -> void:
	_ability_presentation.confirm_ability_started(
			StringName(ack.get_ability_id()),
			ack.get_requested_tick())

func on_ability_rejected(rejection: Proto.AbilityUseRejected) -> void:
	_ability_presentation.reject_ability_started(
			StringName(rejection.get_ability_id()),
			rejection.get_requested_tick(),
			rejection.get_cancel_reason())

func on_entity_position_diff(entity: Proto.EntityPosition, tick: int) -> void:
	if frozen:
		return

	var server_pos := Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	var server_vel := Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())
	var server_rot: float = entity.get_rot_y()

	_csp.setPendingServerTick(tick, server_pos, server_vel, server_rot)

func freeze() -> void:
	print("[CLIENT] Player frozen")
	frozen = true
	_body.velocity = Vector3.ZERO
	_visual.Body = null # Stop the visual smoother.
	_csp._input_history.clear()
	_csp._pending_server_tick = -1
	_input_batcher.clear()

func unfreeze() -> void:
	print("[CLIENT] Player unfrozen")
	frozen = false
	_visual.Body = _body # Re-enable the visual smoother.

func setCharacterModel(name) -> void:
	var model = (load("res://assets/entities/character_models/%s.tscn" % name)).instantiate()
	
	# Check for existing model
	var currentModel = _visual.get_node_or_null("BaseCharacter")
	if currentModel:
		currentModel.queue_free()
	
	print("Setting character model to res://assets/entities/character_models/%s.tscn" % name)
	_visual.add_child(model)

	# These models start at 0,0,0 and grow upward, while the collision capsule is *centered* at
	# 0,0,0. So offset the y position accordingly so we're not floating in the air.
	model.position.y = -1 

	# Connect the AnimationTree to the Body (must be relative path from the AnimationTree node)
	var anim_tree: AnimationTree = model.get_node("%AnimationTree") as AnimationTree
	anim_tree.advance_expression_base_node = anim_tree.get_path_to(_body)
	anim_tree.active = true
	
	_animationTree = anim_tree
	_animationPlayer = model.get_node("%AnimationPlayer") as AnimationPlayer
