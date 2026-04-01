class_name EffectDef

# effect type strings
const TYPE_DAMAGE: String = "damage"
const TYPE_HEAL: String = "heal"
const TYPE_STATUS_EFFECT: String = "status_effect"
const TYPE_DISPLACEMENT: String = "displacement"
const TYPE_DISPEL: String = "dispel"
const TYPE_CONSUME_STACKS: String = "consume_stacks"

# target_type_narrower values
const NARROWER_HOSTILE: String = "hostile"
const NARROWER_FRIENDLY: String = "friendly"

# displacement_type values
const DISPLACEMENT_KNOCKBACK: String = "knockback"
const DISPLACEMENT_PULL: String = "pull"
const DISPLACEMENT_DASH: String = "dash"
const DISPLACEMENT_TELEPORT: String = "teleport"

var type: String = ""

# damage / heal
var base_value: float = 0.0
var aggro_modifier: float = 1.0
var target_type_narrower: String = "" # "" = apply to all

# status_effect
var status_id: String = ""
var is_debuff: bool = false
var duration: float = 0.0       # 0 = permanent
var max_stacks: int = 1
var tick_interval: float = CombatConstants.STATUS_EFFECT_DEFAULT_TICK
var dispel_category: String = "" # "" = cannot be dispelled
var tick_effects: Array = []     # Array[EffectDef]
var tags_applied: Array = []     # Array[String]
var tags_locked: Array = []      # Array[String]

# displacement
var displacement_type: String = ""
var force: float = 0.0
var duration_ticks: int = 0

# dispel
var max_effects: int = 1

# consume_stacks
var per_stack_effects: Array = [] # Array[EffectDef]


static func from_dict(d: Dictionary) -> EffectDef:
	var e := EffectDef.new()
	e.type = d.get("type", "")
	e.base_value = float(d.get("base_value", 0.0))
	e.aggro_modifier = float(d.get("aggro_modifier", 1.0))
	e.target_type_narrower = d.get("target_type_narrower", "")

	e.status_id = d.get("status_id", "")
	e.is_debuff = bool(d.get("is_debuff", false))
	e.duration = float(d.get("duration", 0.0))
	e.max_stacks = int(d.get("max_stacks", 1))
	e.tick_interval = float(d.get("tick_interval", CombatConstants.STATUS_EFFECT_DEFAULT_TICK))
	e.dispel_category = d.get("dispel_category", "") if d.get("dispel_category") != null else ""
	e.tags_applied = d.get("tags_applied", [])
	e.tags_locked = d.get("tags_locked", [])
	for te in d.get("tick_effects", []):
		e.tick_effects.append(EffectDef.from_dict(te))

	e.displacement_type = d.get("displacement_type", "")
	e.force = float(d.get("force", 0.0))
	e.duration_ticks = int(d.get("duration_ticks", 0))

	e.max_effects = int(d.get("max_effects", 1))

	for pe in d.get("per_stack_effects", []):
		e.per_stack_effects.append(EffectDef.from_dict(pe))

	return e
