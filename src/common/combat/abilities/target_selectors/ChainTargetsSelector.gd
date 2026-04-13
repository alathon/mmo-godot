class_name ChainTargetsSelector
extends TargetSelector

@export var filter: TargetFilter = TargetFilter.ENEMIES
@export var chain_count: int = 2            # number of additional targets after the primary
@export var max_link_distance: float = 15.0 # max distance between consecutive chain links
@export var can_rehit: bool = false         # whether the chain can bounce back to already-hit targets
@export var damage_falloff: float = 1.0    # multiplier applied per link; 1.0 = no falloff, 0.8 = 80% per link
