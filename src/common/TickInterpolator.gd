class_name TickInterpolator
extends Node

## Interpolates between network ticks for smooth visual motion on the local player.
##
## Attach as a child of the node whose properties you want to smooth.
## Set [member properties] to the property names to interpolate (e.g. "global_position").
## The node restores the true simulation state before each tick loop, lets ticks
## run, then snapshots the result and interpolates visually in _process.

## Properties to interpolate (resolved on the parent node).
@export var properties: Array[String]

## Toggles interpolation on/off.
@export var enabled: bool = true

## If true, takes an initial snapshot on _ready so objects that move immediately
## don't pop from the origin.
@export var record_first_state: bool = true

var _from: Dictionary = {}
var _to: Dictionary = {}
var _is_teleporting: bool = false

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	if record_first_state:
		_snapshot_to()
		_from = _to.duplicate()

func _exit_tree() -> void:
	NetworkTime.before_tick_loop.disconnect(_before_tick_loop)
	NetworkTime.after_tick_loop.disconnect(_after_tick_loop)

var _debug: bool = true

func _process(_delta: float) -> void:
	if not enabled or properties.is_empty() or _is_teleporting:
		return
	var f := NetworkTime.tick_factor
	if _debug and _from.has("global_position") and _to.has("global_position"):
		print("TI | f=%.3f | from=%s | to=%s | result=%s" % [
			f, _from["global_position"], _to["global_position"],
			_lerp(_from["global_position"], _to["global_position"], f)
		])
	_interpolate(f)

## Record current state and skip interpolation for one frame (e.g. after a respawn).
func teleport() -> void:
	_snapshot_to()
	_from = _to.duplicate()
	_is_teleporting = true

## Manually push the current property values as the new target state.
## Useful when [member record_first_state] is false or you update properties
## outside the normal tick loop.
func push_state() -> void:
	_from = _to.duplicate()
	_snapshot_to()

func _before_tick_loop() -> void:
	_is_teleporting = false
	# Restore the true simulation state so tick logic reads correct values.
	_apply(_to)

func _after_tick_loop() -> void:
	if _is_teleporting:
		return
	# Snapshot the post-tick state as the new target.
	_from = _to.duplicate()
	_snapshot_to()
	# Apply the starting state so _process can interpolate from here.
	_apply(_from)

func _snapshot_to() -> void:
	var parent := get_parent()
	for prop in properties:
		_to[prop] = parent.get(prop)

func _apply(state: Dictionary) -> void:
	var parent := get_parent()
	for prop in state:
		parent.set(prop, state[prop])

func _interpolate(f: float) -> void:
	var parent := get_parent()
	for prop in _from:
		if not _to.has(prop):
			continue
		var a = _from[prop]
		var b = _to[prop]
		if a == null or b == null:
			continue
		parent.set(prop, _lerp(a, b, f))

static func _lerp(a: Variant, b: Variant, t: float) -> Variant:
	if a is Transform3D:
		return (a as Transform3D).interpolate_with(b, t)
	if a is Quaternion:
		return (a as Quaternion).slerp(b, t)
	if a is float:
		return lerp_angle(a, b, t)
	return a.lerp(b, t)
