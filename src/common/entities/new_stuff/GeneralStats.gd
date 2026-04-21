class_name GeneralStats
extends Node

signal stat_changed(stat: StringName, value: Variant)

var hp: int = 100:
	set = set_hp

var max_hp: int = 100:
	set = set_max_hp

var mana: int = 100
var max_mana: int = 100

func set_hp(value: int):
	if hp != value:
		stat_changed.emit("hp", value)
	hp = value

func set_max_hp(value: int):
	if max_hp != value:
		stat_changed.emit("max_hp", value)
	max_hp = value
