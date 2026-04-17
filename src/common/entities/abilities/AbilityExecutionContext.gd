class_name AbilityExecutionContext
extends RefCounted

var sim_tick: int = 0
var source_entity_id: int = 0
var delta: float = 0.0
var ability: AbilityResource = null
var ability_id: StringName = &""
var source_stats: Dictionary = {}

var ability_system: Node = null
var combat_system: Node = null
var ability_db: AbilityDatabase = null
