class_name Stats
extends Node

@export var max_hp: int = 100
@export var max_mana: int = 100
@export var max_stamina: int = 100

var hp: int
var mana: int
var stamina: int


func _ready() -> void:
	hp = max_hp
	mana = max_mana
	stamina = max_stamina


func has_resource(resource: String, cost: int) -> bool:
	match resource:
		"mana":    return mana >= cost
		"stamina": return stamina >= cost
		"hp":      return hp > cost  # must survive the spend
	return true


func spend_resource(resource: String, cost: int) -> void:
	match resource:
		"mana":    mana -= cost
		"stamina": stamina -= cost
		"hp":      hp -= cost
	_clamp()


func restore_hp(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


func is_dead() -> bool:
	return hp <= 0


func _clamp() -> void:
	hp      = clampi(hp,      0, max_hp)
	mana    = clampi(mana,    0, max_mana)
	stamina = clampi(stamina, 0, max_stamina)
