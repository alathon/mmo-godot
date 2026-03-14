class_name Interpolator
extends Node

# Smoothly interpolates a set of properties on the parent node between server snapshots.
# Usage: call push_snapshot({"global_position": vec3, "rotation": vec3, ...}) when a new
# server update arrives. The component lerps all tracked properties each frame.

var _entries: Dictionary = {}  # String -> {from: Variant, to: Variant}
var _t: float = 0.0

func push_snapshot(props: Dictionary) -> void:
	var parent = get_parent()
	for key in props:
		_entries[key] = { "from": parent.get(key), "to": props[key] }
	_t = 0.0

func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	_t += delta
	var alpha = clamp(_t / Globals.TICK_INTERVAL, 0.0, 1.0)
	var parent = get_parent()
	for key in _entries:
		var e: Dictionary = _entries[key]
		parent.set(key, _lerp(e.from, e.to, alpha))

static func _lerp(a: Variant, b: Variant, t: float) -> Variant:
	if a is Quaternion:
		return (a as Quaternion).slerp(b, t)
	return a.lerp(b, t)
