class_name CombatSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _combat_manager: CombatManager = $CombatManager


## Called from ServerZone._on_packet() when a TargetSelect packet arrives.
func handle_target_select(peer_id: int, target_entity_id: int,
		players: Dictionary) -> void:
	var player := players.get(peer_id) as Node
	if player:
		var cs := player.get_node_or_null("MobCombatState") as MobCombatState
		if cs:
			cs.target_entity_id = target_entity_id


## Run the combat tick, send per-peer ACKs, and broadcast WorldState.
func tick(sim_tick: int, current_tick: int, players: Dictionary,
		ability_inputs: Dictionary, moving_entities: Dictionary,
		frozen_peers: Dictionary) -> void:
	# Combat simulation
	var combat_acks := _combat_manager.tick(sim_tick, players, ability_inputs, moving_entities)

	# Send per-peer ACKs (accepted / rejected)
	for ack in combat_acks:
		var target: int = ack["peer_id"]
		if players.has(target) and not frozen_peers.has(target):
			multiplayer.send_bytes(ack["bytes"], target, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)

	# Reliable broadcast: vitals snapshot + any combat events
	var rpkt = Proto.Packet.new()
	var wstate = rpkt.new_world_state()
	wstate.set_tick(current_tick)
	for peer_id in players:
		var mob_stats := (players[peer_id] as Node).get_node_or_null("MobStats") as MobStats
		if mob_stats:
			var es = wstate.add_entities()
			es.set_entity_id(peer_id)
			es.set_hp(mob_stats.hp)
			es.set_max_hp(mob_stats.max_hp)
			es.set_mana(mob_stats.mana)
			es.set_max_mana(mob_stats.max_mana)
			es.set_stamina(mob_stats.stamina)
			es.set_max_stamina(mob_stats.max_stamina)
	if _combat_manager.has_events():
		_combat_manager.build_combat_events_proto(wstate.new_combat_events(), sim_tick)
	var rbytes = rpkt.to_bytes()
	for peer_id in players:
		if not frozen_peers.has(peer_id):
			multiplayer.send_bytes(rbytes, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)
