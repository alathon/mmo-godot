class_name EntityState
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

signal target_changed(target: Node)

@onready var _general_stats: GeneralStats = %GeneralStats
@onready var _class_stats: ClassStats = %ClassStats
@onready var _race_stats: RaceStats = %RaceStats
@onready var _aggro_state: AggroState = %AggroState
@onready var _ability_state: AbilityState = %AbilityState

var in_combat = true:
	set = set_in_combat	

var current_target: Node:
	set = set_target

var is_npc = true

var ability_state: AbilityState:
	get:
		return _ability_state

var aggro_state: AggroState:
	get:
		return _aggro_state

var general_stats: GeneralStats:
	get:
		return _general_stats

func is_alive() -> bool:
	return _general_stats.hp > 0

func is_attackable_by(target) -> bool:
	if is_npc:
		return true
	
	return false

# kos = kill on sight
func is_kos(target) -> bool:
	if _aggro_state != null and is_npc:
		if _aggro_state.is_on_aggro_list(target):
			return true
	
	# TODO: Some kind of faction/other stuff determining hostility/kill on sight or not
	return true

func set_in_combat(value: bool):
	in_combat = value

func set_target(node: Node):
	if current_target != node:
		current_target = node
		target_changed.emit(node)

func clear_target():
	set_target(null)

func has_target():
	return current_target != null

func get_target_id() -> int:
	return current_target.id if current_target != null else -1

func has_resources_for(ability: AbilityResource) -> bool:
	if ability == null or _general_stats == null:
		return false
	return _general_stats.mana >= ability.mana_cost


func spend_resources_for(ability: AbilityResource) -> void:
	if ability == null or _general_stats == null:
		return
	_general_stats.mana = maxi(0, _general_stats.mana - ability.mana_cost)

func tick_runtime(delta: float) -> void:
	_ability_state.tick_time(delta)
	var cooldowns = get_parent().get_node_or_null("%Cooldowns") if get_parent() != null else null
	if cooldowns != null and cooldowns.has_method("tick"):
		cooldowns.tick(delta)

func apply_entity_event(event: EntityEvents, event_tick: int) -> void:
	if event == null:
		return

	match event.type:
		EntityEvents.Type.ABILITY_USE_STARTED:
			var ability := AbilityDB.get_ability(event.ability_id)
			if ability == null:
				return
			_ability_state.start_cast_from_ability(
					event.request_id,
					ability,
					_target_spec_from_event(event),
					event_tick)
		EntityEvents.Type.ABILITY_USE_FINISHED:
			_ability_state.finish_cast(event.request_id)
		EntityEvents.Type.ABILITY_USE_IMPACT:
			_ability_state.mark_impact_emitted(event.request_id)
			_ability_state.clear_cast(event.request_id)
		EntityEvents.Type.ABILITY_USE_CANCELED:
			_ability_state.clear_cast(event.request_id)
			_ability_state.clear_queue(event.request_id)

func apply_ability_resolved(resolved: Proto.AbilityUseResolved) -> void:
	if resolved == null:
		return
	_ability_state.resolve_current_cast(resolved, resolved.get_resolve_tick())

func on_world_state(state: Proto.ServerEntityState):
	_general_stats.hp = state.get_hp()
	_general_stats.max_hp = state.get_max_hp()
	_general_stats.mana = state.get_mana()
	_general_stats.max_mana = state.get_max_mana()
	_general_stats.stamina = state.get_stamina()
	_general_stats.max_stamina = state.get_max_stamina()

func _target_spec_from_event(event: EntityEvents) -> AbilityTargetSpec:
	if event.target_entity_id > 0:
		return AbilityTargetSpec.entity(event.target_entity_id)
	if event.ground_position != Vector3.ZERO:
		return AbilityTargetSpec.ground(event.ground_position)
	return null
