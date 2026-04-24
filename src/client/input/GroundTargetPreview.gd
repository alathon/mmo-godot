class_name GroundTargetPreview
extends Node3D

const DOME_RINGS: int = 8
const DOME_SEGMENTS: int = 64
const BASE_LIFT: float = 0.04

var _mesh_instance: MeshInstance3D
var _base_ring: MeshInstance3D


func _init() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Dome"
	add_child(_mesh_instance)

	_base_ring = MeshInstance3D.new()
	_base_ring.name = "BaseRing"
	add_child(_base_ring)

	visible = false


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
	global_position = position + Vector3.UP * BASE_LIFT
	visible = _mesh_instance.mesh != null


func hide_preview() -> void:
	visible = false


func clear() -> void:
	_mesh_instance.mesh = null
	_base_ring.mesh = null
	visible = false


func _configure_circle(radius: float) -> void:
	_mesh_instance.mesh = _build_hemisphere_mesh(radius)
	_mesh_instance.material_override = _make_dome_material()

	_base_ring.mesh = _build_base_ring_mesh(radius)
	_base_ring.material_override = _make_ring_material()


func _build_hemisphere_mesh(radius: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for ring_index in range(DOME_RINGS + 1):
		var phi: float = (float(ring_index) / float(DOME_RINGS)) * PI * 0.5
		var ring_radius: float = cos(phi) * radius
		var y: float = sin(phi) * radius

		for segment_index in range(DOME_SEGMENTS):
			var theta: float = (float(segment_index) / float(DOME_SEGMENTS)) * TAU
			vertices.append(Vector3(cos(theta) * ring_radius, y, sin(theta) * ring_radius))

	for ring_index in range(DOME_RINGS):
		for segment_index in range(DOME_SEGMENTS):
			var current: int = ring_index * DOME_SEGMENTS + segment_index
			var next: int = ring_index * DOME_SEGMENTS + ((segment_index + 1) % DOME_SEGMENTS)
			var above: int = (ring_index + 1) * DOME_SEGMENTS + segment_index
			var above_next: int = (ring_index + 1) * DOME_SEGMENTS + ((segment_index + 1) % DOME_SEGMENTS)

			indices.append(current)
			indices.append(above)
			indices.append(next)
			indices.append(next)
			indices.append(above)
			indices.append(above_next)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_base_ring_mesh(radius: float) -> ArrayMesh:
	var inner_radius: float = maxf(radius - 0.08, radius * 0.97)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for segment_index in range(DOME_SEGMENTS):
		var theta: float = (float(segment_index) / float(DOME_SEGMENTS)) * TAU
		var direction: Vector3 = Vector3(cos(theta), 0.0, sin(theta))
		vertices.append(direction * inner_radius)
		vertices.append(direction * radius)

	for segment_index in range(DOME_SEGMENTS):
		var inner_current: int = segment_index * 2
		var outer_current: int = inner_current + 1
		var inner_next: int = ((segment_index + 1) % DOME_SEGMENTS) * 2
		var outer_next: int = inner_next + 1

		indices.append(inner_current)
		indices.append(outer_current)
		indices.append(inner_next)
		indices.append(inner_next)
		indices.append(outer_current)
		indices.append(outer_next)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_dome_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.28, 0.08, 0.18)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material


func _make_ring_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.42, 0.1, 0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material
