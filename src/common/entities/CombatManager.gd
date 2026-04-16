class_name CombatManager
extends Node

@onready var stats: Stats = %Stats
@onready var entity: Node = get_parent()

var combat_started_tick: int = 0
var last_combat_event_tick: int = 0


func init(owner_entity: Node) -> void:
	pass


func is_in_combat() -> bool:
	return false


func enter_combat(source_entity: Node, sim_tick: int) -> void:
	pass


func leave_combat(sim_tick: int) -> void:
	pass


func can_target(
		target_entity: Node,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> AbilityValidationResult:
	return AbilityValidationResult.new()


func is_hostile_to(target_entity: Node) -> bool:
	return false


func is_friendly_to(target_entity: Node) -> bool:
	return false


func is_alive() -> bool:
	return false


func on_ability_landed(
		source_entity: Node,
		target_entities: Array[Node],
		ability: AbilityResource,
		events: Array[EntityEvents],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func _apply_effect(
		source_entity: Node,
		target_entities: Array[Node],
		ability: AbilityResource,
		effect: AbilityEffect,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	return []


func on_damage_dealt(
		target_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> void:
	pass


func on_damage_taken(
		source_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> void:
	pass


func on_healing_done(
		target_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> void:
	pass


func on_combatant_died(killer_entity: Node, context: AbilityExecutionContext) -> EntityEvents:
	return null
