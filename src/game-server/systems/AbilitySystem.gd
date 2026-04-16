class_name AbilitySystem
extends Node

@onready var _zone: ServerZone = get_owner()
@onready var _combat_system: CombatSystem = %CombatSystem
var _targeting: RefCounted = null
var _pending_events: Array[EntityEvents] = []
var _ack_queue: Array = []


func init(zone: Node, combat_system: CombatSystem) -> void:
	pass


func tick(sim_tick: int, ctx: Dictionary) -> void:
	pass


func handle_ability_input(entity_id: int, input: Dictionary, sim_tick: int) -> void:
	pass


func has_events() -> bool:
	return false


func build_ability_events_proto(ability_events_msg, sim_tick: int) -> void:
	pass


func get_entity(entity_id: int) -> Node:
	return null


func get_ability_manager(entity_id: int) -> AbilityManager:
	return null


func resolve_targets(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec) -> Array[Node]:
	return []


func is_in_range(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	return false


func _process_movement_cancels(moving_entities: Dictionary, sim_tick: int) -> void:
	pass


func _process_ability_inputs(ability_inputs: Dictionary, sim_tick: int) -> void:
	pass


func _tick_ability_managers(sim_tick: int) -> void:
	pass


func _flush_ack_queue() -> void:
	pass


func _make_execution_context(sim_tick: int) -> AbilityExecutionContext:
	return null


func _enqueue_ack(result: AbilityUseResult) -> void:
	pass


func _append_events(events: Array[EntityEvents]) -> void:
	pass


func _dispatch_resolved_ability(
		source_entity: Node,
		ability: AbilityResource,
		target_entities: Array[Node],
		ability_events: Array[EntityEvents],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []
