class_name GroundTargetingMode
extends Node

signal target_confirmed(ability_id: int, target: AbilityTargetSpec)

@onready var _camera: Camera3D = $/root/Root/CameraPivot/SpringArm3D/Camera
@onready var _input_source: LocalInput = %LocalInput
@onready var _world_input_service: WorldInputService = %WorldInputService
@onready var _game_manager: GameManager = %GameManager

var active: bool = false
var _ability_id: int = 0
var _preview: GroundTargetPreview = null
var _local_ability_controller: LocalAbilityController = null


func _ready() -> void:
	_ensure_preview()
	_game_manager.local_player_spawned.connect(_on_local_player_spawned)


func _process(_delta: float) -> void:
	if not active:
		return

	_update_preview(_get_targeting_screen_position())

func activate(ability_id: int) -> bool:
	if not _can_begin_ground_targeting(ability_id):
		return false
	active = true
	_ability_id = ability_id
	_configure_preview(ability_id)
	print("[CLIENT] Entering ground targeting mode for ability %d" % ability_id)
	return true

func deactivate() -> void:
	if active:
		print("[CLIENT] Leaving ground targeting mode")
	active = false
	_ability_id = 0
	if _preview != null:
		_preview.hide_preview()

func is_active() -> bool:
	return active

func is_active_for(ability_id: int) -> bool:
	return active and _ability_id == ability_id

func get_ability_id() -> int:
	return _ability_id


func set_input_source(input_source: LocalInput) -> void:
	_input_source = input_source

func _on_local_player_spawned(player: Player) -> void:
	_local_ability_controller = player.local_ability_controller

func capture_primary_click(screen_position: Vector2) -> bool:
	if not active:
		return false
	confirm_at_screen_position(screen_position)
	return true

func confirm_at_cursor() -> AbilityTargetSpec:
	if not active:
		return null
	return confirm_at_screen_position(_get_targeting_screen_position())

func confirm_at_screen_position(screen_position: Vector2) -> AbilityTargetSpec:
	if not active:
		return null

	var target: AbilityTargetSpec = _build_ground_target_spec(screen_position)
	if target == null:
		print("[CLIENT] Ground targeting did not hit valid ground")
		return null

	target_confirmed.emit(_ability_id, target)
	return target

func consume_target_spec(input: Dictionary) -> AbilityTargetSpec:
	if not active:
		return null
	if not bool(input.get("primary_click_pressed", false)):
		return null
	return _build_ground_target_spec(input.get("primary_click_position", Vector2.ZERO) as Vector2)

func build_target_spec_at_cursor() -> AbilityTargetSpec:
	if not active:
		return null
	return _build_ground_target_spec(_get_targeting_screen_position())

func _build_ground_target_spec(screen_position: Vector2) -> AbilityTargetSpec:
	var ground_position = _raycast_ground_position(screen_position)
	if ground_position == null:
		return null
	return AbilityTargetSpec.ground(ground_position)

func _raycast_ground_position(screen_position: Vector2):
	if _camera == null:
		return null

	var origin: Vector3 = _camera.project_ray_origin(screen_position)
	var direction: Vector3 = _camera.project_ray_normal(screen_position)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 10000.0
	)
	query.collision_mask = 1 << 1 # only layer 2

	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	return hit.position


func _configure_preview(ability_id: int) -> void:
	_ensure_preview()
	if _preview == null:
		return

	var ability: AbilityResource = AbilityDB.get_ability(ability_id)
	_preview.configure(ability)
	_update_preview(_get_targeting_screen_position())


func _can_begin_ground_targeting(ability_id: int) -> bool:
	if _local_ability_controller == null:
		return false
	var validation: AbilityValidationResult = _local_ability_controller.can_begin_ground_targeting(
			ability_id,
			NetworkTime.tick)
	return validation.ok


func _update_preview(screen_position: Vector2) -> void:
	if _preview == null:
		return

	var ground_position = _raycast_ground_position(screen_position)
	if ground_position == null:
		_preview.hide_preview()
		return

	_preview.set_target_position(ground_position)


func _ensure_preview() -> void:
	if _preview != null:
		return

	_preview = GroundTargetPreview.new()
	_preview.name = "GroundTargetPreview"
	add_child(_preview)


func _get_targeting_screen_position() -> Vector2:
	if _world_input_service != null:
		return _world_input_service.get_targeting_screen_position()
	return get_viewport().get_mouse_position()
