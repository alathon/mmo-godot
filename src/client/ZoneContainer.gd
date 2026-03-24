class_name ZoneContainer
extends Node3D

signal zone_border_entered(body: Node3D)

var _zone: Node = null
var _zone_id: String = ""

var entities: Node:
	get: return _zone.get_node("Entities") if _zone else null

func _exit_tree() -> void:
	if _zone_id != "":
		print("[CLIENT] Zone unloaded: %s" % _zone_id)

func load_zone(zone_id: String, player: Node3D = null) -> void:
	print("[CLIENT] Zone loading: %s" % zone_id)
	_zone_id = zone_id
	_zone = (load(Globals.ZONE_SCENES[zone_id]) as PackedScene).instantiate()
	add_child(_zone)
	for node in _zone.get_children():
		if node.is_in_group("server_only"):
			node.queue_free()
	_connect_zone_borders()
	print("[CLIENT] Zone loaded: %s" % zone_id)
	if player:
		entities.call_deferred("add_child", player)

func _connect_zone_borders() -> void:
	for border in get_tree().get_nodes_in_group("zone_borders"):
		if border is ZoneBorder and not border.body_entered.is_connected(_on_zone_border_entered):
			border.body_entered.connect(_on_zone_border_entered)

func _on_zone_border_entered(body: Node3D) -> void:
	zone_border_entered.emit(body)
