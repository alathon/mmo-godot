class_name Stats
extends Node

const Proto = preload("res://src/common/proto/packets.gd")

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


func apply_world_state(state: Proto.EntityState) -> void:
	if state == null:
		return
	hp = state.get_hp()
	max_hp = state.get_max_hp()
	mana = state.get_mana()
	max_mana = state.get_max_mana()
	stamina = state.get_stamina()
	max_stamina = state.get_max_stamina()
	
	
