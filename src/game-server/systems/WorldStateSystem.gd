class_name WorldStateSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _zone: Node = get_owner()
@onready var _combat_system: CombatSystem = %CombatSystem
@onready var _ability_system: AbilitySystem = %AbilitySystem


func init(zone: Node, combat_system: CombatSystem) -> void:
	_zone = zone
	_combat_system = combat_system


## Builds and broadcasts the reliable WorldState packet (vitals + entity events).
## Must run after AbilitySystem.tick() and CombatSystem.tick() so events are populated.
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers

	var rpkt := Proto.Packet.new()
	var wstate := rpkt.new_world_state()
	wstate.set_tick(tick)

	for peer_id in players:
		var player := players[peer_id] as ServerPlayer
		var stats := player.entity_state.general_stats
		var es := wstate.add_entities()
		es.set_entity_id(peer_id)
		es.set_hp(stats.hp)
		es.set_max_hp(stats.max_hp)
		es.set_mana(stats.mana)
		es.set_max_mana(stats.max_mana)
		es.set_stamina(stats.stamina)
		es.set_max_stamina(stats.max_stamina)

	if _ability_system.has_entity_events():
		_ability_system.build_entity_events_proto(wstate, tick)
	if _combat_system.has_events():
		_combat_system.build_entity_events_proto(wstate, tick)

	var rbytes := rpkt.to_bytes()
	for peer_id in players:
		if not frozen_peers.has(peer_id):
			multiplayer.send_bytes(rbytes, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)
