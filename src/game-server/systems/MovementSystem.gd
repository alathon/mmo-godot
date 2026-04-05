class_name MovementSystem
extends Node

var _zone: Node


func init(zone: Node) -> void:
	_zone = zone


## Runs player movement simulation for one tick.
## Reads ctx["inputs"] produced by InputSystem.tick().
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var inputs: Dictionary = ctx["inputs"]
	for peer_id in inputs:
		var player: CommonPlayer = players.get(peer_id)
		if player:
			player.simulate(inputs[peer_id], Globals.TICK_INTERVAL)
