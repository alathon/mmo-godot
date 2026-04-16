class_name CombatSystem
extends Node

var _zone: Node = null
var _targeting: CombatTargeting = null
var _pending_events: Array[EntityEvents] = []


func init(zone: Node) -> void:
	pass


func tick(sim_tick: int, ctx: Dictionary) -> void:
	pass


func get_combat_manager(entity_id: int) -> CombatManager:
	return null


func is_valid_combat_target(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource) -> bool:
	return false


func is_in_combat_range(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	return false


func on_ability_resolved(
		source_entity: Node,
		ability: AbilityResource,
		target_entities: Array[Node],
		ability_events: Array[EntityEvents],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func resolve_damage(effect: AbilityEffect, ability: AbilityResource, source_stats: Dictionary) -> int:
	return 0


func resolve_heal(effect: AbilityEffect, ability: AbilityResource, source_stats: Dictionary) -> int:
	return 0


func resolve_hit(ability: AbilityResource, source_stats: Dictionary, target_stats: Stats) -> int:
	return 0


func did_hit(hit_result: int) -> bool:
	return false


func has_events() -> bool:
	return false


func build_combat_events_proto(combat_events_msg, sim_tick: int) -> void:
	pass


func _append_events(events: Array[EntityEvents]) -> void:
	pass


func _check_deaths(
		source_entity: Node,
		target_entities: Array[Node],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _update_combat_engagement(
		source_entity: Node,
		target_entities: Array[Node],
		events: Array[EntityEvents],
		context: AbilityExecutionContext) -> void:
	pass


func _get_entity(entity_id: int) -> Node:
	return null
