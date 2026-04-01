class_name AbilityDef

# target_type values
const TARGET_SELF: String = "self"
const TARGET_OTHER_ENEMY: String = "other_enemy"
const TARGET_OTHER_FRIEND: String = "other_friend"
const TARGET_OTHER_ANY: String = "other_any"
const TARGET_GROUND: String = "ground"

# aoe shape values
const AOE_CIRCLE: String = "circle"

var id: String = ""
var name: String = ""
var tags: Array = []         # Array[String]
var target_type: String = ""
var cast_time: float = 0.0
var range: float = 0.0
var gcd: bool = true
var cooldown: float = 0.0
var cooldown_group: String = "" # "" = no group
var resource_cost: Dictionary = {}
var effects: Array = []       # Array[EffectDef]

# AOE (only valid when target_type == TARGET_GROUND)
var aoe_shape: String = ""    # "" = no AOE
var aoe_radius: float = 0.0


static func from_dict(d: Dictionary) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = d.get("id", "")
	a.name = d.get("name", "")
	a.tags = d.get("tags", [])
	a.target_type = d.get("target_type", "")
	a.cast_time = float(d.get("cast_time", 0.0))
	a.range = float(d.get("range", 0.0))
	a.gcd = bool(d.get("gcd", true))
	a.cooldown = float(d.get("cooldown", 0.0))
	a.cooldown_group = d.get("cooldown_group", "") if d.get("cooldown_group") != null else ""
	a.resource_cost = d.get("resource_cost", {})
	for effect in d.get("effects", []):
		a.effects.append(EffectDef.from_dict(effect))
	var aoe: Dictionary = d.get("aoe", {})
	if not aoe.is_empty():
		a.aoe_shape = aoe.get("shape", "")
		a.aoe_radius = float(aoe.get("radius", 0.0))
	return a
