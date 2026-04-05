class_name Player
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _body: CharacterBody3D = %Body
@onready var _csp: CSP = %CSP
@onready var _input_source: LocalInput = %LocalInput
@onready var _input_batcher: InputBatcher = %InputBatcher
@onready var _visual: VisualSmoother = %Visual

var frozen: bool = true
var id: int

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
	_input_batcher.queue_input(input["input_x"], input["input_z"], input["jump_pressed"], _body.rotation.y, current_tick)

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
