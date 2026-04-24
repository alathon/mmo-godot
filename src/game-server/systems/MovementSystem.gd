class_name MovementSystem
extends Node

const MOVEMENT_INPUT_EPSILON := 0.01
const MOVED_POSITION_EPSILON := 0.01

var _zone: Node


func init(zone: Node) -> void:
	_zone = zone


## Runs player movement simulation for one tick.
## Reads ctx["inputs"] produced by InputSystem.tick().
func tick(tick: int, ctx: Dictionary) -> void:
	var players: Dictionary = _zone.players
	var inputs: Dictionary = ctx["inputs"]
	var moving_entities: Dictionary = {}
	var moved_entities: Dictionary = {}
	for peer_id in inputs:
		var player: ServerPlayer = players.get(peer_id)
		if player:
			var input: Dictionary = inputs[peer_id]
			var before_position: Vector3 = player.body.global_position
			if (
				abs(input.get("input_x", 0.0)) > MOVEMENT_INPUT_EPSILON
				or abs(input.get("input_z", 0.0)) > MOVEMENT_INPUT_EPSILON
				or input.get("jump_pressed", false)
			):
				moving_entities[peer_id] = true
			player.body.simulate(inputs[peer_id], Globals.TICK_INTERVAL)
			if before_position.distance_squared_to(player.body.global_position) > MOVED_POSITION_EPSILON * MOVED_POSITION_EPSILON:
				moved_entities[peer_id] = true
	ctx["moving_entities"] = moving_entities
	ctx["moved_entities"] = moved_entities
