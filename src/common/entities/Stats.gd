class_name Stats
extends Node

@export var max_hp: int = 100
@export var max_mana: int = 100
@export var max_stamina: int = 100
@export var max_energy: int = 100

var hp: int = 0
var mana: int = 0
var stamina: int = 0
var energy: int = 0


func _ready() -> void:
	if hp <= 0:
		hp = max_hp
	if mana <= 0:
		mana = max_mana
	if stamina <= 0:
		stamina = max_stamina
	if energy <= 0:
		energy = max_energy
