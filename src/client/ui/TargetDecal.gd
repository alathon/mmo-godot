class_name TargetDecal
extends Node3D

@onready var decal: Decal = %Decal

func set_radius(radius: float) -> void:
	var diameter := radius * 2.0
	decal.size.x = diameter
	decal.size.z = diameter
