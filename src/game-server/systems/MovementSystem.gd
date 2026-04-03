class_name MovementSystem
extends Node

## Runs player movement simulation for one tick.
## Called after InputSystem.tick() produces the inputs dict.
func tick(players: Dictionary, inputs: Dictionary) -> void:
	for peer_id in inputs:
		var player: CommonPlayer = players.get(peer_id)
		if player:
			player.simulate(inputs[peer_id], Globals.TICK_INTERVAL)
