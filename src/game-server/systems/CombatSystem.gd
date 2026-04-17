class_name CombatSystem
extends Node

var _zone: Node = null
var _targeting: CombatTargeting = null
var _pending_events: Array[EntityEvents] = []


func init(zone: Node) -> void:
	_zone = zone
	_targeting = CombatTargeting.new()
	_targeting.init(_zone)


func tick(sim_tick: int, ctx: Dictionary) -> void:
	var context: AbilityExecutionContext = ctx.get("ability_execution_context", null)
	if context == null:
		return
	for completed_use in ctx.get("completed_ability_uses", []):
		_append_events(_resolve_completed_ability_use(completed_use, context))


func get_combat_manager(entity_id: int) -> CombatManager:
	var entity := _get_entity(entity_id)
	if entity is ServerPlayer:
		return (entity as ServerPlayer).combat_manager
	return null


func get_entity_id(entity: Node) -> int:
	if _zone == null or entity == null:
		return 0
	for entity_id in _zone.players:
		if _zone.players[entity_id] == entity:
			return entity_id
	return 0


func add_healing_aggro(
		healer_entity: Node,
		healed_entity: Node,
		threat_amount: float,
		sim_tick: int) -> void:
	if healer_entity == null or healed_entity == null or threat_amount <= 0.0:
		return
	for combat_manager in _get_combat_managers():
		if combat_manager.entity == healer_entity:
			continue
		if combat_manager.hostility != null and combat_manager.hostility.has_aggro_for(healed_entity):
			combat_manager.hostility.add_aggro(healer_entity, threat_amount)
			combat_manager.enter_combat(healer_entity, sim_tick)
			var healer_manager := _get_combat_manager_for_entity(healer_entity)
			if healer_manager != null:
				healer_manager.enter_combat(combat_manager.entity, sim_tick)


func clear_combat_for_entity(entity: Node, sim_tick: int) -> void:
	if entity == null:
		return
	var entity_manager := _get_combat_manager_for_entity(entity)
	if entity_manager != null:
		entity_manager.leave_combat(sim_tick)
	for combat_manager in _get_combat_managers():
		if combat_manager.hostility != null:
			combat_manager.hostility.clear_aggro(entity)
		if combat_manager.hostility == null or not combat_manager.hostility.has_aggro():
			combat_manager.leave_combat(sim_tick)


func is_valid_combat_target(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource) -> bool:
	if _targeting == null:
		return false
	return _targeting.is_valid_combat_target(source_entity, target_entity, ability)


func is_in_combat_range(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	if _targeting == null:
		return false
	return _targeting.is_in_combat_range(source_entity, target_entity, ability)


func on_ability_resolved(
		source_entity: Node,
		ability: AbilityResource,
		target_entities: Array[Node],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if source_entity == null or ability == null:
		return []
	var source_manager := _get_combat_manager_for_entity(source_entity)
	if source_manager == null:
		return []
	var events := source_manager.on_ability_landed(source_entity, target_entities, ability, [], context)
	_update_combat_engagement(source_entity, target_entities, events, context)
	return events


func resolve_damage(effect: AbilityEffect, ability: AbilityResource, source_stats: Dictionary) -> int:
	if not effect is DamageEffect:
		return 0
	var damage_effect := effect as DamageEffect
	if damage_effect.formula == null:
		return 0
	return maxi(0, int(round(damage_effect.formula.evaluate(source_stats))))


func resolve_heal(effect: AbilityEffect, ability: AbilityResource, source_stats: Dictionary) -> int:
	if not effect is HealEffect:
		return 0
	var heal_effect := effect as HealEffect
	if heal_effect.formula == null:
		return 0
	return maxi(0, int(round(heal_effect.formula.evaluate(source_stats))))


func resolve_hit(ability: AbilityResource, source_stats: Dictionary, target_stats: Stats) -> int:
	return 0


func did_hit(hit_result: int) -> bool:
	return hit_result == 0 or hit_result == 3 or hit_result == 4 or hit_result == 5


func has_events() -> bool:
	return _pending_events.size() > 0


func build_entity_events_proto(world_state_msg, sim_tick: int) -> void:
	EntityEventCodec.write_events(world_state_msg, _pending_events, sim_tick)
	_pending_events.clear()


func _append_events(events: Array[EntityEvents]) -> void:
	_pending_events.append_array(events)


func _check_deaths(
		source_entity: Node,
		target_entities: Array[Node],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	var events: Array[EntityEvents] = []
	var killer_entity_id := get_entity_id(source_entity)
	for target_entity in target_entities:
		var manager := _get_combat_manager_for_entity(target_entity)
		if manager != null and not manager.is_alive():
			events.append(EntityEvents.combatant_died(get_entity_id(target_entity), killer_entity_id))
	return events


func _update_combat_engagement(
		source_entity: Node,
		target_entities: Array[Node],
		events: Array[EntityEvents],
		context: AbilityExecutionContext) -> void:
	if context == null:
		return
	var source_manager := _get_combat_manager_for_entity(source_entity)
	if source_manager != null:
		source_manager.enter_combat(source_entity, context.sim_tick)
	for target_entity in target_entities:
		var target_manager := _get_combat_manager_for_entity(target_entity)
		if target_manager != null:
			target_manager.enter_combat(source_entity, context.sim_tick)


func _get_entity(entity_id: int) -> Node:
	if _zone == null:
		return null
	return _zone.players.get(entity_id, null)


func _get_combat_manager_for_entity(entity: Node) -> CombatManager:
	if entity is ServerPlayer:
		return (entity as ServerPlayer).combat_manager
	return null


func _get_combat_managers() -> Array[CombatManager]:
	var managers: Array[CombatManager] = []
	if _zone == null:
		return managers
	for entity_id in _zone.players:
		var player := _zone.players[entity_id] as ServerPlayer
		if player != null and player.combat_manager != null:
			managers.append(player.combat_manager)
	return managers


func _resolve_completed_ability_use(
		completed_use: CompletedAbilityUse,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if completed_use == null or context == null or context.ability_db == null:
		return []

	var source_entity := _get_entity(completed_use.source_entity_id)
	if source_entity == null:
		return []

	var ability := context.ability_db.get_ability(completed_use.ability_id)
	if ability == null:
		return []

	var target_entities: Array[Node] = []
	if context.ability_system != null:
		target_entities = context.ability_system.resolve_targets(
				source_entity,
				ability,
				completed_use.target)

	return on_ability_resolved(source_entity, ability, target_entities, context)
