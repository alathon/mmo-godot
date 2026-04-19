class_name TargetSelectionIndicator
extends Node

const TargetDecalScene := preload("res://src/client/ui/entities/TargetDecal.tscn")
const TARGET_DECAL_OFFSET := Vector3(0, -0.95, 0)

var _decal: Node3D = null
var _target: Node3D = null

func _ready() -> void:
	_decal = TargetDecalScene.instantiate()
	add_child(_decal)
	_decal.visible = false

func set_target(target: Node3D) -> void:
	if target == _target:
		print("[TARGET_INDICATOR] target unchanged target=%s decal_parent=%s" % [
			_target_name(target), _target_name(_decal.get_parent())])
		return

	_target = target
	if _target == null:
		clear()
		return

	_reparent_decal(_target)
	_decal.position = TARGET_DECAL_OFFSET
	_decal.visible = true
	print("[TARGET_INDICATOR] target=%s decal_parent=%s visible=%s position=%s" % [
		_target_name(_target), _target_name(_decal.get_parent()), _decal.visible, _decal.position])

func clear() -> void:
	if _decal == null:
		return

	_target = null
	_decal.visible = false
	_reparent_decal(self)
	_decal.position = Vector3.ZERO
	print("[TARGET_INDICATOR] clear decal_parent=%s" % _target_name(_decal.get_parent()))

func clear_if_target(target: Node) -> void:
	if target == _target:
		clear()

func _reparent_decal(new_parent: Node) -> void:
	if _decal.get_parent() == new_parent:
		return

	if _decal.get_parent() != null:
		_decal.get_parent().remove_child(_decal)

	new_parent.add_child(_decal)

func _target_name(target: Node) -> String:
	if target == null:
		return "<null>"
	return "%s(%s)" % [target.name, target.get_path()]
