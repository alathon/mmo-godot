class_name GroundTargetPreview
extends Node3D

const DECAL_TEXTURE_PATH: String = "res://assets/effects/target_decal.png"
const DECAL_HEIGHT: float = 2.0
const DECAL_LIFT: float = 0.5
const ROTATION_SPEED: float = 0.6
const DECAL_TINT: Color = Color(1.0, 0.45, 0.08, 1.0)

var _decal: Decal


func _init() -> void:
	_decal = Decal.new()
	_decal.name = "Decal"
	_decal.cull_mask = 1 << 1
	add_child(_decal)

	visible = false


func _process(delta: float) -> void:
	if visible:
		_decal.rotate_y(ROTATION_SPEED * delta)


func configure(ability: AbilityResource) -> void:
	if ability == null:
		clear()
		return

	match ability.aoe_shape:
		AbilityResource.AoeShape.CIRCLE:
			if ability.aoe_radius <= 0.0:
				clear()
				return
			_configure_circle(ability.aoe_radius)
		_:
			clear()


func set_target_position(position: Vector3) -> void:
	global_position = position + Vector3.UP * DECAL_LIFT
	visible = _decal.texture_albedo != null


func hide_preview() -> void:
	visible = false


func clear() -> void:
	_decal.texture_albedo = null
	visible = false


func _configure_circle(radius: float) -> void:
	var texture: Texture2D = ResourceLoader.load(DECAL_TEXTURE_PATH) as Texture2D
	if texture == null:
		clear()
		return

	var diameter: float = radius * 2.0
	_decal.texture_albedo = texture
	_decal.modulate = DECAL_TINT
	_decal.size = Vector3(diameter, DECAL_HEIGHT, diameter)
