class_name TickInterpolator
extends Node

## Interpolates between network ticks for smooth visual motion.
##
## Properties are expressed as strings relative to [member target].
## For the target's own properties, use "property_name"
## (e.g. "global_transform"). For sub-node properties, use
## "ChildNode:property" (e.g. "Visual:visible").

@onready var _game_manager: GameManager = %GameManager

## The node whose properties (and sub-tree) are resolved against.
@export var target: Node

## Property paths to interpolate, relative to target.
## e.g. ["global_transform", "Visual:visible"]
@export var properties: Array[String]

## Toggles interpolation on/off.
@export var enabled: bool = false

## If true, takes an initial snapshot on _ready so objects that move immediately
## don't pop from the origin.
@export var record_first_state: bool = true

# Cached resolved properties: Array of { node: Node, property: StringName }
var _resolved: Array = []

var _from: Dictionary = {}  # int index -> value
var _to: Dictionary = {}
var _is_teleporting: bool = false

func _ready() -> void:
	_resolve_properties()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	if record_first_state and target != null:
		_snapshot_to()
		_from = _to.duplicate()
	_game_manager.zone_before_unloading.connect(_on_zone_unloading)
	_game_manager.player_spawned.connect(_on_player_spawned)

func _exit_tree() -> void:
	NetworkTime.before_tick_loop.disconnect(_before_tick_loop)
	NetworkTime.after_tick_loop.disconnect(_after_tick_loop)

func _process(_delta: float) -> void:
	if not enabled or _resolved.is_empty() or _is_teleporting:
		return
	_interpolate(NetworkTime.tick_factor)

## Record current state and skip interpolation for one frame (e.g. after a respawn).
func teleport() -> void:
	_snapshot_to()
	_from = _to.duplicate()
	_is_teleporting = true

## Manually push the current property values as the new target state.
func push_state() -> void:
	_from = _to.duplicate()
	_snapshot_to()

func _on_zone_unloading() -> void:
	target = null
	_resolved.clear()
	_from.clear()
	_to.clear()

func _on_player_spawned(player: Player) -> void:
	target = player
	_resolve_properties()

## Re-resolve property paths. Call if target or properties change at runtime.
func _resolve_properties() -> void:
	_resolved.clear()
	for path_str in properties:
		var path := NodePath(path_str)
		var node: Node
		var prop: StringName
		# If the path has subnames (e.g. ":global_transform" or "Child:prop"),
		# split into node path + property name.
		if path.get_subname_count() > 0:
			var node_path := NodePath(path.get_concatenated_names())
			if node_path.is_empty():
				node = target
			else:
				node = target.get_node_or_null(node_path)
			prop = StringName(path.get_concatenated_subnames())
		else:
			# No subnames — treat the whole string as a property on target.
			node = target
			prop = StringName(path_str)
		if node == null:
			push_warning("TickInterpolator: could not resolve node for '%s'" % path_str)
			continue
		_resolved.append({ "node": node, "property": prop })

func _before_tick_loop() -> void:
	_is_teleporting = false
	_apply(_to)

func _after_tick_loop() -> void:
	if _is_teleporting:
		return
	_from = _to.duplicate()
	_snapshot_to()
	_apply(_from)

func _snapshot_to() -> void:
	for i in _resolved.size():
		var r = _resolved[i]
		_to[i] = r.node.get(r.property)

func _apply(state: Dictionary) -> void:
	for i in state:
		var r = _resolved[i]
		r.node.set(r.property, state[i])

func _interpolate(f: float) -> void:
	for i in _from:
		if not _to.has(i):
			continue
		var a = _from[i]
		var b = _to[i]
		if a == null or b == null:
			continue
		var r = _resolved[i]
		r.node.set(r.property, _lerp(a, b, f))

static func _lerp(a: Variant, b: Variant, t: float) -> Variant:
	if a is Transform3D:
		return (a as Transform3D).interpolate_with(b, t)
	if a is Quaternion:
		return (a as Quaternion).slerp(b, t)
	if a is float:
		return lerp_angle(a, b, t)
	return a.lerp(b, t)
