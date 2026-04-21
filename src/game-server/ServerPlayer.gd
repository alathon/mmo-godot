class_name ServerPlayer
extends Node

var id: int = 0
var face_angle: float:
	get:
		return body.face_angle
	set(value):
		body.face_angle = value

@onready var ability_manager: AbilityManager = %AbilityManager
@onready var combat_manager: CombatManager = %CombatManager
@onready var entity_state: EntityState = %EntityState
@onready var body: PhysicsBody = %Body
@onready var input_state: PlayerInputState = $PlayerInputState

var stats: GeneralStats:
	get:
		return entity_state.general_stats


func set_target_entity_id(entity_id: int) -> void:
	if entity_id <= 0:
		entity_state.clear_target()
		return
	entity_state.set_target(_get_server_zone().get_entity_by_id(entity_id))


func get_target_entity_id() -> int:
	return entity_state.get_target_id()


func clear_target() -> void:
	entity_state.clear_target()


func _get_server_zone() -> ServerZone:
	var node := get_parent()
	while node != null and not node is ServerZone:
		node = node.get_parent()
	return node as ServerZone
