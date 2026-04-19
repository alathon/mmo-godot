class_name ApplyStatusEffect
extends AbilityEffect

@export var display_name: String = ""
@export var status_id: int = 0
@export var icon: Texture2D
@export var is_debuff: bool = false
@export var duration: float = 0.0           # 0 = permanent
@export var max_stacks: int = 1
@export var tick_interval: float = CombatConstants.STATUS_EFFECT_DEFAULT_TICK
@export var dispel_category: String = ""    # "" = cannot be dispelled
@export var tags_applied: PackedStringArray = []
@export var tags_locked: PackedStringArray = []
@export var tick_effects: Array[AbilityEffect] = []
