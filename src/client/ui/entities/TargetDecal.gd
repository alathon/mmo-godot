class_name TargetDecal
extends Node3D

const TERRAIN_RENDER_LAYER_MASK := 1 << 1
const DECAL_HEIGHT := 2.0

@onready var decal: Decal = %Decal

func _ready() -> void:
	decal.cull_mask = TERRAIN_RENDER_LAYER_MASK
	decal.size.y = DECAL_HEIGHT

func set_radius(radius: float) -> void:
	var diameter: float = radius * 2.0
	decal.size.x = diameter
	decal.size.y = DECAL_HEIGHT
	decal.size.z = diameter
