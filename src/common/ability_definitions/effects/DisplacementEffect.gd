class_name DisplacementEffect
extends AbilityEffect

enum DisplacementType {
	KNOCKBACK,
	PULL,
	DASH,
	TELEPORT,
}

@export var displacement_type: DisplacementType = DisplacementType.KNOCKBACK
@export var force: float = 0.0
@export var duration_ticks: int = 0
