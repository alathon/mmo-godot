extends Node

static func ts() -> String:
	var t := Time.get_unix_time_from_system()
	var d := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d.%03d" % [d["hour"], d["minute"], d["second"], int(fmod(t, 1.0) * 1000)]

const TICK_INTERVAL: float = 1.0 / 20
const TICK_RATE: int = 20

## How many ticks the server processes input in the past.
## Used by both server (to buffer) and client (to reconcile).
const INPUT_BUFFER_SIZE: int = 3

const ZONE_SCENES: Dictionary = {
	"forest": "res://src/common/zones/Forest.tscn",
	"other": "res://src/common/zones/Other.tscn"
}
