class_name RemoteEntityOld
extends Entity

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _visual: RemoteEntityBody = %Visual
@onready var _interpolator: RemoteInterpolator = %RemoteInterpolator
@onready var stats: Stats = %Stats
@onready var _hp_bar: HealthBar = $Visual/UIAnchor/HealthBar

var velocity: Vector3:
	get:
		return _visual.velocity if _visual != null else Vector3.ZERO
	set(value):
		if _visual != null:
			_visual.velocity = value

# Server data
var _last_server_tick_received: int = -1
var _last_server_tick_processed: int = -1
var _last_server_pos: Vector3
var _last_server_rot: float

func is_on_floor() -> bool:
	return _visual != null and _visual.is_on_floor()

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer




func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	NetworkTime.before_tick_loop.connect(_on_before_tick_loop)
	if stats != null and _hp_bar != null:
		_hp_bar.set_values(stats.hp, stats.max_hp)


func _get_face_angle() -> float:
	return _visual.face_angle if _visual != null else 0.0


func _set_face_angle(value: float) -> void:
	if _visual != null:
		_visual.face_angle = value


func initialize_position(pos: Vector3, rot_y: float) -> void:
	if _visual == null:
		return
	_visual.global_position = pos
	face_angle = rot_y

func apply_world_state(state: Proto.ServerEntityState) -> void:
	if stats != null:
		stats.apply_world_state(state)
		if _hp_bar != null:
			_hp_bar.set_values(stats.hp, stats.max_hp)


func setCharacterModel(model_name: String) -> void:
	var model = (load("res://assets/entities/character_models/%s.tscn" % model_name)).instantiate()

	_visual.add_child(model)
	model.position.y = -1

	var anim_tree: AnimationTree = model.get_node("%AnimationTree") as AnimationTree
	anim_tree.advance_expression_base_node = anim_tree.get_path_to(_visual)
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
