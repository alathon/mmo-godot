class_name ServerPlayerState
extends Node

## Whether this player has ever received input from the client.
## False during clock sync; simulation is skipped until first input arrives.
var has_received_input: bool = false

## Tick of last received input. Used to kick idle/dead connections.
var last_input_tick: int = -1

## Last applied input (re-executed when no new input arrives for a tick).
var last_input := { "input_x": 0.0, "input_z": 0.0, "jump_pressed": false }
