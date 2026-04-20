class_name Player
extends SimulatedEntity

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _body: CharacterBody3D = %Body
@onready var _csp: CSP = %CSP
@onready var _input_source: LocalInput = %LocalInput
@onready var _input_batcher: InputBatcher = %InputBatcher
@onready var _ground_targeting_mode: GroundTargetingMode = %GroundTargetingMode
@onready var _visual: VisualSmoother = %VisualSmoother
@onready var _ability_event_controller: AbilityEventController = %AbilityEventController
@onready var _hp_bar: HealthBar = %HealthBar as HealthBar
@onready var _game_manager: GameManager = $/root/Root/Services/GameManager

var _animationTree: AnimationTree
var _animationPlayer: AnimationPlayer
var _debug: bool = false
var _predicted_ability_ids_by_request: Dictionary = {}
var _pending_local_impacts: Array = []

var frozen: bool = true

func _get_face_angle() -> float:
	return _body.face_angle


func _set_face_angle(value: float) -> void:
	_body.face_angle = value

func apply_world_state(state: Proto.EntityState) -> void:
	if stats != null:
		stats.apply_world_state(state)
		if _hp_bar != null:
			_hp_bar.set_values(stats.hp, stats.max_hp)

func _ready() -> void:
	NetworkTime.on_tick.connect(_on_network_tick)
	if stats != null and _hp_bar != null:
		_hp_bar.set_values(stats.hp, stats.max_hp)

func _on_network_tick(delta: float, current_tick: int) -> void:
	if frozen:
		return

	# Gather input
	var input = _input_source.getInput()
	var ability_context := _make_ability_context(delta, current_tick)

	# Apply movement input
	_body.simulate(input, delta)

	var ability_attempt := _process_ability_input(current_tick, ability_context, input)
	if ability_attempt != null and ability_attempt.accepted:
		_predicted_ability_ids_by_request[ability_attempt.request_id] = ability_attempt.ability_id
		_ability_event_controller.add_local_request(
				ability_attempt.request_id,
				id,
				ability_attempt.ability_id,
				ability_attempt.requested_tick)
		_apply_predicted_use_result(ability_attempt)

	var predicted_events := ability_manager.tick(ability_context)
	_apply_predicted_ability_events(predicted_events, current_tick)
	_apply_predicted_ability_events(_consume_pending_local_impacts(current_tick), current_tick)

	# Client-side post-tick stuff.
	_csp.setInputAt(current_tick, input)
	_csp.setPredictionAt(current_tick, { "global_position" = _body.global_position })

	# Batch input for server send.
	_input_batcher.queue_input(
			input["input_x"],
			input["input_z"],
			input["jump_pressed"],
			_body.rotation.y,
			current_tick,
			ability_attempt.ability_id if ability_attempt != null and ability_attempt.accepted else 0,
			ability_attempt.get_target_entity_id() if ability_attempt != null and ability_attempt.accepted else 0,
			ability_attempt.get_ground_position() if ability_attempt != null and ability_attempt.accepted else Vector3.ZERO,
			ability_attempt.request_id if ability_attempt != null and ability_attempt.accepted else 0)

func on_ability_started(event, event_tick: int) -> void:
	_ability_event_controller.on_ability_started(event, event_tick)

func on_ability_finished(event, event_tick: int) -> void:
	_ability_event_controller.on_ability_finished(event, event_tick)

func on_ability_impact(event, event_tick: int) -> void:
	_ability_event_controller.on_ability_impact(event, event_tick)

func on_ability_canceled(event, event_tick: int) -> void:
	_remove_pending_local_impact(_event_request_id(event))
	_ability_event_controller.on_ability_canceled(event, event_tick)

func on_ability_accepted(ack: Proto.AbilityUseAccepted) -> void:
	if ack == null:
		return
	if not _predicted_ability_ids_by_request.has(ack.get_request_id()):
		return

func on_ability_rejected(rejection: Proto.AbilityUseRejected) -> void:
	if rejection == null:
		return
	var rollback_events := ability_manager.reject_request(
			rejection.get_request_id(),
			rejection.get_cancel_reason(),
			_make_ability_context(0.0, NetworkTime.tick))
	_predicted_ability_ids_by_request.erase(rejection.get_request_id())
	_apply_predicted_ability_events(rollback_events, NetworkTime.tick)

func get_predicted_ability_id_for_request(request_id: int) -> int:
	return int(_predicted_ability_ids_by_request.get(request_id, 0))


func get_ability_event_controller() -> AbilityEventController:
	return _ability_event_controller

func on_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	_ability_event_controller.on_ability_resolved(resolved)


func should_ignore_request_event(event, event_tick: int, consume: bool = false, log_decision: bool = false) -> bool:
	return _ability_event_controller.should_ignore_request_event(event, event_tick, consume, log_decision)

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
	_predicted_ability_ids_by_request.clear()
	_pending_local_impacts.clear()
	_ground_targeting_mode.deactivate()

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


func _make_ability_context(delta: float, current_tick: int) -> AbilityExecutionContext:
	var context := AbilityExecutionContext.new()
	context.sim_tick = current_tick
	context.source_entity_id = id
	context.delta = delta
	context.target_resolver = _game_manager
	return context


func _build_target_spec(target_entity_id: int) -> AbilityTargetSpec:
	if target_entity_id > 0:
		return AbilityTargetSpec.entity(target_entity_id)
	return null


func _apply_predicted_use_result(result: AbilityUseResult) -> void:
	if result == null or not result.accepted:
		return
	var event_tick := result.start_tick if result.start_tick > 0 else result.requested_tick
	_apply_predicted_ability_events(result.events, event_tick)


func _apply_predicted_ability_events(events: Array[EntityEvents], event_tick: int) -> void:
	for event in events:
		if event == null:
			continue
		match event.type:
			EntityEvents.Type.ABILITY_USE_STARTED:
				_ability_event_controller.on_ability_started(event, event_tick)
			EntityEvents.Type.ABILITY_USE_FINISHED:
				_queue_local_impact_for_finished_event(event)
				_ability_event_controller.on_ability_finished(event, event_tick)
			EntityEvents.Type.ABILITY_USE_IMPACT:
				_ability_event_controller.on_ability_impact(event, event_tick)
			EntityEvents.Type.ABILITY_USE_CANCELED:
				_remove_pending_local_impact(event.request_id)
				_ability_event_controller.on_ability_canceled(event, event_tick)


func _input_has_movement(input: Dictionary) -> bool:
	return absf(float(input.get("input_x", 0.0))) > 0.001 or absf(float(input.get("input_z", 0.0))) > 0.001


func capture_primary_click(screen_position: Vector2) -> bool:
	if _ground_targeting_mode == null:
		return false
	return _ground_targeting_mode.capture_primary_click(screen_position)


func _process_ability_input(
		current_tick: int,
		ability_context: AbilityExecutionContext,
		input: Dictionary) -> AbilityUseResult:
	if _ground_targeting_mode.is_active():
		var confirmed_target_spec := _ground_targeting_mode.consume_target_spec(input)
		if confirmed_target_spec != null:
			return _attempt_ground_targeted_ability_use(
					current_tick,
					_ground_targeting_mode.get_ability_id(),
					confirmed_target_spec,
					ability_context)

	var activated_ability_id := int(input.get("ability_id", 0))
	if activated_ability_id <= 0:
		return null

	var activated_ability := AbilityDB.get_ability(activated_ability_id)
	if activated_ability != null and activated_ability.target_type == AbilityResource.TargetType.GROUND:
		if _ground_targeting_mode.is_active_for(activated_ability_id):
			return _attempt_ground_targeted_ability_use(
					current_tick,
					activated_ability_id,
					_ground_targeting_mode.build_target_spec_at_cursor(),
					ability_context)
		_ground_targeting_mode.activate(activated_ability_id)
		return null

	if _ground_targeting_mode.is_active():
		_ground_targeting_mode.deactivate()

	return _attempt_ability_use(
			current_tick,
			activated_ability_id,
			_build_target_spec(get_target_entity_id()),
			ability_context)


func _attempt_ground_targeted_ability_use(
		current_tick: int,
		ability_id: int,
		target_spec: AbilityTargetSpec,
		ability_context: AbilityExecutionContext) -> AbilityUseResult:
	if target_spec == null:
		return null
	var result := _attempt_ability_use(current_tick, ability_id, target_spec, ability_context)
	if result != null and result.accepted:
		_ground_targeting_mode.deactivate()
	return result


func _attempt_ability_use(
		current_tick: int,
		ability_id: int,
		target_spec: AbilityTargetSpec,
		ability_context: AbilityExecutionContext) -> AbilityUseResult:
	var request_id := ability_manager.get_next_request_id()
	return ability_manager.use_ability(
			current_tick,
			request_id,
			ability_id,
			target_spec,
			ability_context)


func _queue_local_impact_for_finished_event(event: EntityEvents) -> void:
	if event == null or event.request_id <= 0:
		return
	var impact_tick := ability_manager.get_recent_request_impact_tick(event.request_id)
	if impact_tick <= 0:
		return
	_remove_pending_local_impact(event.request_id)
	_pending_local_impacts.append({
		"source_entity_id": event.source_entity_id,
		"ability_id": event.ability_id,
		"request_id": event.request_id,
		"impact_tick": impact_tick,
	})


func _consume_pending_local_impacts(current_tick: int) -> Array[EntityEvents]:
	if _pending_local_impacts.is_empty():
		return []
	var events: Array[EntityEvents] = []
	for index in range(_pending_local_impacts.size() - 1, -1, -1):
		var pending := _pending_local_impacts[index] as Dictionary
		if int(pending.get("impact_tick", 0)) > current_tick:
			continue
		events.append(EntityEvents.ability_impact(
				int(pending.get("source_entity_id", 0)),
				int(pending.get("ability_id", 0)),
				int(pending.get("request_id", 0))))
		_pending_local_impacts.remove_at(index)
	events.reverse()
	return events


func _remove_pending_local_impact(request_id: int) -> void:
	if request_id <= 0 or _pending_local_impacts.is_empty():
		return
	for index in range(_pending_local_impacts.size() - 1, -1, -1):
		var pending := _pending_local_impacts[index] as Dictionary
		if int(pending.get("request_id", 0)) == request_id:
			_pending_local_impacts.remove_at(index)


func _event_request_id(event) -> int:
	if event == null:
		return 0
	if event is EntityEvents:
		return event.request_id
	if event.has_method("get_request_id"):
		return int(event.get_request_id())
	return 0
