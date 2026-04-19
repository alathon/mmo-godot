class_name HealthBar
extends Node3D

@onready var bar: ProgressBar = $SubViewport/HealthBar

func set_values(current_hp: int, max_hp: int) -> void:
	bar.max_value = max(max_hp, 1)
	bar.value = clamp(current_hp, 0, bar.max_value)
