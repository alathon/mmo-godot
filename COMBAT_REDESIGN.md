Current [CombatSystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/CombatSystem.gd) is doing too many jobs at once: tick orchestration, protobuf ACKs/events, per-entity cast state, GCD, cooldowns, resource spending, validation, target resolution, and effect dispatch.

The better split is:

```text
AbilitySystem
  World-level ability orchestration.
  Ticked by the server.
  Translates ability input protobufs.
  Dispatches accepted/rejected ACKs.
  Advances every entity's AbilityManager.
  Resolves ability target specs.
  Applies ability effects.
  Emits ability events and hands combat-relevant events to CombatSystem.

AbilityManager
  Per-entity ability-use surface.
  Owns cast state, GCD, animation lock, ability cooldowns, queued ability,
  resource validation/spending, and use_ability(...).

CombatSystem
  World-level combat orchestration only.
  Tracks combat engagement, combat event buffering, combat event protobuf
  translation, combat target validity, death/combatant lifecycle, and later
  threat/aggro.

CombatManager
  Per-entity combat surface.
  Owns in-combat state, threat table later, faction/reaction helpers,
  combat flags, and combat-only validation/callbacks.
```

The key correction is: GCD, casting, cooldowns, queueing, and resource costs are not combat concepts. They are ability-use concepts. Combat is one consumer/domain of ability use. You can recall, fish, gather, interact, or perform other non-combat abilities while still using the same cast bar, GCD, cooldowns, and resource rules.

Selected target is also not exclusively combat state. A player can select players and NPCs outside combat. Target selection should live at the entity level, for example `entity.set_target_entity_id(...)`, not inside `CombatManager`.

One important current mismatch: [CombatSystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/CombatSystem.gd):278 calls `stats.get_combat_stats()`, but [Stats.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/Stats.gd) does not currently define that. The new skeleton should make that contract explicit, either as `Stats.get_combat_stats()` or as a separate `CombatStatBlock`.

**Recommended Shape**

```text
src/common/abilities/
  AbilityConstants.gd
  AbilityManager.gd
  AbilityState.gd
  AbilityCooldowns.gd
  AbilityUseRequest.gd
  AbilityUseResult.gd
  AbilityValidationResult.gd
  AbilityTargetSpec.gd
  AbilityExecutionContext.gd
  AbilityEvent.gd
  AbilityEventCodec.gd

src/common/entities/
  EntityTargetState.gd
  CombatManager.gd
  Stats.gd

src/common/combat/
  CombatConstants.gd
  CombatEvent.gd
  CombatEventCodec.gd
  DamageResolver.gd
  HitResolver.gd

src/common/combat/abilities/
  AbilityResource.gd
  effects/
    AbilityEffect.gd
    DamageEffect.gd
    HealEffect.gd
    ApplyStatusEffect.gd
    ConsumeStacksEffect.gd
    DispelEffect.gd
    DisplacementEffect.gd

src/game-server/systems/
  AbilitySystem.gd
  AbilityTargeting.gd
  CombatSystem.gd
  CombatTargeting.gd
```

Longer-term, `src/common/combat/abilities/AbilityResource.gd` probably wants to become `src/common/abilities/AbilityResource.gd`, because fishing, recall, and other non-combat abilities should not live under `combat`. I would not force that move in the first skeleton unless we are ready for path churn.

**Flat Mob Shape**

Use the flat shape under `Mob`:

```text
Mob
  Stats               # Stats.gd
  EntityTarget        # EntityTargetState.gd
  AbilityState        # AbilityState.gd
  AbilityCooldowns    # AbilityCooldowns.gd
  AbilityManager      # AbilityManager.gd
  CombatManager       # CombatManager.gd
```

Then expose the entity-level APIs from `ServerPlayer.gd`:

```gdscript
@onready var ability_manager: AbilityManager = $Mob/AbilityManager
@onready var combat_manager: CombatManager = $Mob/CombatManager
@onready var target_state: EntityTargetState = $Mob/EntityTarget

func set_target_entity_id(entity_id: int) -> void:
	target_state.set_target_entity_id(entity_id)

func get_target_entity_id() -> int:
	return target_state.get_target_entity_id()

func clear_target() -> void:
	target_state.clear_target()

# Optional aliases if we want entity.abilityManager / entity.combatManager style.
var abilityManager: AbilityManager:
	get:
		return ability_manager

var combatManager: CombatManager:
	get:
		return combat_manager
```

**EntityTargetState**

Target selection is entity-level state, not combat state.

```gdscript
class_name EntityTargetState
extends Node

var target_entity_id: int = 0

func set_target_entity_id(entity_id: int) -> void
func get_target_entity_id() -> int
func has_target() -> bool
func clear_target() -> void
```

`CombatManager` can ask the entity for its selected target when a combat ability uses the current target, but it should not own that target.

**AbilityState**

`AbilityState` is the renamed version of the current `CombatState` timing data, minus selected target.

```gdscript
class_name AbilityState
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0

var cast_ability_id: StringName = &""
var cast_target: AbilityTargetSpec
var cast_total: float = 0.0
var cast_remaining: float = 0.0
var cast_requested_tick: int = 0
var cast_start_tick: int = 0

var queued_ability_id: StringName = &""
var queued_target: AbilityTargetSpec
var queued_requested_tick: int = 0

func is_casting() -> bool
func has_queued() -> bool
func clear_cast() -> void
func clear_queued() -> void
```

**AbilityCooldowns**

`AbilityCooldowns` is the renamed version of the current `Cooldowns` node.

```gdscript
class_name AbilityCooldowns
extends Node

var _ability: Dictionary = {}
var _group: Dictionary = {}

func tick(delta: float) -> void
func is_ready(ability_id: StringName, cooldown_group: StringName) -> bool
func start(ability_id: StringName, cooldown: float, cooldown_group: StringName) -> void
func cancel(ability_id: StringName, cooldown_group: StringName) -> void
func get_ability_remaining(ability_id: StringName) -> float
func get_group_remaining(group_id: StringName) -> float
```

**AbilitySystem**

`AbilitySystem` should own the world-level sequencing of ability use. It should not decide combat engagement or threat, but it can delegate combat-specific checks to `CombatSystem`.

```gdscript
class_name AbilitySystem
extends Node

func init(zone: Node, combat_system: CombatSystem) -> void

func tick(sim_tick: int, ctx: Dictionary) -> void

func handle_ability_input(entity_id: int, input: Dictionary, sim_tick: int) -> void

func has_events() -> bool
func build_ability_events_proto(ability_events_msg, sim_tick: int) -> void

func get_entity(entity_id: int) -> Node
func get_ability_manager(entity_id: int) -> AbilityManager

func resolve_targets(
	source_entity: Node,
	ability: AbilityResource,
	target: AbilityTargetSpec
) -> Array[Node]

func is_in_range(
	source_entity: Node,
	ability: AbilityResource,
	target: AbilityTargetSpec
) -> bool
```

Suggested private methods:

```gdscript
func _process_movement_cancels(moving_entities: Dictionary, sim_tick: int) -> void
func _process_ability_inputs(ability_inputs: Dictionary, sim_tick: int) -> void
func _tick_ability_managers(sim_tick: int) -> void
func _flush_ack_queue() -> void

func _make_execution_context(sim_tick: int) -> AbilityExecutionContext
func _enqueue_ack(result: AbilityUseResult) -> void
func _append_events(events: Array[AbilityEvent]) -> void
func _forward_combat_events(events: Array[AbilityEvent], context: AbilityExecutionContext) -> void
```

Current mapping:

```text
CombatSystem._process_ability_input      -> AbilityManager.use_ability(...)
CombatSystem._advance_and_resolve        -> AbilityManager.tick(...)
CombatSystem._start_cast                 -> AbilityManager._start_cast(...)
CombatSystem._resolve_cast               -> AbilityManager._complete_cast(...)
CombatSystem._cancel_cast                -> AbilityManager.cancel_casting(...)
CombatSystem._dequeue_ability            -> AbilityManager._try_dequeue_ability(...)
CombatSystem._validate                   -> AbilityManager.can_use_ability(...)
CombatSystem._has_resources              -> AbilityManager.has_resources_for(...)
CombatSystem._spend_resources            -> AbilityManager.spend_resources_for(...)
CombatSystem._apply_effect               -> AbilityEffect.apply(...)
CombatSystem._check_range / _get_targets -> AbilitySystem / AbilityTargeting
CombatSystem.build_combat_events_proto   -> AbilityEventCodec and CombatEventCodec
```

Tick order in `ServerZone` becomes:

```gdscript
_input_system.tick(sim_tick, ctx)
_movement_system.tick(sim_tick, ctx)
_ability_system.tick(sim_tick, ctx)
_combat_system.tick(sim_tick, ctx)
_world_state_system.tick(sim_tick, ctx)
_world_positions_system.tick(sim_tick, ctx)
```

`AbilitySystem.tick()` should cancel casts on movement because casting is ability state:

```gdscript
for entity_id in moving_entities:
	var ability_manager := get_ability_manager(entity_id)
	if ability_manager and ability_manager.is_casting():
		ability_manager.cancel_casting(AbilityConstants.CANCEL_MOVED, context)
```

The cancel reason constants should move from `CombatConstants` to `AbilityConstants` when they describe ability-use outcomes.

**AbilityManager**

This is the entity-facing ability surface. It owns GCD, cast state, animation lock, cooldowns, queueing, and resource checks for one entity.

```gdscript
class_name AbilityManager
extends Node

@export var state_path: NodePath = ^"../AbilityState"
@export var cooldowns_path: NodePath = ^"../AbilityCooldowns"
@export var stats_path: NodePath = ^"../Stats"
@export var combat_manager_path: NodePath = ^"../CombatManager"

@onready var state: AbilityState = get_node(state_path)
@onready var cooldowns: AbilityCooldowns = get_node(cooldowns_path)
@onready var stats: Stats = get_node(stats_path)
@onready var combat_manager: CombatManager = get_node_or_null(combat_manager_path)

var entity: Node

func init(owner_entity: Node) -> void

func tick(
	delta: float,
	sim_tick: int,
	context: AbilityExecutionContext
) -> Array[AbilityEvent]

func use_ability(
	ability_id: StringName,
	target: AbilityTargetSpec,
	requested_tick: int,
	context: AbilityExecutionContext
) -> AbilityUseResult

func can_use_ability(
	ability: AbilityResource,
	target: AbilityTargetSpec,
	context: AbilityExecutionContext,
	allow_queue: bool = false
) -> AbilityValidationResult

func has_resources_for(ability: AbilityResource) -> bool
func spend_resources_for(ability: AbilityResource) -> void

func is_casting() -> bool
func is_on_gcd() -> bool
func is_animation_locked() -> bool
func get_gcd_remaining() -> float
func get_cooldown_remaining(ability_id: StringName) -> float

func cancel_casting(reason: int, context: AbilityExecutionContext) -> Array[AbilityEvent]
func clear_queued_ability() -> void
```

Private methods:

```gdscript
func _start_cast(request: AbilityUseRequest, ability: AbilityResource, sim_tick: int) -> Array[AbilityEvent]
func _complete_cast(sim_tick: int, context: AbilityExecutionContext) -> Array[AbilityEvent]
func _resolve_ability(request: AbilityUseRequest, ability: AbilityResource, context: AbilityExecutionContext) -> Array[AbilityEvent]

func _queue_ability(request: AbilityUseRequest) -> void
func _try_dequeue_ability(sim_tick: int, context: AbilityExecutionContext) -> Array[AbilityEvent]

func _in_cast_queue_window() -> bool
func _in_gcd_queue_window() -> bool
func _apply_gcd(ability: AbilityResource) -> void
func _apply_cooldown(ability: AbilityResource) -> void
func _cancel_cooldown(ability: AbilityResource) -> void
```

This gives the ability API:

```gdscript
entity.ability_manager.use_ability(&"fireball", target, tick, context)
entity.ability_manager.is_casting()
entity.ability_manager.cancel_casting(AbilityConstants.CANCEL_MOVED, context)
entity.ability_manager.can_use_ability(ability, target, context)
entity.ability_manager.has_resources_for(ability)
```

And leaves combat-only state in the combat API:

```gdscript
entity.combat_manager.is_in_combat()
entity.combat_manager.can_target(target_entity, ability, context)
entity.combat_manager.on_damage_taken(source_entity, amount, ability, context)
```

**CombatSystem**

`CombatSystem` should stay responsible for the combat stack only. It should not handle ability input directly and should not own GCD/cast/cooldown sequencing.

```gdscript
class_name CombatSystem
extends Node

func init(zone: Node) -> void

func tick(sim_tick: int, ctx: Dictionary) -> void

func get_combat_manager(entity_id: int) -> CombatManager

func is_valid_combat_target(
	source_entity: Node,
	target_entity: Node,
	ability: AbilityResource
) -> bool

func is_in_combat_range(
	source_entity: Node,
	target_entity: Node,
	ability: AbilityResource
) -> bool

func on_ability_resolved(
	source_entity: Node,
	ability: AbilityResource,
	target_entities: Array[Node],
	ability_events: Array[AbilityEvent],
	context: AbilityExecutionContext
) -> Array[CombatEvent]

func has_events() -> bool
func build_combat_events_proto(combat_events_msg, sim_tick: int) -> void
```

Suggested private methods:

```gdscript
func _append_events(events: Array[CombatEvent]) -> void
func _check_deaths(source_entity: Node, target_entities: Array[Node], context: AbilityExecutionContext) -> Array[CombatEvent]
func _update_combat_engagement(source_entity: Node, target_entities: Array[Node], events: Array[AbilityEvent], context: AbilityExecutionContext) -> void
func _get_entity(entity_id: int) -> Node
```

**CombatManager**

`CombatManager` owns one entity's combat-only state and hooks. It does not own selected target, GCD, casts, cooldowns, queueing, or generic resource checks.

```gdscript
class_name CombatManager
extends Node

@export var stats_path: NodePath = ^"../Stats"

@onready var stats: Stats = get_node(stats_path)

var entity: Node
var combat_started_tick: int = 0
var last_combat_event_tick: int = 0

func init(owner_entity: Node) -> void

func is_in_combat() -> bool
func enter_combat(source_entity: Node, sim_tick: int) -> void
func leave_combat(sim_tick: int) -> void

func can_target(
	target_entity: Node,
	ability: AbilityResource,
	context: AbilityExecutionContext
) -> AbilityValidationResult

func is_hostile_to(target_entity: Node) -> bool
func is_friendly_to(target_entity: Node) -> bool
func is_alive() -> bool

func on_ability_landed(
	source_entity: Node,
	target_entities: Array[Node],
	ability: AbilityResource,
	events: Array[AbilityEvent],
	context: AbilityExecutionContext
) -> Array[CombatEvent]

func on_damage_dealt(target_entity: Node, amount: int, ability: AbilityResource, context: AbilityExecutionContext) -> void
func on_damage_taken(source_entity: Node, amount: int, ability: AbilityResource, context: AbilityExecutionContext) -> void
func on_healing_done(target_entity: Node, amount: int, ability: AbilityResource, context: AbilityExecutionContext) -> void
func on_combatant_died(killer_entity: Node, context: AbilityExecutionContext) -> CombatEvent
```

**AbilityTargeting**

`AbilityTargeting` resolves ability target specs for all abilities, not just combat abilities.

```gdscript
class_name AbilityTargeting
extends RefCounted

func init(zone: Node, combat_system: CombatSystem) -> void

func resolve_targets(
	source_entity: Node,
	ability: AbilityResource,
	target: AbilityTargetSpec
) -> Array[Node]

func get_valid_targets_for(
	source_entity: Node,
	ability: AbilityResource
) -> Array[Node]

func is_valid_target(
	source_entity: Node,
	target_entity: Node,
	ability: AbilityResource
) -> bool

func is_in_range(
	source_entity: Node,
	ability: AbilityResource,
	target: AbilityTargetSpec
) -> bool

func get_entity_position(entity: Node) -> Vector3
func get_entity_by_id(entity_id: int) -> Node
```

Combat-specific target validity can be delegated:

```gdscript
if ability_is_combat_ability:
	return combat_system.is_valid_combat_target(source_entity, target_entity, ability)
```

**CombatTargeting**

`CombatTargeting` contains combat-only target rules: hostility, friendliness, alive/dead rules, faction/reaction, line-of-sight later, and combat-specific range constraints if those diverge from generic ability range.

```gdscript
class_name CombatTargeting
extends RefCounted

func init(zone: Node) -> void

func is_valid_combat_target(
	source_entity: Node,
	target_entity: Node,
	ability: AbilityResource
) -> bool

func is_hostile_target(source_entity: Node, target_entity: Node) -> bool
func is_friendly_target(source_entity: Node, target_entity: Node) -> bool
func is_alive_target(target_entity: Node) -> bool
func is_in_combat_range(source_entity: Node, target_entity: Node, ability: AbilityResource) -> bool
```

**Effects**

Effects stay on abilities, but their API becomes neutral:

```gdscript
class_name AbilityEffect
extends Resource

func apply(
	source_entity: Node,
	target_entities: Array[Node],
	context: AbilityExecutionContext
) -> Array[AbilityEvent]:
	return []
```

The ideal shape is still:

```gdscript
effect.apply(source_entity, target_entities, context) -> Array[AbilityEvent]
```

Passing `AbilityExecutionContext` avoids globals and gives effects access to the current ability, damage resolver, RNG, sim tick, hit result, combat system, and event helpers.

Example concrete API:

```gdscript
class_name DamageEffect
extends AbilityEffect

@export var formula: ValueFormula
@export var aggro_modifier: float = 1.0

func apply(
	source_entity: Node,
	target_entities: Array[Node],
	context: AbilityExecutionContext
) -> Array[AbilityEvent]:
	var events: Array[AbilityEvent] = []
	for target_entity in target_entities:
		var amount := context.damage_resolver.resolve_damage(
			self,
			context.ability,
			context.source_stats
		)
		target_entity.combat_manager.stats.take_damage(amount)
		events.append(AbilityEvent.damage_taken(
			source_entity,
			target_entity,
			context.ability_id,
			amount
		))
	return events
```

Same shape for `HealEffect`, `ApplyStatusEffect`, `DisplacementEffect`, `DispelEffect`, `RecallEffect`, `FishingEffect`, etc.

**Small Data Classes**

These keep the manager/system APIs from passing loose dictionaries everywhere.

```gdscript
class_name AbilityUseRequest
extends RefCounted

var source_entity_id: int
var ability_id: StringName
var target: AbilityTargetSpec
var requested_tick: int
```

```gdscript
class_name AbilityTargetSpec
extends RefCounted

enum Kind { NONE, ENTITY, GROUND, SELF, CURRENT_TARGET }

var kind: Kind = Kind.NONE
var entity_id: int = 0
var ground_position: Vector3 = Vector3.ZERO

static func self_target() -> AbilityTargetSpec
static func current_target() -> AbilityTargetSpec
static func entity(entity_id: int) -> AbilityTargetSpec
static func ground(position: Vector3) -> AbilityTargetSpec
```

`CURRENT_TARGET` resolves through the entity-level `EntityTargetState`, not through `CombatManager`.

```gdscript
class_name AbilityValidationResult
extends RefCounted

var ok: bool = false
var reason: StringName = &""
var cancel_reason: int = AbilityConstants.CANCEL_INVALID

static func accepted() -> AbilityValidationResult
static func rejected(reason: StringName, cancel_reason: int) -> AbilityValidationResult
```

```gdscript
class_name AbilityUseResult
extends RefCounted

var accepted: bool = false
var ability_id: StringName
var requested_tick: int
var start_tick: int = 0
var reject_reason: int = AbilityConstants.CANCEL_INVALID
var events: Array[AbilityEvent] = []
```

```gdscript
class_name AbilityExecutionContext
extends RefCounted

var sim_tick: int
var delta: float
var ability: AbilityResource
var ability_id: StringName
var source_stats: Dictionary

var ability_system: AbilitySystem
var combat_system: CombatSystem
var ability_db: AbilityDatabase
var damage_resolver: DamageResolver
var hit_resolver: HitResolver
```

**AbilityEvent**

Ability events cover generic ability-use events and ability effects that need replication. Combat-specific events can either be mirrored into `CombatEvent` or kept here initially for less churn.

```gdscript
class_name AbilityEvent
extends RefCounted

enum Type {
	ABILITY_USE_STARTED,
	ABILITY_USE_CANCELED,
	ABILITY_USE_COMPLETED,
	DAMAGE_TAKEN,
	HEALING_RECEIVED,
	RECALL_STARTED,
	RECALL_COMPLETED,
	GATHER_ATTEMPTED,
}

var type: Type
var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: StringName = &""
var amount: float = 0.0
var cancel_reason: int = 0
var hit_type: int = 0
var ground_position: Vector3 = Vector3.ZERO
var cast_time: float = 0.0

static func ability_started(...) -> AbilityEvent
static func ability_canceled(...) -> AbilityEvent
static func ability_completed(...) -> AbilityEvent
static func damage_taken(...) -> AbilityEvent
static func healing_received(...) -> AbilityEvent
static func recall_started(...) -> AbilityEvent
static func recall_completed(...) -> AbilityEvent
static func gather_attempted(...) -> AbilityEvent
```

Then:

```gdscript
class_name AbilityEventCodec
extends RefCounted

static func write_tick_events(msg, events: Array[AbilityEvent], sim_tick: int) -> void
static func write_event(msg, event: AbilityEvent, sim_tick: int) -> void
```

**CombatEvent**

Combat events are reserved for combat lifecycle and combat-specific replication.

```gdscript
class_name CombatEvent
extends RefCounted

enum Type {
	COMBAT_STARTED,
	COMBAT_ENDED,
	COMBATANT_DIED,
	BUFF_APPLIED,
	DEBUFF_APPLIED,
	STATUS_EFFECT_REMOVED,
}

var type: Type
var source_entity_id: int = 0
var target_entity_id: int = 0
var ability_id: StringName = &""
var entity_id: int = 0
var killer_entity_id: int = 0
var status_effect_id: StringName = &""
var remove_reason: int = 0

static func combat_started(...) -> CombatEvent
static func combat_ended(...) -> CombatEvent
static func combatant_died(...) -> CombatEvent
static func buff_applied(...) -> CombatEvent
static func debuff_applied(...) -> CombatEvent
static func status_effect_removed(...) -> CombatEvent
```

Then:

```gdscript
class_name CombatEventCodec
extends RefCounted

static func write_tick_events(msg, events: Array[CombatEvent], sim_tick: int) -> void
static func write_event(msg, event: CombatEvent, sim_tick: int) -> void
```

**Design Boundary**

```text
AbilitySystem
  Owns tick order for ability use, input translation, world lookup,
  generic target/range queries, ability event buffering, ACK sending,
  and ability protobuf translation.

AbilityManager
  Owns one entity's ability-use state: GCD, animation lock, cooldowns,
  cast lifecycle, queueing, resource checks, and the public ability API.

EntityTargetState
  Owns selected target for the entity, independent of combat.

CombatSystem
  Owns combat event buffering, combat event protobuf translation,
  combat engagement/death lifecycle, and combat-only target rules.

CombatManager
  Owns one entity's combat-only state: in-combat state, hostility/faction
  checks, threat/aggro later, and combat lifecycle callbacks.

AbilityEffect
  Owns effect-specific application logic and returns AbilityEvent objects.

AbilityEventCodec / CombatEventCodec
  Own translation from event objects to protobuf messages.
```

That keeps recall, fishing, gathering, and interaction abilities out of `CombatManager`, while still letting combat abilities use the same ability pipeline. `CombatSystem` remains authoritative for combat-only consequences, but the ability pipeline no longer pretends every ability is combat.
