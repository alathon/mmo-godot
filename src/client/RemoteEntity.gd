class_name RemoteEntity
extends Node3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _interpolator: RemoteInterpolator = %RemoteInterpolator
@onready var _ability_presentation: Node = %AbilityPresentation
@onready var stats: Stats = %Stats

var id: int

# Mimic CharacterBody3D-exposed things
var velocity: Vector3 = Vector3.ZERO
var _is_on_floor: bool = true
func is_on_floor() -> bool:
	return _is_on_floor

var face_angle: float:
	set(value):
		face_angle = value
		rotation.y = value

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer

# Server data
var _last_server_tick_received: int = -1
var _last_server_tick_processed: int = -1
var _last_server_pos: Vector3
var _last_server_rot: float


func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func initialize_position(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y

func apply_world_state(state: Proto.EntityState) -> void:
	if stats != null:
		stats.apply_world_state(state)

func on_ability_started(event) -> void:
	_ability_presentation.on_authoritative_ability_started(event)

func on_ability_completed(event) -> void:
	_ability_presentation.on_authoritative_ability_completed(event)

func on_ability_canceled(event) -> void:
	_ability_presentation.on_authoritative_ability_canceled(event)

func setCharacterModel(model_name: String) -> void:
	var model = (load("res://assets/entities/character_models/%s.tscn" % model_name)).instantiate()

	add_child(model)
	model.position.y = -1

	var anim_tree: AnimationTree = model.get_node("%AnimationTree") as AnimationTree
	anim_tree.advance_expression_base_node = anim_tree.get_path_to(self)
	anim_tree.active = true

	_animationTree = anim_tree
	_animationPlayer = model.get_node("%AnimationPlayer") as AnimationPlayer

	# Enable _process now that we have animations to drive
	set_process(true)

func on_entity_position_diff(entity: Proto.EntityPosition, tick: int) -> void:
	_last_server_tick_received = tick

	_last_server_pos = Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	_last_server_rot = entity.get_rot_y()

	var server_vel = Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())

	_interpolator.push_snapshot(tick, {
		"global_position": _last_server_pos,
		"face_angle": _last_server_rot,
		"velocity": server_vel,
		"_is_on_floor": entity.get_is_on_floor(),
	})

func _on_before_tick_loop(tick: int) -> void:
	if _last_server_tick_received == -1 or _last_server_tick_processed == _last_server_tick_received:
		return

	_last_server_tick_processed = _last_server_tick_received
