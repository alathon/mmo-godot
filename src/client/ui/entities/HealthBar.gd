class_name HealthBar
extends Node3D

@onready var bar: ProgressBar = $SubViewport/HealthBar

# This script requires that the owner has an EntityState
var _general_stats: GeneralStats

func _ready():
	_general_stats = owner.get_node("%EntityState/%GeneralStats")
	_general_stats.stat_changed.connect(_on_stat_changed)
	set_values(_general_stats.hp, _general_stats.max_hp)

func set_values(current_hp: int, max_hp: int) -> void:
	bar.max_value = max(max_hp, 1)
	bar.value = clamp(current_hp, 0, bar.max_value)

func _on_stat_changed(stat: StringName, _value: Variant):
	if stat == "hp" or stat == "max_hp":
		set_values(_general_stats.hp, _general_stats.max_hp)
