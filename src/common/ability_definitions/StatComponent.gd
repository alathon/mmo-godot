class_name StatComponent
extends Resource

enum StatType {
	SPELL_POWER,
	ATTACK_POWER,
	STRENGTH,
	INTELLIGENCE,
	AGILITY,
	STAMINA,
}

@export var stat: StatType = StatType.SPELL_POWER
@export var coefficient: float = 1.0
