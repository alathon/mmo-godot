class_name ServerPlayer
extends Node

@onready var body: PhysicsBody = %Body

@onready var ability_manager: AbilityManager = %AbilityManager
@onready var combat_manager: CombatManager = %CombatManager
@onready var hostility: Node = %DetermineHostility
@onready var target_state: EntityTargetState = %EntityTarget
@onready var stats: Stats = %Stats
@onready var input_state: PlayerInputState = $PlayerInputState

func set_target_entity_id(entity_id: int) -> void:
	target_state.set_target_entity_id(entity_id)

func get_target_entity_id() -> int:
	return target_state.get_target_entity_id()

func clear_target() -> void:
	target_state.clear_target()
