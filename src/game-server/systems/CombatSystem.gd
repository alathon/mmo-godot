class_name CombatSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _zone: Node = null
var _targeting: CombatTargeting = null
var _pending_events: Array[EntityEvents] = []
var _resolved_casts: Dictionary = {}


func init(zone: Node) -> void:
	_zone = zone
	_targeting = CombatTargeting.new()
	_targeting.init(_zone)


func tick(sim_tick: int, ctx: Dictionary) -> void:
	return


func get_combat_manager(entity_id: int) -> CombatManager:
	var entity := _get_entity(entity_id)
	return _get_combat_manager_for_entity(entity)


func get_entity_id(entity: Node) -> int:
	if _zone == null or entity == null:
		return 0
	return int(entity.id)


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
		if combat_manager.hostility.has_aggro_for(healed_entity):
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
		combat_manager.hostility.clear_aggro(entity)
		if not combat_manager.hostility.has_aggro():
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


func on_cast_locked(
		transition: AbilityTransition,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if transition == null:
		return []
	var cast_state := _get_cast_state(transition.request_id)
	cast_state["transition"] = transition
	cast_state["locked"] = true
	_resolved_casts[transition.request_id] = cast_state

	if cast_state.get("resolved_use", null) == null or bool(cast_state.get("early_applied", false)):
		return []

	var events := _apply_resolved_phase(transition, context, ResolvedAbilityEffectSnapshot.Phase.EARLY)
	cast_state["early_applied"] = true
	_resolved_casts[transition.request_id] = cast_state
	return events


func on_cast_resolve_due(
		transition: AbilityTransition,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if transition == null or context == null:
		return []

	var resolved_use := ResolvedAbilityUseSnapshot.from_scheduled_use(transition)
	var source_entity := _get_entity(transition.source_entity_id)
	var ability := AbilityDB.get_ability(transition.ability_id)
	if source_entity != null and ability != null:
		var target_entities := _resolve_targets_for_cast(source_entity, ability, transition.target, context)
		var source_combat_manager := _get_combat_manager_for_entity(source_entity)
		if source_combat_manager != null:
			resolved_use = source_combat_manager.resolve_ability_use_snapshot(
					source_entity,
					target_entities,
					ability,
					transition,
					context)
		_log_ability("Resolve ability snapshot", context.sim_tick, transition.ability_id, transition.source_entity_id, {
			"request": transition.request_id,
			"start": transition.start_tick,
			"resolve": transition.resolve_tick,
			"finish": transition.finish_tick,
			"impact": transition.impact_tick,
			"targets": target_entities.size(),
			"effects": resolved_use.effects.size(),
		})

	var cast_state := _get_cast_state(transition.request_id)
	cast_state["transition"] = transition
	cast_state["resolved_use"] = resolved_use
	_resolved_casts[transition.request_id] = cast_state
	_send_ability_resolved(resolved_use)

	if bool(cast_state.get("locked", false)) and not bool(cast_state.get("early_applied", false)):
		var events := _apply_resolved_phase(transition, context, ResolvedAbilityEffectSnapshot.Phase.EARLY)
		cast_state["early_applied"] = true
		_resolved_casts[transition.request_id] = cast_state
		return events

	return []


func on_cast_impact_due(
		transition: AbilityTransition,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if transition == null:
		return []

	var events: Array[EntityEvents] = [
		EntityEvents.ability_impact(
				transition.source_entity_id,
				transition.ability_id,
				transition.request_id)
	]
	events.append_array(_apply_resolved_phase(transition, context, ResolvedAbilityEffectSnapshot.Phase.IMPACT))
	_resolved_casts.erase(transition.request_id)
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


func resolve_hit(ability: AbilityResource, source_stats: Dictionary, target_stats: GeneralStats) -> int:
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


func _apply_resolved_phase(
		transition: AbilityTransition,
		context: AbilityExecutionContext,
		phase: int) -> Array[EntityEvents]:
	if transition == null or context == null:
		return []

	var cast_state := _get_cast_state(transition.request_id)
	var resolved_use := cast_state.get("resolved_use", null) as ResolvedAbilityUseSnapshot
	if resolved_use == null:
		return []

	var source_entity := _get_entity(transition.source_entity_id)
	if source_entity == null:
		return []

	var source_manager := _get_combat_manager_for_entity(source_entity)
	if source_manager == null:
		return []

	var events := source_manager.apply_resolved_ability_use(source_entity, resolved_use, context, phase)
	if events.is_empty():
		return events

	var label := "Apply early effects" if phase == ResolvedAbilityEffectSnapshot.Phase.EARLY else "Apply impact effects"
	_log_ability(label, context.sim_tick, transition.ability_id, transition.source_entity_id, {
		"request": transition.request_id,
		"start": transition.start_tick,
		"resolve": transition.resolve_tick,
		"finish": transition.finish_tick,
		"impact": transition.impact_tick,
		"applied": events.size(),
	})
	for event in events:
		if event != null and event.type == EntityEvents.Type.COMBATANT_DIED:
			_log_death(context.sim_tick, event.entity_id, event.killer_entity_id, transition.ability_id)
	return events


func _resolve_targets_for_cast(
		source_entity: Node,
		ability: AbilityResource,
		target: AbilityTargetSpec,
		context: AbilityExecutionContext) -> Array[Node]:
	if source_entity == null or target == null or ability == null:
		return []
	if ability.target_type == AbilityResource.TargetType.SELF:
		return [source_entity]
	if ability.aoe_shape != AbilityResource.AoeShape.NONE:
		return _resolve_aoe_targets(source_entity, ability, target)
	if not _is_in_range(source_entity, ability, target):
		return []

	match target.kind:
		AbilityTargetSpec.Kind.ENTITY:
			var target_entity := _get_entity(target.entity_id)
			if _is_valid_target(source_entity, target_entity, ability):
				return [target_entity]
		AbilityTargetSpec.Kind.GROUND:
			if ability.target_type == AbilityResource.TargetType.GROUND:
				return _resolve_ground_targets(source_entity, ability, target.ground_position)
	return []


func _resolve_aoe_targets(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> Array[Node]:
	match ability.aoe_shape:
		AbilityResource.AoeShape.CIRCLE:
			return _resolve_circle_targets(source_entity, ability, _get_aoe_center(source_entity, target))
		AbilityResource.AoeShape.CONE:
			return _resolve_cone_targets(source_entity, ability, target)
		_:
			return []


func _resolve_ground_targets(source_entity: Node, ability: AbilityResource, ground_position: Vector3) -> Array[Node]:
	if ability == null or ability.aoe_shape == AbilityResource.AoeShape.NONE:
		return []
	return _resolve_aoe_targets(source_entity, ability, AbilityTargetSpec.ground(ground_position))


func _resolve_circle_targets(source_entity: Node, ability: AbilityResource, center: Vector3) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var targets: Array[Node] = []
	for candidate in _get_valid_targets_for(source_entity, ability):
		if _get_entity_position(candidate).distance_to(center) <= radius:
			targets.append(candidate)
	return targets


func _resolve_cone_targets(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> Array[Node]:
	var radius := _get_aoe_radius(ability)
	var source_position := _get_entity_position(source_entity)
	var forward := _get_cone_forward(source_entity, target)
	if forward == Vector3.ZERO:
		return []

	var targets: Array[Node] = []
	for candidate in _get_valid_targets_for(source_entity, ability):
		var offset := _get_entity_position(candidate) - source_position
		offset.y = 0.0
		if offset == Vector3.ZERO or offset.length() > radius:
			continue
		if forward.angle_to(offset.normalized()) <= PI * 0.25:
			targets.append(candidate)
	return targets


func _get_aoe_center(source_entity: Node, target: AbilityTargetSpec) -> Vector3:
	if target == null:
		return _get_entity_position(source_entity)
	match target.kind:
		AbilityTargetSpec.Kind.GROUND:
			return target.ground_position
		AbilityTargetSpec.Kind.ENTITY:
			return _get_entity_position(_get_entity(target.entity_id))
		_:
			return _get_entity_position(source_entity)


func _get_cone_forward(source_entity: Node, target: AbilityTargetSpec) -> Vector3:
	var source_position := _get_entity_position(source_entity)
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		var toward_ground := target.ground_position - source_position
		toward_ground.y = 0.0
		return toward_ground.normalized() if toward_ground != Vector3.ZERO else Vector3.ZERO
	var angle := float(source_entity.face_angle)
	return Vector3(-sin(angle), 0.0, -cos(angle)).normalized()


func _get_aoe_radius(ability: AbilityResource) -> float:
	if ability == null:
		return 0.0
	if ability.aoe_radius > 0.0:
		return ability.aoe_radius
	return ability.range


func _get_valid_targets_for(source_entity: Node, ability: AbilityResource) -> Array[Node]:
	var targets: Array[Node] = []
	for candidate in _get_all_entities():
		if _is_valid_target(source_entity, candidate, ability):
			targets.append(candidate)
	return targets


func _is_valid_target(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool:
	if source_entity == null or target_entity == null or ability == null:
		return false
	if ability.target_type == AbilityResource.TargetType.SELF:
		return source_entity == target_entity
	if _is_combat_target_type(ability.target_type):
		return _targeting != null and _targeting.is_valid_combat_target(source_entity, target_entity, ability)
	return true


func _is_in_range(source_entity: Node, ability: AbilityResource, target: AbilityTargetSpec) -> bool:
	if source_entity == null or ability == null:
		return false
	if ability.range <= 0.0:
		return true
	if target != null and target.kind == AbilityTargetSpec.Kind.GROUND:
		return _get_entity_position(source_entity).distance_to(target.ground_position) <= ability.range
	var targets := _resolve_targets_for_direct_range(source_entity, target)
	if targets.is_empty():
		return ability.target_type == AbilityResource.TargetType.GROUND
	for target_entity in targets:
		if _get_entity_position(source_entity).distance_to(_get_entity_position(target_entity)) > ability.range:
			return false
	return true


func _resolve_targets_for_direct_range(source_entity: Node, target: AbilityTargetSpec) -> Array[Node]:
	if target == null:
		return []
	match target.kind:
		AbilityTargetSpec.Kind.ENTITY:
			var target_entity := _get_entity(target.entity_id)
			if target_entity != null:
				return [target_entity]
	return []


func _get_entity(entity_id: int) -> Node:
	if _zone == null:
		return null
	return _zone.players.get(entity_id, null)


func _get_combat_manager_for_entity(entity: Node) -> CombatManager:
	if entity == null:
		return null
	return entity.combat_manager as CombatManager


func _get_combat_managers() -> Array[CombatManager]:
	var managers: Array[CombatManager] = []
	if _zone == null:
		return managers
	for entity_id in _zone.players:
		var player := _zone.players[entity_id] as ServerPlayer
		managers.append(player.combat_manager)
	return managers


func _get_all_entities() -> Array[Node]:
	if _zone == null:
		return []
	if _zone.has_method("get_all_entities"):
		return _zone.get_all_entities()
	var entities: Array[Node] = []
	for entity_id in _zone.players:
		entities.append(_zone.players[entity_id])
	return entities


func _get_entity_position(target_entity: Node) -> Vector3:
	if target_entity == null:
		return Vector3.ZERO
	if target_entity is Node3D:
		return target_entity.global_position
	return target_entity.body.global_position


func _is_combat_target_type(target_type: int) -> bool:
	return target_type == AbilityResource.TargetType.OTHER_ENEMY or \
			target_type == AbilityResource.TargetType.OTHER_FRIEND or \
			target_type == AbilityResource.TargetType.OTHER_ANY


func _get_cast_state(request_id: int) -> Dictionary:
	var value = _resolved_casts.get(request_id, null)
	if value is Dictionary:
		return value.duplicate()
	return {
		"transition": null,
		"resolved_use": null,
		"locked": false,
		"early_applied": false,
	}


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
	var message := "%s [SERVER] [ABILITY_SERVER] %s entity=%d ability=%s" % [
		_format_tick_prefix(tick),
		label,
		entity_id,
		ability_id]
	for key in details:
		message += " %s=%s" % [key, str(details[key])]
	print(message)


func _log_death(tick: int, entity_id: int, killer_entity_id: int, ability_id: int) -> void:
	print("%s [SERVER] [COMBAT] Combatant died entity=%d killer=%d ability=%s" % [
		_format_tick_prefix(tick),
		entity_id,
		killer_entity_id,
		ability_id])


func _format_tick_prefix(tick: int) -> String:
	return "[TICK %d | (%s)]" % [tick, _timestamp()]


func _timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [
		int(time["hour"]),
		int(time["minute"]),
		int(time["second"]),
		Time.get_ticks_msec() % 1000]
