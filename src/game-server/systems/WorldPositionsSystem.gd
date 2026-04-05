class_name WorldPositionsSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _zone: Node


func init(zone: Node) -> void:
	_zone = zone


## Builds and broadcasts the unreliable WorldPositions packet (positions + velocities).
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var frozen_peers: Dictionary = _zone._frozen_peers

	var upkt := Proto.Packet.new()
	var wpos := upkt.new_world_positions()
	wpos.set_tick(tick)
	for peer_id in players:
		var player: CommonPlayer = players[peer_id]
		var ep := wpos.add_entities()
		ep.set_entity_id(peer_id)
		ep.set_pos_x(player.global_position.x)
		ep.set_pos_y(player.global_position.y)
		ep.set_pos_z(player.global_position.z)
		ep.set_vel_x(player.velocity.x)
		ep.set_vel_y(player.velocity.y)
		ep.set_vel_z(player.velocity.z)
		ep.set_rot_y(player.face_angle)
	var ubytes := upkt.to_bytes()
	for peer_id in players:
		if not frozen_peers.has(peer_id):
			multiplayer.send_bytes(ubytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)
