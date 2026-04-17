class_name CombatManager
extends Node

@onready var stats: Stats = %Stats
@onready var hostility: Node = %DetermineHostility
@onready var entity: Node = get_parent()

var combat_started_tick: int = 0


func init(owner_entity: Node) -> void:
	entity = owner_entity


func is_in_combat() -> bool:
	return combat_started_tick > 0


func enter_combat(source_entity: Node, sim_tick: int) -> void:
	if combat_started_tick <= 0:
		combat_started_tick = sim_tick


func leave_combat(sim_tick: int) -> void:
	combat_started_tick = 0
	if hostility != null:
		hostility.clear_combat()


func can_target(
		target_entity: Node,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> AbilityValidationResult:
	if target_entity == null or ability == null:
		return AbilityValidationResult.rejected(&"invalid_target", AbilityConstants.CANCEL_INVALID)
	if not is_alive():
		return AbilityValidationResult.rejected(&"source_dead", AbilityConstants.CANCEL_INVALID)
	var target_manager := _get_combat_manager(target_entity)
	if target_manager == null or not target_manager.is_alive():
		return AbilityValidationResult.rejected(&"target_dead", AbilityConstants.CANCEL_TARGET_DIED)
	return AbilityValidationResult.accepted()


func is_hostile_to(target_entity: Node) -> bool:
	return hostility != null and hostility.is_hostile_to(target_entity)


func is_friendly_to(target_entity: Node) -> bool:
	return hostility == null or hostility.is_friendly_to(target_entity)


func is_alive() -> bool:
	return stats != null and stats.hp > 0


func on_ability_landed(
		source_entity: Node,
		target_entities: Array[Node],
		ability: AbilityResource,
		events: Array[EntityEvents],
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	var resolved: Array[EntityEvents] = []
	resolved.append_array(events)
	if ability == null:
		return resolved
	for effect in ability.effects:
		resolved.append_array(_apply_effect(source_entity, target_entities, ability, effect, context))
	return resolved


func _apply_effect(
		source_entity: Node,
		target_entities: Array[Node],
		ability: AbilityResource,
		effect: AbilityEffect,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	if source_entity == null or ability == null or effect == null:
		return []
	if not _passes_proc(effect):
		return []

	var events: Array[EntityEvents] = []
	for target_entity in target_entities:
		if not _effect_can_apply_to_target(source_entity, target_entity, effect):
			continue
		if effect is DamageEffect:
			events.append_array(_apply_damage(source_entity, target_entity, ability, effect as DamageEffect, context))
		elif effect is HealEffect:
			events.append_array(_apply_heal(source_entity, target_entity, ability, effect as HealEffect, context))
		elif effect is ApplyStatusEffect:
			events.append(_apply_status(source_entity, target_entity, ability, effect as ApplyStatusEffect, context))
	return events


func on_damage_dealt(
		target_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> void:
	if context != null:
		enter_combat(target_entity, context.sim_tick)


func on_damage_taken(
		source_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext,
		threat_amount: float = -1.0) -> void:
	if hostility != null:
		hostility.attacked_by(source_entity, amount if threat_amount < 0.0 else threat_amount)
	if context != null:
		enter_combat(source_entity, context.sim_tick)


func on_healing_done(
		target_entity: Node,
		amount: int,
		ability: AbilityResource,
		context: AbilityExecutionContext) -> void:
	pass


func on_combatant_died(killer_entity: Node, context: AbilityExecutionContext) -> EntityEvents:
	return EntityEvents.combatant_died(_entity_id(entity, context), _entity_id(killer_entity, context))


func _apply_damage(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource,
		effect: DamageEffect,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	var target_manager := _get_combat_manager(target_entity)
	if target_manager == null or not target_manager.is_alive():
		return []

	var amount := int(round(resolve_effect_value(effect.formula)))
	if amount <= 0:
		return []

	target_manager.stats.hp = maxi(0, target_manager.stats.hp - amount)
	var threat_amount := float(amount) * effect.aggro_modifier
	on_damage_dealt(target_entity, amount, ability, context)
	target_manager.on_damage_taken(source_entity, amount, ability, context, threat_amount)

	var source_entity_id := _entity_id(source_entity, context)
	var target_entity_id := _entity_id(target_entity, context)
	var events: Array[EntityEvents] = [
		EntityEvents.damage_taken(source_entity_id, target_entity_id, ability.get_ability_id(), amount)
	]
	if target_manager.stats.hp <= 0:
		events.append(target_manager.on_combatant_died(source_entity, context))
		if context != null and context.combat_system != null:
			context.combat_system.clear_combat_for_entity(target_entity, context.sim_tick)
	return events


func _apply_heal(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource,
		effect: HealEffect,
		context: AbilityExecutionContext) -> Array[EntityEvents]:
	var target_manager := _get_combat_manager(target_entity)
	if target_manager == null or not target_manager.is_alive():
		return []

	var amount := int(round(resolve_effect_value(effect.formula)))
	if amount <= 0:
		return []

	var missing_hp := maxi(0, target_manager.stats.max_hp - target_manager.stats.hp)
	var applied := mini(amount, missing_hp)
	if applied <= 0:
		return []

	target_manager.stats.hp = mini(target_manager.stats.max_hp, target_manager.stats.hp + applied)
	on_healing_done(target_entity, applied, ability, context)
	if context != null and context.combat_system != null:
		context.combat_system.add_healing_aggro(
				source_entity,
				target_entity,
				float(applied) * effect.aggro_modifier,
				context.sim_tick)

	return [
		EntityEvents.healing_received(
				_entity_id(source_entity, context),
				_entity_id(target_entity, context),
				ability.get_ability_id(),
				applied)
	]


func _apply_status(
		source_entity: Node,
		target_entity: Node,
		ability: AbilityResource,
		effect: ApplyStatusEffect,
		context: AbilityExecutionContext) -> EntityEvents:
	var status_id := effect.effect_id
	if status_id == &"":
		status_id = StringName(effect.display_name)
	var source_entity_id := _entity_id(source_entity, context)
	var target_entity_id := _entity_id(target_entity, context)
	if effect.is_debuff:
		return EntityEvents.debuff_applied(source_entity_id, target_entity_id, ability.get_ability_id(), status_id, effect.duration)
	return EntityEvents.buff_applied(source_entity_id, target_entity_id, ability.get_ability_id(), status_id, effect.duration)


func resolve_effect_value(formula: ValueFormula) -> float:
	if formula == null:
		return 0.0
	return formula.evaluate({})


func _passes_proc(effect: AbilityEffect) -> bool:
	if effect.proc_chance >= 100.0:
		return true
	return randf() * 100.0 <= effect.proc_chance


func _effect_can_apply_to_target(source_entity: Node, target_entity: Node, effect: AbilityEffect) -> bool:
	if target_entity == null:
		return false
	match effect.target_narrower:
		AbilityEffect.TargetNarrower.HOSTILE:
			return is_hostile_to(target_entity)
		AbilityEffect.TargetNarrower.FRIENDLY:
			return is_friendly_to(target_entity)
		_:
			return true


func _get_combat_manager(target_entity: Node) -> CombatManager:
	if target_entity is ServerPlayer:
		return (target_entity as ServerPlayer).combat_manager
	return null


func _entity_id(target_entity: Node, context: AbilityExecutionContext) -> int:
	if context != null and context.combat_system != null:
		return context.combat_system.get_entity_id(target_entity)
	return 0
