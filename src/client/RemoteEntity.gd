class_name RemoteEntity
extends Node3D

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _interpolator: RemoteInterpolator = %RemoteInterpolator
@onready var _visual: RemoteVisualSmoother = %VisualSmoother

var last_server_tick_received: int = -1
var last_server_tick_processed: int = -1

var last_server_pos: Vector3
var last_server_rot: float

var id: int

# Animation-related state
var velocity: Vector3 = Vector3.ZERO
#var _prev_position: Vector3  # Used by position-delta velocity approach
var _is_on_floor: bool = true

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer

func is_on_floor() -> bool:
	return _is_on_floor

func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	_visual.top_level = true
	#_interpolator._debug = true
	#_prev_position = global_position  # Used by position-delta velocity approach
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)

func initialize_position(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y
	_visual.global_position = pos
	_visual.face_angle = rot_y
	#_prev_position = pos  # Used by position-delta velocity approach

func _process(_delta: float) -> void:
	# Server velocity approach: read interpolated velocity from the visual smoother
	velocity = _visual.server_velocity
	_is_on_floor = _visual.is_on_floor

	## Position-delta velocity approach (commented out):
	#if delta > 0:
	#	velocity = (_visual.global_position - _prev_position) / delta
	#	if _is_on_floor:
	#		velocity.y = 0.0
	#	_prev_position = _visual.global_position

func setCharacterModel(model_name: String) -> void:
	var model = (load("res://assets/entities/character_models/%s.tscn" % model_name)).instantiate()

	_visual.add_child(model)
	model.position.y = -1

	var anim_tree: AnimationTree = model.get_node("%AnimationTree") as AnimationTree
	anim_tree.advance_expression_base_node = anim_tree.get_path_to(self)
	anim_tree.active = true

	_animationTree = anim_tree
	_animationPlayer = model.get_node("%AnimationPlayer") as AnimationPlayer

	# Enable _process now that we have animations to drive
	set_process(true)

func on_entity_position_diff(entity: Proto.EntityPosition, tick: int) -> void:
	last_server_tick_received = tick

	last_server_pos = Vector3(entity.get_pos_x(), entity.get_pos_y(), entity.get_pos_z())
	last_server_rot = entity.get_rot_y()

	var server_vel = Vector3(entity.get_vel_x(), entity.get_vel_y(), entity.get_vel_z())

	_interpolator.push_snapshot(tick, {
		"global_position": last_server_pos,
		"face_angle": last_server_rot,
		"server_velocity": server_vel,
		"is_on_floor": entity.get_is_on_floor(),
	})

func _on_before_tick_loop(tick: int) -> void:
	if last_server_tick_received == -1 or last_server_tick_processed == last_server_tick_received:
		return

	last_server_tick_processed = last_server_tick_received
