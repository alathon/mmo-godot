class_name CombatSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _zone: Node = null
var _targeting: CombatTargeting = null
var _pending_events: Array[EntityEvents] = []
var _pending_uses: Array = []


func init(zone: Node) -> void:
	_zone = zone
	_targeting = CombatTargeting.new()
	_targeting.init(_zone)


func tick(sim_tick: int, ctx: Dictionary) -> void:
	var context: AbilityExecutionContext = ctx.get("ability_execution_context", null)
	if context == null:
		return
	_enqueue_scheduled_uses(ctx.get("scheduled_ability_uses", []))
	_process_scheduled_uses(sim_tick, context)


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


func get_entity(entity_id: int) -> Node:
	return _get_entity(entity_id)


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


func _enqueue_scheduled_uses(scheduled_uses: Array) -> void:
	for use in scheduled_uses:
		var scheduled_use := use as ScheduledAbilityUse
		if scheduled_use != null:
			_pending_uses.append(scheduled_use)


func _process_scheduled_uses(sim_tick: int, context: AbilityExecutionContext) -> void:
	var pending: Array = []
	for use in _pending_uses:
		if use.canceled:
			continue
		if not use.resolved and use.resolve_tick <= sim_tick:
			_resolve_scheduled_ability_use(use, context)
		if use.resolved and not use.early_applied and use.lock_tick <= sim_tick:
			_append_events(_apply_scheduled_ability_use(use, context, ResolvedAbilityEffectSnapshot.Phase.EARLY))
			use.early_applied = true
		if use.resolved and use.impact_tick <= sim_tick:
			_append_events(_apply_scheduled_ability_use(use, context, ResolvedAbilityEffectSnapshot.Phase.IMPACT))
		else:
			pending.append(use)
	_pending_uses = pending


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


func _resolve_scheduled_ability_use(
		use: ScheduledAbilityUse,
		context: AbilityExecutionContext) -> void:
	if use == null or context == null or context.ability_db == null:
		return

	var resolved_use := ResolvedAbilityUseSnapshot.from_scheduled_use(use)
	var source_entity := _get_entity(use.source_entity_id)
	if source_entity == null:
		use.resolved_use = resolved_use
		use.resolved = true
		_send_ability_resolved(resolved_use)
		return

	var ability := context.ability_db.get_ability(use.ability_id)
	if ability == null:
		use.resolved_use = resolved_use
		use.resolved = true
		_send_ability_resolved(resolved_use)
		return

	var target_entities: Array[Node] = []
	if context.ability_system != null and context.ability_system.is_in_range(source_entity, ability, use.target):
		target_entities = context.ability_system.resolve_targets(
				source_entity,
				ability,
				use.target)

	var source_manager := _get_combat_manager_for_entity(source_entity)
	if source_manager != null:
		resolved_use = source_manager.resolve_ability_use_snapshot(
				source_entity,
				target_entities,
				ability,
				use,
				context)
	use.resolved_use = resolved_use
	use.resolved = true

	_log_ability("Resolve ability use (server)", context.sim_tick, use.ability_id, use.source_entity_id, {
		"request": use.request_id,
		"requested": use.requested_tick,
		"start": use.start_tick,
		"lock": use.lock_tick,
		"resolve": use.resolve_tick,
		"finish": use.finish_tick,
		"impact": use.impact_tick,
		"targets": target_entities.size(),
		"effects": resolved_use.effects.size(),
	})
	_send_ability_resolved(resolved_use)


func _apply_scheduled_ability_use(
		use: ScheduledAbilityUse,
		context: AbilityExecutionContext,
		phase: int = ResolvedAbilityEffectSnapshot.Phase.IMPACT) -> Array[EntityEvents]:
	if use == null or context == null or use.resolved_use == null:
		return []

	var source_entity := _get_entity(use.source_entity_id)
	if source_entity == null:
		return []

	var source_manager := _get_combat_manager_for_entity(source_entity)
	if source_manager == null:
		return []

	var events := source_manager.apply_resolved_ability_use(source_entity, use.resolved_use, context, phase)
	if events.is_empty():
		return events

	var phase_label := "early" if phase == ResolvedAbilityEffectSnapshot.Phase.EARLY else "impact"
	_log_ability("Apply ability %s (server)" % phase_label, context.sim_tick, use.ability_id, use.source_entity_id, {
		"request": use.request_id,
		"requested": use.requested_tick,
		"start": use.start_tick,
		"lock": use.lock_tick,
		"resolve": use.resolve_tick,
		"finish": use.finish_tick,
		"impact": use.impact_tick,
		"applied": events.size(),
	})
	for event in events:
		if event != null and event.type == EntityEvents.Type.COMBATANT_DIED:
			_log_death(context.sim_tick, event.entity_id, event.killer_entity_id, use.ability_id)
	return events


func _send_ability_resolved(resolved_use: ResolvedAbilityUseSnapshot) -> void:
	if resolved_use == null or resolved_use.source_entity_id <= 0:
		return

	var packet := Proto.Packet.new()
	var resolved_msg := packet.new_ability_resolved()
	resolved_msg.set_ability_id(resolved_use.ability_id)
	resolved_msg.set_start_tick(resolved_use.start_tick)
	resolved_msg.set_request_id(resolved_use.request_id)
	resolved_msg.set_resolve_tick(resolved_use.resolve_tick)
	resolved_msg.set_finish_tick(resolved_use.finish_tick)
	resolved_msg.set_impact_tick(resolved_use.impact_tick)
	for resolved_effect in resolved_use.effects:
		_write_resolved_effect(resolved_msg.add_effects(), resolved_effect)
	multiplayer.send_bytes(
			packet.to_bytes(),
			resolved_use.source_entity_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			0)


func _write_resolved_effect(effect_msg, resolved_effect: ResolvedAbilityEffectSnapshot) -> void:
	if resolved_effect == null:
		return
	effect_msg.set_kind(resolved_effect.kind)
	effect_msg.set_phase(resolved_effect.phase)
	effect_msg.set_target_entity_id(resolved_effect.target_entity_id)
	effect_msg.set_hit_type(resolved_effect.hit_type)
	effect_msg.set_amount(resolved_effect.amount)
	effect_msg.set_status_id(resolved_effect.status_id)
	effect_msg.set_duration(resolved_effect.duration)
	effect_msg.set_is_debuff(resolved_effect.is_debuff)


func _log_ability(
		label: String,
		tick: int,
		ability_id: int,
		entity_id: int,
		details: Dictionary = {}) -> void:
	var message := "[ABILITY] %s tick=%d time=%s entity=%d ability=%s" % [
		label,
		tick,
		_timestamp(),
		entity_id,
		ability_id]
	for key in details:
		message += " %s=%s" % [key, str(details[key])]
	print(message)


func _log_death(tick: int, entity_id: int, killer_entity_id: int, ability_id: int) -> void:
	print("[COMBAT] Combatant died tick=%d time=%s entity=%d killer=%d ability=%s" % [
		tick,
		_timestamp(),
		entity_id,
		killer_entity_id,
		ability_id])


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
