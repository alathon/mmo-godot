class_name CombatSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _zone: Node
var _db: AbilityDatabase

## Event descriptors accumulated this tick, flushed into CombatTickEvents at the end.
var _pending_events: Array = []
## Per-peer reliable ACK packets (accepted / rejected).
var _ack_queue: Array = []  # Array[{peer_id, bytes}]


func _ready() -> void:
	_db = AbilityDatabase.new()
	_db.load_all()
	print("[COMBAT] AbilityDatabase loaded %d abilities" % _db.get_all().size())


func init(zone: Node) -> void:
	_zone = zone


## Called from ServerZone._on_packet() when a TargetSelect packet arrives.
func handle_target_select(peer_id: int, target_entity_id: int) -> void:
	var player: ServerPlayer = _zone.players.get(peer_id)
	if player:
		var cs := player.get_node_or_null("Mob/Combat") as CombatState
		if cs:
			cs.target_entity_id = target_entity_id


## Resolves the combat stack for sim_tick and dispatches per-peer ACKs.
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers
	var ability_inputs: Dictionary = ctx["ability_inputs"]
	var moving_entities: Dictionary = ctx["moving_entities"]

	_pending_events.clear()
	_ack_queue.clear()

	# 1. Cancel casts for entities that moved
	for entity_id in moving_entities:
		var combat := _combat(entity_id, players)
		var cds    := _cooldowns(entity_id, players)
		if combat and combat.is_casting():
			_cancel_cast(entity_id, combat, cds, CombatConstants.CANCEL_MOVED)

	# 2. Process incoming ability inputs
	for entity_id in ability_inputs:
		var combat := _combat(entity_id, players)
		var cds    := _cooldowns(entity_id, players)
		var stats  := _stats(entity_id, players)
		if combat == null or cds == null or stats == null:
			continue
		_process_ability_input(entity_id, combat, cds, stats,
				ability_inputs[entity_id], tick, players)

	# 3. Advance timers and resolve completed casts
	for entity_id in players:
		var combat := _combat(entity_id, players)
		var cds    := _cooldowns(entity_id, players)
		var stats  := _stats(entity_id, players)
		if combat == null or cds == null or stats == null:
			continue
		_advance_and_resolve(entity_id, combat, cds, stats, tick, players)

	# Dispatch per-peer ACKs
	for ack in _ack_queue:
		var target: int = ack["peer_id"]
		if players.has(target) and not frozen_peers.has(target):
			multiplayer.send_bytes(ack["bytes"], target, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)


func has_events() -> bool:
	return not _pending_events.is_empty()


## Populates a CombatTickEvents proto message with all events from this tick.
## Call only after tick() and before the next tick().
func build_combat_events_proto(combat_events_msg, sim_tick: int) -> void:
	combat_events_msg.set_tick(sim_tick)
	for desc in _pending_events:
		var ev = combat_events_msg.add_events()
		ev.set_tick(sim_tick)
		match desc["type"]:
			"ability_use_started":
				var m = ev.new_ability_use_started()
				m.set_source_entity_id(desc["source_entity_id"])
				m.set_ability_id(desc["ability_id"])
				m.set_target_entity_id(desc["target_entity_id"])
				var gp: Vector3 = desc["ground_pos"]
				m.set_ground_x(gp.x); m.set_ground_y(gp.y); m.set_ground_z(gp.z)
				m.set_cast_time(desc["cast_time"])
			"ability_use_canceled":
				var m = ev.new_ability_use_canceled()
				m.set_source_entity_id(desc["source_entity_id"])
				m.set_ability_id(desc["ability_id"])
				m.set_cancel_reason(desc["cancel_reason"])
			"ability_use_completed":
				var m = ev.new_ability_use_completed()
				m.set_source_entity_id(desc["source_entity_id"])
				m.set_ability_id(desc["ability_id"])
				m.set_hit_type(desc["hit_type"])
			"damage_taken":
				var m = ev.new_damage_taken()
				m.set_source_entity_id(desc["source_entity_id"])
				m.set_target_entity_id(desc["target_entity_id"])
				m.set_ability_id(desc["ability_id"])
				m.set_amount(desc["amount"])
			"healing_received":
				var m = ev.new_healing_received()
				m.set_source_entity_id(desc["source_entity_id"])
				m.set_target_entity_id(desc["target_entity_id"])
				m.set_ability_id(desc["ability_id"])
				m.set_amount(desc["amount"])
			"combatant_died":
				var m = ev.new_combatant_died()
				m.set_entity_id(desc["entity_id"])
				m.set_killer_entity_id(desc["killer_entity_id"])


# ── Ability input processing ───────────────────────────────────────────────────

func _process_ability_input(entity_id: int, combat: CombatState, cds: Cooldowns,
		stats: Stats, ai: Dictionary, sim_tick: int, zone_players: Dictionary) -> void:
	var ability_id: String = ai["ability_id"]
	var target_id: int = ai["target_entity_id"]
	var ground_pos := Vector3(ai["ground_x"], ai["ground_y"], ai["ground_z"])

	var ability: AbilityDef = _db.get_ability(ability_id)
	if ability == null:
		_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
		return

	if combat.is_casting():
		if _in_cast_queue_window(combat):
			var err := _validate(entity_id, combat, cds, stats, ability,
					target_id, ground_pos, zone_players, true)
			if err != "":
				_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
				return
			combat.queued_ability_id = ability_id
			combat.queued_target_entity_id = target_id
			combat.queued_ground_pos = ground_pos
			combat.queued_requested_tick = sim_tick
			_enqueue_accepted(entity_id, ability_id, sim_tick, 0)
		else:
			_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
		return

	# No active cast — allow queuing during the last 50% of GCD
	if combat.gcd_remaining > 0.0:
		if ability.gcd and _in_gcd_queue_window(combat):
			var err := _validate(entity_id, combat, cds, stats, ability,
					target_id, ground_pos, zone_players, true)
			if err != "":
				_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
				return
			combat.queued_ability_id = ability_id
			combat.queued_target_entity_id = target_id
			combat.queued_ground_pos = ground_pos
			combat.queued_requested_tick = sim_tick
			_enqueue_accepted(entity_id, ability_id, sim_tick, 0)
		else:
			_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
		return

	var err := _validate(entity_id, combat, cds, stats, ability,
			target_id, ground_pos, zone_players, false)
	if err != "":
		_enqueue_rejected(entity_id, ability_id, sim_tick, CombatConstants.CANCEL_INVALID)
		return

	_start_cast(entity_id, combat, cds, ability, target_id, ground_pos, sim_tick)


# ── Timer advancement and cast resolution ─────────────────────────────────────

func _advance_and_resolve(entity_id: int, combat: CombatState, cds: Cooldowns,
		stats: Stats, sim_tick: int, zone_players: Dictionary) -> void:
	var prev_gcd := combat.gcd_remaining
	combat.gcd_remaining = maxf(0.0, combat.gcd_remaining - Globals.TICK_INTERVAL)
	combat.anim_lock_remaining = maxf(0.0, combat.anim_lock_remaining - Globals.TICK_INTERVAL)
	cds.tick(Globals.TICK_INTERVAL)

	if combat.is_casting():
		combat.cast_remaining -= Globals.TICK_INTERVAL
		if combat.cast_remaining <= 0.0:
			_resolve_cast(entity_id, combat, cds, stats, sim_tick, zone_players)
	elif combat.has_queued():
		# GCD just expired with no active cast — fire the queued ability
		if prev_gcd > 0.0 and combat.gcd_remaining <= 0.0:
			_dequeue_ability(entity_id, combat, cds, stats, sim_tick, zone_players)


# ── Cast lifecycle ─────────────────────────────────────────────────────────────

func _start_cast(entity_id: int, combat: CombatState, cds: Cooldowns,
		ability: AbilityDef, target_id: int, ground_pos: Vector3, sim_tick: int) -> void:
	combat.cast_ability_id = ability.id
	combat.cast_target_entity_id = target_id
	combat.cast_ground_pos = ground_pos
	combat.cast_total = ability.cast_time
	combat.cast_remaining = ability.cast_time
	combat.cast_requested_tick = sim_tick
	combat.cast_start_tick = sim_tick

	if ability.gcd:
		combat.gcd_remaining = CombatConstants.GCD_DURATION
	combat.anim_lock_remaining = CombatConstants.ANIMATION_LOCK_DURATION

	cds.start(ability.id, ability.cooldown, ability.cooldown_group)

	_enqueue_accepted(entity_id, ability.id, sim_tick, sim_tick)

	_pending_events.append({
		"type": "ability_use_started",
		"source_entity_id": entity_id,
		"ability_id": ability.id,
		"target_entity_id": target_id,
		"ground_pos": ground_pos,
		"cast_time": ability.cast_time,
	})


func _resolve_cast(entity_id: int, combat: CombatState, cds: Cooldowns,
		stats: Stats, sim_tick: int, zone_players: Dictionary) -> void:
	var ability_id := combat.cast_ability_id
	var ability: AbilityDef = _db.get_ability(ability_id)
	var target_id := combat.cast_target_entity_id
	var ground_pos := combat.cast_ground_pos
	combat.clear_cast()

	if ability == null:
		return

	# Re-validate resources at completion
	for resource in ability.resource_cost:
		if not stats.has_resource(resource, ability.resource_cost[resource]):
			_pending_events.append({
				"type": "ability_use_canceled",
				"source_entity_id": entity_id,
				"ability_id": ability_id,
				"cancel_reason": CombatConstants.CANCEL_INVALID,
			})
			if combat.has_queued():
				_dequeue_ability(entity_id, combat, cds, stats, sim_tick, zone_players)
			return

	# Re-validate range at completion (only for non-instant abilities)
	if ability.cast_time > 0.0 and ability.target_type != AbilityDef.TARGET_SELF:
		var range_err := _check_range(entity_id, ability, target_id, ground_pos, zone_players)
		if range_err != "":
			var reason := CombatConstants.CANCEL_TARGET_DIED \
					if range_err == "target_gone" else CombatConstants.CANCEL_INVALID
			_pending_events.append({
				"type": "ability_use_canceled",
				"source_entity_id": entity_id,
				"ability_id": ability_id,
				"cancel_reason": reason,
			})
			if combat.has_queued():
				_dequeue_ability(entity_id, combat, cds, stats, sim_tick, zone_players)
			return

	# Spend resources
	for resource in ability.resource_cost:
		stats.spend_resource(resource, ability.resource_cost[resource])

	_pending_events.append({
		"type": "ability_use_completed",
		"source_entity_id": entity_id,
		"ability_id": ability_id,
		"hit_type": 0,  # HIT — no miss/crit system yet
	})

	# Apply effects to all resolved targets
	var targets := _get_targets(entity_id, ability, target_id, ground_pos, zone_players)
	for t_id in targets:
		var t_stats: Stats = _stats(t_id, zone_players)
		if t_stats == null:
			continue
		for effect in ability.effects:
			_apply_effect(entity_id, ability_id, t_id, t_stats, effect)

	# Death check
	for t_id in targets:
		var t_stats: Stats = _stats(t_id, zone_players)
		if t_stats and t_stats.is_dead():
			_pending_events.append({
				"type": "combatant_died",
				"entity_id": t_id,
				"killer_entity_id": entity_id,
			})

	if combat.has_queued():
		_dequeue_ability(entity_id, combat, cds, stats, sim_tick, zone_players)


func _cancel_cast(entity_id: int, combat: CombatState,
		cds: Cooldowns, reason: int) -> void:
	var ability_id := combat.cast_ability_id
	var ability: AbilityDef = _db.get_ability(ability_id)
	# Per spec: canceling a cast also cancels the GCD, anim lock, and ability cooldown
	cds.cancel(ability_id, ability.cooldown_group if ability else "")
	combat.gcd_remaining = 0.0
	combat.anim_lock_remaining = 0.0
	combat.clear_cast()
	combat.clear_queued()
	_pending_events.append({
		"type": "ability_use_canceled",
		"source_entity_id": entity_id,
		"ability_id": ability_id,
		"cancel_reason": reason,
	})


func _dequeue_ability(entity_id: int, combat: CombatState, cds: Cooldowns,
		stats: Stats, sim_tick: int, zone_players: Dictionary) -> void:
	var ability_id := combat.queued_ability_id
	var target_id := combat.queued_target_entity_id
	var ground_pos := combat.queued_ground_pos
	combat.clear_queued()

	var ability: AbilityDef = _db.get_ability(ability_id)
	if ability == null:
		return
	if _validate(entity_id, combat, cds, stats, ability,
			target_id, ground_pos, zone_players, false) != "":
		return  # Conditions changed — silently drop

	_start_cast(entity_id, combat, cds, ability, target_id, ground_pos, sim_tick)


# ── Effect application ─────────────────────────────────────────────────────────

func _apply_effect(source_id: int, ability_id: String,
		target_id: int, t_stats: Stats, effect: EffectDef) -> void:
	match effect.type:
		EffectDef.TYPE_DAMAGE:
			var amount := int(effect.base_value)
			t_stats.take_damage(amount)
			_pending_events.append({
				"type": "damage_taken",
				"source_entity_id": source_id,
				"target_entity_id": target_id,
				"ability_id": ability_id,
				"amount": float(amount),
			})
		EffectDef.TYPE_HEAL:
			var amount := int(effect.base_value)
			t_stats.restore_hp(amount)
			_pending_events.append({
				"type": "healing_received",
				"source_entity_id": source_id,
				"target_entity_id": target_id,
				"ability_id": ability_id,
				"amount": float(amount),
			})
		# Status effects, displacement, dispel, consume_stacks: deferred
		_:
			pass


# ── Validation ────────────────────────────────────────────────────────────────

func _validate(entity_id: int, combat: CombatState, cds: Cooldowns, stats: Stats,
		ability: AbilityDef, target_id: int, ground_pos: Vector3,
		zone_players: Dictionary, is_queuing: bool) -> String:
	if not is_queuing:
		if combat.anim_lock_remaining > 0.0:
			return "anim_lock"
		if ability.gcd and combat.gcd_remaining > 0.0:
			return "gcd"

	if not cds.is_ready(ability.id, ability.cooldown_group):
		return "on_cooldown"

	for resource in ability.resource_cost:
		if not stats.has_resource(resource, ability.resource_cost[resource]):
			return "insufficient_" + resource

	if ability.target_type == AbilityDef.TARGET_SELF:
		return ""

	return _check_range(entity_id, ability, target_id, ground_pos, zone_players)


func _check_range(entity_id: int, ability: AbilityDef, target_id: int,
		ground_pos: Vector3, zone_players: Dictionary) -> String:
	var caster_pos := _pos(entity_id, zone_players)
	if ability.target_type == AbilityDef.TARGET_GROUND:
		if ability.range > 0.0 and caster_pos.distance_to(ground_pos) > ability.range:
			return "out_of_range"
	else:
		if not zone_players.has(target_id):
			return "target_gone"
		if ability.range > 0.0 and caster_pos.distance_to(_pos(target_id, zone_players)) > ability.range:
			return "out_of_range"
	return ""


# ── Target resolution ─────────────────────────────────────────────────────────

func _get_targets(caster_id: int, ability: AbilityDef,
		target_id: int, ground_pos: Vector3, zone_players: Dictionary) -> Array:
	if ability.target_type == AbilityDef.TARGET_SELF:
		return [caster_id]
	if ability.aoe_shape != "":
		var result: Array = []
		for eid in zone_players:
			if ground_pos.distance_to(_pos(eid, zone_players)) <= ability.aoe_radius:
				result.append(eid)
		return result
	if zone_players.has(target_id):
		return [target_id]
	return []


# ── Packet helpers ────────────────────────────────────────────────────────────

func _enqueue_accepted(peer_id: int, ability_id: String,
		requested_tick: int, start_tick: int) -> void:
	var pkt := Proto.Packet.new()
	var msg = pkt.new_ability_accepted()
	msg.set_ability_id(ability_id)
	msg.set_requested_tick(requested_tick)
	msg.set_start_tick(start_tick)
	_ack_queue.append({"peer_id": peer_id, "bytes": pkt.to_bytes()})


func _enqueue_rejected(peer_id: int, ability_id: String,
		requested_tick: int, reason: int) -> void:
	var pkt := Proto.Packet.new()
	var msg = pkt.new_ability_rejected()
	msg.set_ability_id(ability_id)
	msg.set_requested_tick(requested_tick)
	msg.set_cancel_reason(reason)
	_ack_queue.append({"peer_id": peer_id, "bytes": pkt.to_bytes()})


# ── Component accessors ────────────────────────────────────────────────────────

func _stats(entity_id: int, zone_players: Dictionary) -> Stats:
	var player: ServerPlayer = zone_players.get(entity_id)
	return player.get_node_or_null("Mob/Stats") as Stats if player else null


func _cooldowns(entity_id: int, zone_players: Dictionary) -> Cooldowns:
	var player: ServerPlayer = zone_players.get(entity_id)
	return player.get_node_or_null("Mob/Cooldowns") as Cooldowns if player else null


func _combat(entity_id: int, zone_players: Dictionary) -> CombatState:
	var player: ServerPlayer = zone_players.get(entity_id)
	return player.get_node_or_null("Mob/Combat") as CombatState if player else null


func _in_cast_queue_window(combat: CombatState) -> bool:
	return combat.cast_total > 0.0 and \
		combat.cast_remaining <= combat.cast_total * CombatConstants.ABILITY_QUEUE_WINDOW


func _in_gcd_queue_window(combat: CombatState) -> bool:
	return combat.gcd_remaining <= CombatConstants.GCD_DURATION * CombatConstants.ABILITY_QUEUE_WINDOW


func _pos(entity_id: int, zone_players: Dictionary) -> Vector3:
	var player: ServerPlayer = zone_players.get(entity_id)
	return player.body.global_position if player else Vector3.ZERO
