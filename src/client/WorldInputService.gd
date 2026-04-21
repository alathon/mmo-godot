class_name WorldInputService
extends Node

const TARGET_PICK_RADIUS_PX := 80.0
const TARGET_PICK_HEIGHT := 1.0

@onready var _game_manager: GameManager = %GameManager
@onready var _api: BackendAPI = %BackendAPI
@onready var _ground_targeting_mode: GroundTargetingMode = %GroundTargetingMode
@onready var _camera: Camera3D = $/root/Root/CameraPivot/SpringArm3D/Camera

var _local_player: PlayerNew = null

func _ready() -> void:
	_game_manager.local_player_spawned.connect(_on_local_player_spawned)


func _on_local_player_spawned(player: PlayerNew) -> void:
	_local_player = player


func handle_primary_click(screen_position: Vector2) -> void:
	if _local_player == null:
		return

	# Ground targeting consumes the click entirely and should ignore
	# entities or future interactables.
	if _ground_targeting_mode.capture_primary_click(screen_position):
		return

	select_target_at_screen_position(screen_position)


func select_target_at_screen_position(screen_position: Vector2) -> void:
	select_target(_pick_target_at_screen_position(screen_position))


func select_target_by_id(entity_id: int) -> void:
	var target := _game_manager.get_entity_by_id(entity_id) if entity_id > 0 else null
	select_target(target)


func select_target(target: Node) -> void:
	if _local_player == null:
		return

	_local_player.entity_state.set_target(target)
	var target_id := _local_player.entity_state.get_target_id()
	_api.send_target_select(maxi(target_id, 0))


func clear_target() -> void:
	select_target(null)


func _pick_target_at_screen_position(screen_position: Vector2) -> Node:
	if _camera == null:
		return null

	var nearest: Node = null
	var nearest_distance_sq := TARGET_PICK_RADIUS_PX * TARGET_PICK_RADIUS_PX
	for entity in _game_manager.get_remote_players():
		if entity == null or not is_instance_valid(entity):
			continue

		var model := entity.get_node_or_null("%Model") as Node3D
		if model == null:
			continue

		var target_position := model.global_position + Vector3.UP * TARGET_PICK_HEIGHT
		if _camera.is_position_behind(target_position):
			continue

		var entity_screen_position := _camera.unproject_position(target_position)
		var distance_sq := screen_position.distance_squared_to(entity_screen_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = entity

	return nearest
