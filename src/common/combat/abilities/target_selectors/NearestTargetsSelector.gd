class_name NearestTargetsSelector
extends TargetSelector

@export var filter: TargetFilter = TargetFilter.ENEMIES
@export var count: int = 1
@export var max_distance: float = 0.0   # 0 = unlimited
@export var exclude_primary: bool = true
