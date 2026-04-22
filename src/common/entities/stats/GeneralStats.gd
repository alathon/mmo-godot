class_name GeneralStats
extends Node

signal stat_changed(stat: StringName, value: Variant)

var hp: int = 100:
	set = set_hp

var max_hp: int = 100:
	set = set_max_hp

var mana: int = 100
var max_mana: int = 100
var stamina: int = 100
var max_stamina: int = 100

func set_hp(value: int):
	if hp == value:
		return
	hp = value
	stat_changed.emit("hp", value)

func set_max_hp(value: int):
	if max_hp == value:
		return
	max_hp = value
	stat_changed.emit("max_hp", value)
