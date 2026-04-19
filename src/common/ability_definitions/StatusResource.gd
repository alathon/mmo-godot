class_name StatusResource
extends Resource

@export var status_id: int = 0
@export var status_name: String = ""
@export var is_debuff: bool = false
@export var icon: Texture2D
@export var dispel_category: String = ""    # "" = cannot be dispelled
@export var tags_applied: PackedStringArray = []
@export var tags_locked: PackedStringArray = []
