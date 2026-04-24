class_name GroundTargetPreview
extends Node3D

const DECAL_TEXTURE_PATH: String = "res://assets/effects/target_decal.png"
const DECAL_HEIGHT: float = 2.0
const DECAL_LIFT: float = 0.5
const DISC_LIFT: float = 0.03
const ROTATION_SPEED: float = 0.6
const DISC_COLOR: Color = Color(1.0, 0.35, 0.02, 0.28)

var _decal: Decal
var _disc: MeshInstance3D


func _init() -> void:
	_decal = Decal.new()
	_decal.name = "Decal"
	_decal.cull_mask = 1 << 1
	add_child(_decal)

	_disc = MeshInstance3D.new()
	_disc.name = "OrangeDisc"
	_disc.layers = 1 << 1
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)

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
	_disc.mesh = null
	visible = false


func _configure_circle(radius: float) -> void:
	var texture: Texture2D = ResourceLoader.load(DECAL_TEXTURE_PATH) as Texture2D
	if texture == null:
		clear()
		return

	var diameter: float = radius * 2.0
	_decal.texture_albedo = texture
	_decal.size = Vector3(diameter, DECAL_HEIGHT, diameter)
	_configure_disc(radius)


func _configure_disc(radius: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 96
	mesh.rings = 1

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = DISC_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_disc.mesh = mesh
	_disc.material_override = material
	_disc.position = Vector3.DOWN * (DECAL_LIFT - DISC_LIFT)
