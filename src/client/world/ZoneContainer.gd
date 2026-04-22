class_name ZoneContainer
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

signal zone_border_entered(body: Node3D)
signal zone_before_unloading(zone_id: String)
signal zone_unloading(zone_id: String)
signal zone_before_loading(zone_id: String)
signal zone_loaded(zone_id: String)

var _zone: Node3D
var _zone_id: String
var _entities: Node
var _zone_ready: bool = false

var zone_ready:
	get:
		return _zone_ready

@onready var _game_manager: GameManager = $/root/Root/Services/GameManager

func add_entity(entity: Node):
	_entities.add_child(entity)

# TODO: Remove based on id or similar? We may as well just expose entities if we're doing this...
func remove_entity(entity: Node):
	_entities.remove_child(entity)

func unload_zone() -> void:
	if not _zone_id:
		return
	_zone_ready = false
	var zone_id = _zone_id
	zone_before_unloading.emit(_zone_id)
	_zone.queue_free()
	_entities = null
	zone_unloading.emit(_zone_id)
	print("[CLIENT] Zone unloaded: %s" % zone_id)

func load_zone(zone_id: String) -> void:
	zone_before_loading.emit(zone_id)
	print("[CLIENT] Zone loading: %s" % zone_id)
	_zone_id = zone_id
	_zone = (load(Globals.ZONE_SCENES[zone_id]) as PackedScene).instantiate()
	_zone.name = zone_id
	add_child(_zone)
	_entities = _zone.get_node("Entities")

	for node in _zone.get_children():
		if node.is_in_group("server_only"):
			node.queue_free()
	_connect_zone_borders()
	_zone_ready = true
	print("[CLIENT] Zone loaded: %s" % zone_id)
	zone_loaded.emit(zone_id)

# Subscribe to all zone border triggers.
func _connect_zone_borders() -> void:
	for border in get_tree().get_nodes_in_group("zone_borders"):
		if border is ZoneBorder and not border.body_entered.is_connected(_on_zone_border_entered):
			border.body_entered.connect(_on_zone_border_entered)

func _on_zone_border_entered(body: Node3D) -> void:
	zone_border_entered.emit(body)
