class_name WorldInputService
extends Node

const TARGETABLE_COLLISION_MASK := 1 << 2 # layer 3

@onready var _game_manager: GameManager = %GameManager
@onready var _api: BackendAPI = %BackendAPI
@onready var _ground_targeting_mode: GroundTargetingMode = %GroundTargetingMode
@onready var _camera: Camera3D = $/root/Root/CameraPivot/SpringArm3D/Camera

var _local_player: Player = null
var _virtual_mouse_active: bool = false
var _virtual_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_game_manager.local_player_spawned.connect(_on_local_player_spawned)


func _on_local_player_spawned(player: Player) -> void:
	_local_player = player


func handle_primary_click(screen_position: Vector2) -> void:
	if _local_player == null:
		return

	# Ground targeting consumes the click entirely and should ignore
	# entities or future interactables.
	if _ground_targeting_mode.capture_primary_click(screen_position):
		return

	select_target_at_screen_position(screen_position)


func handle_secondary_click(_screen_position: Vector2) -> void:
	if _ground_targeting_mode.is_active():
		_ground_targeting_mode.deactivate()
		return


func begin_virtual_mouse(screen_position: Vector2) -> void:
	_virtual_mouse_active = true
	_virtual_mouse_position = _clamp_to_viewport(screen_position)


func update_virtual_mouse(relative: Vector2) -> void:
	if not _virtual_mouse_active:
		return
	_virtual_mouse_position = _clamp_to_viewport(_virtual_mouse_position + relative)


func end_virtual_mouse() -> void:
	_virtual_mouse_active = false


func get_targeting_screen_position() -> Vector2:
	if _virtual_mouse_active:
		return _virtual_mouse_position
	return get_viewport().get_mouse_position()


func select_target_at_screen_position(screen_position: Vector2) -> void:
	select_target(_pick_target_at_screen_position(screen_position))


func select_target_by_id(entity_id: int) -> void:
	var target = _game_manager.get_entity_by_id(entity_id) if entity_id > 0 else null
	select_target(target)


func select_target(target: Node) -> void:
	if _local_player == null:
		return

	_local_player.entity_state.set_target(target)
	var target_id: int = _local_player.entity_state.get_target_id()
	_api.send_target_select(maxi(target_id, 0))


func clear_target() -> void:
	select_target(null)


func _pick_target_at_screen_position(screen_position: Vector2) -> Node:
	if _camera == null:
		return null

	var origin: Vector3 = _camera.project_ray_origin(screen_position)
	var direction: Vector3 = _camera.project_ray_normal(screen_position)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin,
			origin + direction * 10000.0)
	query.collision_mask = TARGETABLE_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider", null)
	if not collider is Node:
		return null

	return _resolve_target_entity(collider as Node)

# TODO: The below sucks, we don't have to crawl up through parents like this.
func _resolve_target_entity(node: Node) -> Node:
	return node.owner

	# var current := node
	# while current != null:
	# 	if current == _local_player:
	# 		return null
	# 	if current.has_node("%EntityState"):
	# 		return current
	# 	current = current.get_parent()
	# return null


func _clamp_to_viewport(screen_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
			clampf(screen_position.x, 0.0, viewport_size.x),
			clampf(screen_position.y, 0.0, viewport_size.y))
