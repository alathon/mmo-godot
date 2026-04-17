class_name WorldStateSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

@onready var _zone: Node = get_owner()
@onready var _combat_system: CombatSystem = %CombatSystem
@onready var _ability_system: AbilitySystem = %AbilitySystem


func init(zone: Node, combat_system: CombatSystem) -> void:
	_zone = zone
	_combat_system = combat_system


## Builds and broadcasts the reliable WorldState packet (vitals + combat events).
## Must run after CombatSystem.tick() so combat events are populated.
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers

	var rpkt := Proto.Packet.new()
	var wstate := rpkt.new_world_state()
	wstate.set_tick(tick)

	for peer_id in players:
		var player := players[peer_id] as ServerPlayer
		var mob_stats := player.stats
		var es := wstate.add_entities()
		es.set_entity_id(peer_id)
		es.set_hp(mob_stats.hp)
		es.set_max_hp(mob_stats.max_hp)
		es.set_mana(mob_stats.mana)
		es.set_max_mana(mob_stats.max_mana)
		es.set_stamina(mob_stats.stamina)
		es.set_max_stamina(mob_stats.max_stamina)

	if _ability_system.has_events() or _combat_system.has_events():
		var combat_events = wstate.new_combat_events()
		if _ability_system.has_events():
			_ability_system.build_ability_events_proto(combat_events, tick)
		if _combat_system.has_events():
			_combat_system.build_combat_events_proto(combat_events, tick)

	var rbytes := rpkt.to_bytes()
	for peer_id in players:
		if not frozen_peers.has(peer_id):
			multiplayer.send_bytes(rbytes, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)
