TODO:
- https://www.akhmorning.com/allagan-studies/how-to-be-a-math-wizard/shadowbringers/damage-and-healing/#direct-damage-d

I should reconsider how ability damage stuff works. The core idea of 'potency' and then all buffs being multiplicative
is probably good? The idea of potency being that your abilities scale with your stats, basically.. I wonder how
WoW, Monsters & Memories, etc. do it.

# Ability System

This document describes how to design abilities using the resource-based ability system. All abilities are defined as Godot `.tres` resource files and can be created and edited entirely within the Godot editor inspector.

## Quick Start

1. Right-click `resources/abilities/` in the FileSystem panel.
2. Create New Resource, pick **AbilityResource**, and save it (e.g. `fireball.tres`).
3. Fill in the inspector fields, including `ability_id` and `ability_name`.
4. Add effects by expanding the `effects` array and picking a subclass (DamageEffect, HealEffect, etc.).

---

## AbilityResource

The top-level resource that defines a single ability. One `.tres` file per ability, saved in `resources/abilities/`.

| Field | Type | Description |
|---|---|---|
| `ability_id` | int | Stable numeric ability ID used in runtime state and network packets. Must be unique and greater than 0. |
| `ability_name` | String | Human-readable ability name used for UI/logging. |
| `group_tags` | PackedStringArray | Grouping labels for this ability (e.g. `["fire_spell", "aoe_spell"]`). Used by AbilityModifiers to target groups of abilities at once. |
| `tags` | PackedStringArray | Descriptive tags for the ability itself (e.g. `["magic", "fire"]`). |
| `hit_type` | PHYSICAL / MAGICAL | Determines whether the ability uses the physical hit/miss system or the magical resist system. Must be set explicitly. |
| `variance_profile` | NONE / PLUS_MINUS_10_PCT / WEIGHTED_LOW_HIGH | Optional random spread applied by DamageResolver after formula evaluation. |
| `target_type` | SELF / OTHER_ENEMY / OTHER_FRIEND / OTHER_ANY / GROUND | Who or what the caster must target to use this ability. |
| `cast_time` | float | Seconds of casting before the ability fires. 0 = instant cast. |
| `range` | float | Maximum distance to the target. |
| `uses_gcd` | bool | Whether using this ability triggers the global cooldown. |
| `cooldown` | float | Cooldown in seconds. For charge-based abilities, this is the recharge time per charge. 0 = no cooldown. |
| `max_charges` | int | Maximum charges. 1 = normal single-use cooldown. Values above 1 enable charge-based cooldowns: the ability can be used as long as charges remain, and one charge recharges every `cooldown` seconds. Only one charge recharges at a time, and using additional charges does not interrupt the current recharge timer. |
| `cooldown_group` | String | Shared cooldown group ID. Abilities with the same group share a cooldown timer. Empty = no shared cooldown. |
| `mana_cost` | int | Mana consumed on cast. |
| `stamina_cost` | int | Stamina consumed on cast. |
| `energy_cost` | int | Energy consumed on cast. |
| `effects` | Array[AbilityEffect] | The effects that fire when the ability lands. See **Effects** below. |
| `conditional_effects` | Array[ConditionalEffect] | Effects that only apply when a runtime condition is met. See **Conditional Effects** below. |
| `target_selectors` | Array[TargetSelector] | Additional target selection logic for multi-target abilities. See **Target Selectors** below. |
| **AOE group** | | |
| `aoe_shape` | NONE / CIRCLE / CONE | The shape of the area-of-effect. Only relevant for GROUND-targeted abilities. |
| `aoe_radius` | float | Radius (or size) of the AoE area. |

**Ability ID:** Set `ability_id` explicitly in the resource. Keep it stable once shipped.

---

## Effects

Effects define what happens when an ability lands. Each effect is a Resource subclass of **AbilityEffect**. You add them to an ability's `effects` array by picking the specific subclass you want in the inspector.

### Base Fields (on all effects)

Every effect type inherits these fields from AbilityEffect:

| Field | Type | Description |
|---|---|---|
| `effect_id` | StringName | Optional. An ID for this specific effect. Only needed if an AbilityModifier needs to remove or reference this effect. Leave blank otherwise. |
| `tags` | PackedStringArray | Tags on this specific effect (e.g. `["fire"]`). These are set explicitly per effect and are **not** inherited from the ability's tags. Used for resistance lookups and other per-effect logic. |
| `proc_chance` | float (1-100) | Percentage chance this effect activates when the ability lands. 100 = guaranteed. An effect with proc_chance of 30 will only fire 30% of the time, even if the ability itself hits. |
| `target_narrower` | ALL / HOSTILE / FRIENDLY | Narrows which targets in an AoE this effect applies to. For example, Holy Nova can have a DamageEffect with target_narrower=HOSTILE and a HealEffect with target_narrower=FRIENDLY. |
| `target_selector_id` | StringName | If set, this effect applies to targets picked by the named TargetSelector instead of the primary target. See **Target Selectors**. |

### Effect Types

#### DamageEffect

Deals damage to the target.

| Field | Type | Description |
|---|---|---|
| `formula` | ValueFormula | The damage value. Can scale with caster stats. See **ValueFormula**. |
| `aggro_modifier` | float | Multiplier on threat generated. 1.0 = normal threat. 2.0 = double threat. |

#### HealEffect

Restores health to the target.

| Field | Type | Description |
|---|---|---|
| `formula` | ValueFormula | The heal value. Can scale with caster stats. |
| `aggro_modifier` | float | Threat multiplier. Heals typically use a lower value (e.g. 0.5) since healing threat is split across all enemies. |

#### ApplyStatusEffect

Applies a status effect (buff or debuff) to the target. This is the only way to create ticking/persistent effects.

| Field | Type | Description |
|---|---|---|
| `status` | StatusResource | Reference to a status resource in `resources/statuses/`. |
| `duration` | float | How long the status lasts in seconds. 0 = permanent (until removed). |
| `max_stacks` | int | Maximum number of stacks. Re-applying the status when at max stacks refreshes the duration instead. |
| `tick_interval` | float | Seconds between ticks. Defaults to 3.0. |
| `tick_effects` | Array[AbilityEffect] | Effects that fire on each tick (e.g. a DamageEffect for a DoT, a HealEffect for a HoT). |

Statuses are defined in standalone `StatusResource` files. Identity is `status_id` (numeric).

#### DisplacementEffect

Moves the target or caster.

| Field | Type | Description |
|---|---|---|
| `displacement_type` | KNOCKBACK / PULL / DASH / TELEPORT | The kind of movement. |
| `force` | float | How strong the displacement is. |
| `duration_ticks` | int | How many ticks the displacement lasts (for gradual knockbacks/pulls). |

#### DispelEffect

Removes status effects from the target.

| Field | Type | Description |
|---|---|---|
| `dispel_category` | String | Which category of status effects to remove (e.g. `"magic"`). Empty = remove any. |
| `max_effects` | int | Maximum number of status effects to remove in one cast. |

#### ConsumeStacksEffect

Consumes stacks of a status effect and fires additional effects per stack consumed.

| Field | Type | Description |
|---|---|---|
| `status_id` | int | Numeric `status_id` of the ApplyStatusEffect whose stacks to consume. |
| `per_stack_effects` | Array[AbilityEffect] | Effects fired once per stack consumed (e.g. a DamageEffect that scales by stack count). |

---

## ValueFormula

A formula that evaluates to a number based on a base value plus optional stat scaling. Used for damage/heal values and ability modifier multipliers.

| Field | Type | Description |
|---|---|---|
| `base` | float | The starting value. |
| `components` | Array[StatComponent] | Optional stat-scaling terms added to the base. |

Each **StatComponent** has:

| Field | Type | Description |
|---|---|---|
| `stat` | StatType enum | Which stat to read: SPELL_POWER, ATTACK_POWER, STRENGTH, INTELLIGENCE, AGILITY, or STAMINA. |
| `coefficient` | float | Multiplied by the stat value and added to the result. |

**Formula:** `result = base + (stat_1 * coeff_1) + (stat_2 * coeff_2) + ...`

### Examples

- **Flat 120 damage:** base=120, no components.
- **50 + 80% of Spell Power:** base=50, one component with stat=SPELL_POWER and coefficient=0.8.
- **Pure stat scaling:** base=0, one component with stat=ATTACK_POWER and coefficient=1.2.

---

## Procs

Any effect can be made into a proc by setting `proc_chance` to a value less than 100. When the ability lands and all non-proc effects apply, each proc-based effect rolls independently against its proc_chance percentage.

- `proc_chance = 100` (default): The effect always applies when the ability hits.
- `proc_chance = 30`: The effect has a 30% chance to apply per cast that hits.
- `proc_chance = 1`: Extremely rare proc (1% chance).

Proc chances are independent per effect. If an ability has two proc effects (30% and 50%), each rolls separately.

---

## Conditional Effects

A **ConditionalEffect** is an effect modification that only applies when a runtime condition is true. Add them to the ability's `conditional_effects` array.

| Field | Type | Description |
|---|---|---|
| `condition` | ConditionResource | The condition to evaluate at cast time. |
| `mod` | AbilityMod | The modification to apply if the condition is met. See **AbilityMod**. |

### Available Conditions

All conditions have a `negate` checkbox that inverts the result.

| Condition | Fields | Description |
|---|---|---|
| **ConditionTargetHpBelow** | `threshold` (0.0-1.0) | True if the target's HP is below the given fraction. 0.2 = below 20%. |
| **ConditionCasterHasStatus** | `status_id` (int) | True if the caster currently has the status effect ID active. |
| **ConditionTargetHasTag** | `tag` (String) | True if the target currently has the named tag (e.g. from an active status effect). |

### Example: Execute-style finisher

Add a ConditionalEffect with:
- Condition: ConditionTargetHpBelow, threshold=0.2
- Mod: AbilityMod with damage_multiplier base=2.0

Result: when the target is below 20% HP, all damage from this ability is doubled.

---

## Ability Modifiers

**AbilityModifiers** are standalone resources that modify abilities from outside. They live in `resources/ability_modifiers/` and are not part of the ability itself. They represent modifications granted by talents, gear, buffs, or other game systems.

An **AbilityModifier** has:

| Field | Type | Description |
|---|---|---|
| `target_type` | ABILITY_ID / ABILITY_GROUP_TAG | Whether this modifier targets one specific ability or all abilities in a group. |
| `target_value` | StringName | The ability ID or group tag to match. |
| `mod` | AbilityMod | The modification payload. |

### AbilityMod (shared payload)

Both AbilityModifier and ConditionalEffect use the same **AbilityMod** resource to describe what changes:

**Multipliers** (ValueFormula, null = no change):

| Field | Description |
|---|---|
| `cast_time_multiplier` | Multiply the ability's cast time. base=0.5 halves cast time. |
| `resource_cost_multiplier` | Multiply mana/stamina/energy cost. |
| `range_multiplier` | Multiply the ability's range. |
| `damage_multiplier` | Multiply all DamageEffect values. |
| `heal_multiplier` | Multiply all HealEffect values. |

Since multipliers are ValueFormulas, they can scale with caster stats. For example, a talent that reduces cast time based on intelligence: base=1.0 with a StatComponent of INTELLIGENCE at coefficient=-0.01 (1% reduction per point of intelligence).

**Structural changes:**

| Field | Type | Description |
|---|---|---|
| `added_effects` | Array[AbilityEffect] | Extra effects injected into the ability. |
| `removed_effect_ids` | Array[StringName] | Effects to remove, matched by their `effect_id`. |

### Example: Talent that adds a DoT to Fireball

Create an AbilityModifier in `resources/ability_modifiers/`:
- target_type: ABILITY_ID
- target_value: `"fireball"`
- mod: AbilityMod with added_effects containing an ApplyStatusEffect (burning DoT)

### Example: Talent that reduces all fire spell cast times by 30%

- target_type: ABILITY_GROUP_TAG
- target_value: `"fire_spell"`
- mod: AbilityMod with cast_time_multiplier base=0.7

---

## Target Selectors

By default, all effects in an ability apply to the primary target (or all targets in an AoE). **Target Selectors** enable multi-target abilities where different effects apply to different dynamically-selected targets.

### How it works

1. Add TargetSelector resources to the ability's `target_selectors` array. Give each a unique `selector_id`.
2. On any effect, set `target_selector_id` to the selector's ID. That effect will apply to the targets picked by the selector instead of the primary target.
3. Effects with no `target_selector_id` still apply to the primary target as normal.

### Base Fields (on all selectors)

| Field | Type | Description |
|---|---|---|
| `selector_id` | StringName | The ID that effects reference. |
| `allow_caster` | bool | Whether the caster can be selected. Default false. |
| `allow_target` | bool | Whether the primary target can be selected. Default false. |

### Selector Types

#### NearestTargetsSelector

Picks the N nearest entities matching a filter.

| Field | Type | Description |
|---|---|---|
| `filter` | ENEMIES / ALLIES / ANY | Which entities to consider. |
| `count` | int | How many targets to pick. |
| `max_distance` | float | Maximum range. 0 = unlimited. |
| `exclude_primary` | bool | Skip the primary target of the ability. |

#### LowestHpTargetsSelector

Picks the N entities with the lowest current HP.

| Field | Type | Description |
|---|---|---|
| `filter` | ENEMIES / ALLIES / ANY | Which entities to consider. |
| `count` | int | How many targets to pick. |
| `exclude_primary` | bool | Skip the primary target. |

#### RandomTargetsSelector

Picks N random entities matching a filter.

| Field | Type | Description |
|---|---|---|
| `filter` | ENEMIES / ALLIES / ANY | Which entities to consider. |
| `count` | int | How many targets to pick. |
| `exclude_primary` | bool | Skip the primary target. |

#### ChainTargetsSelector

Chains from the primary target to additional nearby entities, one link at a time. Each link selects from entities near the *previous* link, not the caster.

| Field | Type | Description |
|---|---|---|
| `filter` | ENEMIES / ALLIES / ANY | Which entities to chain to. |
| `chain_count` | int | Number of additional targets after the primary. |
| `max_link_distance` | float | Maximum distance between consecutive chain links. |
| `can_rehit` | bool | Whether the chain can bounce back to previously-hit targets. |
| `damage_falloff` | float | Multiplier applied per link. 1.0 = no falloff. 0.8 = each link does 80% of the previous. |

### Example: Chain Lightning

```
AbilityResource (chain_lightning.tres)
  target_type: OTHER_ENEMY
  target_selectors:
    - ChainTargetsSelector
        selector_id: "chain"
        filter: ENEMIES
        chain_count: 2
        max_link_distance: 15.0
        damage_falloff: 0.7
  effects:
    - DamageEffect
        formula: ValueFormula { base: 100 }
        target_selector_id: "chain"
```

Hits the primary target, then chains to 2 additional nearby enemies. Each link does 70% of the previous link's damage.

### Example: Heal Lowest 2 Allies (not yourself)

```
AbilityResource (prayer_of_mending.tres)
  target_type: SELF
  target_selectors:
    - LowestHpTargetsSelector
        selector_id: "weakest"
        filter: ALLIES
        count: 2
        allow_caster: false
  effects:
    - HealEffect
        formula: ValueFormula { base: 80 }
        target_selector_id: "weakest"
```

### Example: Damage Enemy + Heal Lowest Ally

```
AbilityResource (life_drain.tres)
  target_type: OTHER_ENEMY
  target_selectors:
    - LowestHpTargetsSelector
        selector_id: "ally_heal"
        filter: ALLIES
        count: 1
        allow_caster: true
  effects:
    - DamageEffect
        formula: ValueFormula { base: 60 }
    - HealEffect
        formula: ValueFormula { base: 40 }
        target_selector_id: "ally_heal"
```

The DamageEffect hits the targeted enemy (no selector). The HealEffect goes to the lowest-HP ally (which could be the caster since allow_caster is true).

---

## Hit Resolution

When an ability is cast, the server resolves whether it hits:

- **Physical abilities** (hit_type=PHYSICAL): Roll hit vs. miss based on attacker/defender stats.
- **Magical abilities** (hit_type=MAGICAL): Roll resist vs. not-resist based on caster/target stats.

If the ability **misses or is resisted**, no effects are applied at all.

If the ability **hits**:
1. All effects with `proc_chance = 100` apply.
2. Each effect with `proc_chance < 100` rolls independently. On success, it applies; on failure, it is skipped for this cast.
3. Each ConditionalEffect evaluates its condition. If met, the AbilityMod is applied to this cast (multipliers, added/removed effects).
4. AbilityModifiers from the caster's talents/gear/buffs are folded in.

---

## File Organization

```
src/common/combat/
  CombatConstants.gd          -- Global combat timing and reason codes
  AbilityDatabase.gd          -- Loads all .tres abilities from resources/abilities/
  abilities/
    AbilityResource.gd        -- Top-level ability definition
    AbilityMod.gd             -- Shared modification payload (multipliers + structural)
    AbilityModifier.gd        -- External modifier (talents, gear) targeting abilities by ID or group
    ConditionalEffect.gd      -- Condition + AbilityMod, evaluated at cast time
    ValueFormula.gd            -- Base value + stat scaling
    StatComponent.gd           -- Single stat * coefficient term
    effects/
      AbilityEffect.gd        -- Base class for all effects
      DamageEffect.gd
      HealEffect.gd
      ApplyStatusEffect.gd    -- Buffs, debuffs, DoTs, HoTs
      DisplacementEffect.gd   -- Knockback, pull, dash, teleport
      DispelEffect.gd         -- Remove status effects
      ConsumeStacksEffect.gd  -- Consume stacks and fire per-stack effects
    conditions/
      ConditionResource.gd    -- Base class for conditions
      ConditionTargetHpBelow.gd
      ConditionCasterHasStatus.gd
      ConditionTargetHasTag.gd
    target_selectors/
      TargetSelector.gd       -- Base class for selectors
      NearestTargetsSelector.gd
      LowestHpTargetsSelector.gd
      RandomTargetsSelector.gd
      ChainTargetsSelector.gd

resources/
  abilities/                   -- .tres files for AbilityResource instances
  statuses/                    -- .tres files for StatusResource instances
  ability_modifiers/           -- .tres files for AbilityModifier instances
```
