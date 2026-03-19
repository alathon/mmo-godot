class_name ZoneBorder
extends Area3D

## The zone_id of the destination zone.
@export var target_zone_id: String = ""

## Where the player appears in the destination zone (world coordinates in that zone).
@export var target_entry_position: Vector3 = Vector3.ZERO

## Facing direction on arrival (radians).
@export var target_entry_rotation_y: float = 0.0
