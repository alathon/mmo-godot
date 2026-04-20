class_name EntityEventCodec
extends RefCounted

const EntityEvents = preload("res://src/common/EntityEvents.gd")


static func write_events(msg, events: Array[EntityEvents], sim_tick: int) -> void:
	if msg == null:
		return
	for event in events:
		write_event(msg.add_events(), event, sim_tick)


static func write_event(msg, event: EntityEvents, sim_tick: int) -> void:
	if msg == null or event == null:
		return
	msg.set_tick(sim_tick)
	match event.type:
		EntityEvents.Type.ABILITY_USE_STARTED:
			var started = msg.new_ability_use_started()
			started.set_source_entity_id(event.source_entity_id)
			started.set_ability_id(event.ability_id)
			started.set_request_id(event.request_id)
			started.set_target_entity_id(event.target_entity_id)
			started.set_ground_x(event.ground_position.x)
			started.set_ground_y(event.ground_position.y)
			started.set_ground_z(event.ground_position.z)
			started.set_cast_time(event.cast_time)
		EntityEvents.Type.ABILITY_USE_CANCELED:
			var canceled = msg.new_ability_use_canceled()
			canceled.set_source_entity_id(event.source_entity_id)
			canceled.set_ability_id(event.ability_id)
			canceled.set_request_id(event.request_id)
			canceled.set_cancel_reason(event.cancel_reason)
		EntityEvents.Type.ABILITY_USE_FINISHED:
			var finished = msg.new_ability_use_finished()
			finished.set_source_entity_id(event.source_entity_id)
			finished.set_ability_id(event.ability_id)
			finished.set_request_id(event.request_id)
		EntityEvents.Type.ABILITY_USE_IMPACT:
			var impact = msg.new_ability_use_impact()
			impact.set_source_entity_id(event.source_entity_id)
			impact.set_ability_id(event.ability_id)
			impact.set_request_id(event.request_id)
		EntityEvents.Type.DAMAGE_TAKEN:
			var damage = msg.new_damage_taken()
			damage.set_source_entity_id(event.source_entity_id)
			damage.set_target_entity_id(event.target_entity_id)
			damage.set_ability_id(event.ability_id)
			damage.set_amount(event.amount)
		EntityEvents.Type.HEALING_RECEIVED:
			var healing = msg.new_healing_received()
			healing.set_source_entity_id(event.source_entity_id)
			healing.set_target_entity_id(event.target_entity_id)
			healing.set_ability_id(event.ability_id)
			healing.set_amount(event.amount)
		EntityEvents.Type.COMBAT_STARTED:
			var started = msg.new_combat_started()
			started.set_entity_id(event.entity_id)
			started.set_source_entity_id(event.source_entity_id)
		EntityEvents.Type.COMBAT_ENDED:
			var ended = msg.new_combat_ended()
			ended.set_entity_id(event.entity_id)
		EntityEvents.Type.BUFF_APPLIED:
			var buff = msg.new_buff_applied()
			buff.set_source_entity_id(event.source_entity_id)
			buff.set_target_entity_id(event.target_entity_id)
			buff.set_ability_id(event.ability_id)
			buff.set_status_id(event.status_id)
			buff.set_stacks(1)
			buff.set_remaining_duration(event.amount)
		EntityEvents.Type.DEBUFF_APPLIED:
			var debuff = msg.new_debuff_applied()
			debuff.set_source_entity_id(event.source_entity_id)
			debuff.set_target_entity_id(event.target_entity_id)
			debuff.set_ability_id(event.ability_id)
			debuff.set_status_id(event.status_id)
			debuff.set_stacks(1)
			debuff.set_remaining_duration(event.amount)
		EntityEvents.Type.STATUS_EFFECT_REMOVED:
			var removed = msg.new_status_effect_removed()
			removed.set_entity_id(event.entity_id)
			removed.set_status_id(event.status_id)
			removed.set_remove_reason(event.remove_reason)
		EntityEvents.Type.COMBATANT_DIED:
			var died = msg.new_combatant_died()
			died.set_entity_id(event.entity_id)
			died.set_killer_entity_id(event.killer_entity_id)
