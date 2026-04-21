class_name TargetSelectionIndicator
extends Node

const TargetDecalScene := preload("res://src/client/ui/entities/TargetDecal.tscn")
const TARGET_DECAL_OFFSET := Vector3(0, -0.95, 0)

var _decal: Node3D = null
var _target: Node = null
var _entity_state: EntityState = null

@onready var _game_manager: GameManager = %GameManager

func _ready() -> void:
	_decal = TargetDecalScene.instantiate()
	add_child(_decal)
	_decal.visible = false
	
	_game_manager.local_player_spawned.connect(_on_local_player_spawned)

func _on_local_player_spawned(player: PlayerNew):
	if _entity_state != null and _entity_state.target_changed.is_connected(_on_target_changed):
		_entity_state.target_changed.disconnect(_on_target_changed)
	
	_entity_state = player.entity_state
	_entity_state.target_changed.connect(_on_target_changed)
	_on_target_changed(_entity_state.current_target)

func _on_target_changed(target: Node):
	var decal_parent := target.get_node_or_null("%Model") as Node3D if target != null else null
	if decal_parent == null:
		_clear_decal()
		return

	_show_decal_on(decal_parent)

func _reparent_decal(parent: Node):
	if _decal.get_parent() != null:
		_decal.get_parent().remove_child(_decal)
	
	parent.add_child(_decal)
	

func _clear_decal() -> void:
	if _decal == null:
		return

	_decal.visible = false
	_reparent_decal(self)

func _show_decal_on(parent: Node3D):
	_reparent_decal(parent)
	_decal.visible = true
	_decal.position = TARGET_DECAL_OFFSET
