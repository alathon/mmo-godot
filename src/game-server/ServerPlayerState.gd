class_name ServerPlayerState
extends Node

## Tick of the first input received from the client.
## Simulation starts once sim_tick reaches this value.
var first_input_tick: int = -1

## Tick of last received input. Used to kick idle/dead connections.
var last_input_tick: int = -1

## Last applied input (re-executed when no new input arrives for a tick).
var last_input := { "input_x": 0.0, "input_z": 0.0, "jump_pressed": false }
