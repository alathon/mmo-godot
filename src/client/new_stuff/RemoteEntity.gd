class_name RemoteEntity
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var body: RemoteBody = %Body
@onready var model: Node3D = %Model
@onready var _interpolator: RemoteInterpolator = %RemoteInterpolator
@onready var entity_state: EntityState = %EntityState
@onready var animation_controller = %CharacterAnimationController

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer

var id: int = -1

var frozen: bool = true:
	set = set_frozen

# Server data
var _last_server_tick_received: int = -1
var _last_server_tick_processed: int = -1
var _last_server_pos: Vector3
var _last_server_rot: float
var _last_server_vel: Vector3
var _last_server_is_on_floor: bool

func set_frozen(value: bool):
	frozen = value
	if frozen:
		body.velocity = Vector3.ZERO
		model.Body = null # Stop the visual smoother.
	else:
		model.Body = body

func set_character_model(name) -> void:
	var new_model = (load("res://assets/entities/character_models/%s.tscn" % name)).instantiate()

	# Check for existing model
	var current_model = model.get_node_or_null("BaseCharacter")
	if current_model:
		current_model.queue_free()

	print("Setting character model to res://assets/entities/character_models/%s.tscn" % name)
	model.add_child(new_model)

	# These models start at 0,0,0 and grow upward, while the collision capsule is *centered* at
	# 0,0,0. So offset the y position accordingly so we're not floating in the air.
	new_model.position.y = -1

	var anim_tree: AnimationTree = new_model.get_node("%AnimationTree") as AnimationTree
	_animationTree = anim_tree
	_animationPlayer = new_model.get_node("%AnimationPlayer") as AnimationPlayer
	animation_controller.bind_model(_animationTree, _animationPlayer, self)

func on_server_position(pos: Vector3, vel: Vector3, rot_y: float, is_on_floor: bool, tick: int):
	_last_server_tick_received = tick
	_last_server_pos = pos
	_last_server_rot = rot_y
	_last_server_is_on_floor = is_on_floor
	_last_server_vel = vel

	_interpolator.push_snapshot(tick, {
		"global_position": _last_server_pos,
		"face_angle": _last_server_rot,
		"velocity": _last_server_vel,
		"_is_on_floor": _last_server_is_on_floor,
	})

func apply_world_state(state: Proto.ServerEntityState):
	entity_state.on_world_state(state)

func on_ability_event(event: EntityEvents, event_tick: int) -> void:
	entity_state.apply_entity_event(event, event_tick)
	animation_controller.on_entity_event(event, event_tick)

func on_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	entity_state.apply_ability_resolved(resolved)
	animation_controller.on_ability_resolved(resolved)

func _on_before_tick_loop(tick: int) -> void:
	if _last_server_tick_received == -1 or _last_server_tick_processed == _last_server_tick_received:
		return

	_last_server_tick_processed = _last_server_tick_received

func initialize_position(pos: Vector3, rot_y: float) -> void:
	body.global_position = pos
	body.face_angle = rot_y
