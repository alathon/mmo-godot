extends Node

const TICK_INTERVAL: float = 1.0 / 20.0
const TICK_RATE: int = 20

## How many ticks the server processes input in the past.
## Used by both server (to buffer) and client (to reconcile).
const INPUT_BUFFER_SIZE: int = 5
