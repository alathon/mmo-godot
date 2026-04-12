class_name WorldPositionsSystem
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

var _zone: Node
var _debug: bool = false

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
		var body: PhysicsBody = players[peer_id].body
		var ep := wpos.add_entities()
		ep.set_entity_id(peer_id)
		ep.set_pos_x(body.global_position.x)
		ep.set_pos_y(body.global_position.y)
		ep.set_pos_z(body.global_position.z)
		ep.set_vel_x(body.velocity.x)
		ep.set_vel_y(body.velocity.y)
		ep.set_vel_z(body.velocity.z)
		ep.set_rot_y(body.face_angle)
		ep.set_is_on_floor(body.is_on_floor())
	var ubytes := upkt.to_bytes()
	if _debug and (ctx.get("moving_entities", {}).size() > 0):
		print("[TRACE:WorldPositionsSystem] t=%s tick=%d broadcasting positions (moving peers: %s)" % [
			Globals.ts(), tick, ctx["moving_entities"].keys()])
	for peer_id in players:
		if not frozen_peers.has(peer_id):
			multiplayer.send_bytes(ubytes, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)
