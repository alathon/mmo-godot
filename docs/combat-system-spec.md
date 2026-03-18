# Combat System Technical Specification

## 1. Overview

This document specifies the combat system for a server-authoritative PvE MMORPG built in Godot 4.6.1.
The system builds on the existing tick-based networking architecture (20 Hz tick rate, ENet, client-side
prediction with server reconciliation) and uses GDScript + JSON ability definitions + Godobuf for
client/server communication.

**Core design principles:**
- Server-authoritative: the server decides all hit/miss/crit/effect outcomes.
- Client-predictive: clients predict cast starts, self-displacement, and cast cancellations. They do NOT predict damage numbers, healing numbers, buff/debuff applications, or hit types.
- Data-driven: abilities are defined in JSON files, not hardcoded in scripts.
- Tick-aligned: all combat resolution happens within the existing 20 Hz tick loop. Nothing in this document, outside of animations, happens on a render frame basis.

---

## 2. Ability Lifecycle

### 2.1 States

An ability usage goes through these states:

```
[Idle] → [Ground Target Mode]* → [Casting] → [Combat Stack] → [Resolved]
                                      ↓
                                  [Canceled]
```

\* Only for `ground` target type abilities.

### 2.2 Ground Target Mode

When a player activates a ground-targeted ability, that ground-targeted ability must have a location.
To establish this location, the player enters **ground target mode** before casting begins:

- This is purely a client-side visual aide.
- The client shows an AOE indicator on the ground that follows the mouse cursor.
- The player can confirm placement by pressing the ability key again or left-clicking.
- The player can cancel by pressing Escape or right-clicking.
- While in ground target mode, no cast has started, no GCD is triggered, and no resources are spent. This is purely a client-side visual.
- Once the ground position is confirmed (by pressing ability key or left-clicking), that triggers an actual ability activation attempt.
- The confirmed ground position is sent to the server as part of the ability input message.

### 2.3 Casting

Ability activation attempts happen as part of a tick (not render frame). Once an ability is attempted activated:

1. **Resource check:** the client checks if the player has sufficient resources (mana, stamina). If not, the ability fails activation locally and is not sent.
2. **Cast begins:** the ability enters the `casting` state.
3. **GCD trigger:** if the ability is a GCD ability, the global cooldown (2.5s) begins.
4. **Ability cooldown trigger:** if the ability has its own cooldown, it also begins.
5. **Predictive cast:** the client begins the cast bar / animation immediately without waiting for server confirmation.
6. **Input message:** the ability activation is sent to the server as part of the input frame for this tick (see §7).

**Cast times:**
- **Instant (0s):** the ability immediately goes onto the combat stack for the current tick.
- **Non-zero (e.g. 3s):** the ability is `pending` for the cast duration. The caster cannot move during a cast. Any movement input or forced movement (knockback, stun) cancels the cast
immediately.

### 2.4 Cast Cancellation

A cast is canceled when:
- The player moves (client-side prediction: cancel immediately; server is notified through the input frame the move generates anyway).
- The server sends an explicit cancel (stun, silence, knockback, interrupt).
- The target dies before the cast completes.
- The server rejects the cast start (invalid target, out of range, insufficient resources on server).

**On cancellation:**
- If the ability was a GCD ability, the GCD cooldown is canceled.
- If there was a queued ability, the queue is also cleared.
- The client stops the cast animation/bar.

### 2.5 Ability Queuing

- A player can queue one GCD ability while another is casting or while the GCD is active.
- The queue window opens at **50% of the remaining cast time** or 50% of remaining GCD if the current ability, whichever is higher.
- Pressing a GCD ability before the queue window opens is ignored.
- If a queued ability already exists, additional queue attempts are ignored (no replacement).
- Canceling the current cast also cancels the queued ability.
- When the current cast completes (or GCD expires for instants), the queued ability begins casting if its conditions are still valid (target alive, in range, resources available). If conditions are invalid, the queue silently fails.

### 2.6 Combat Stack Resolution

On each server tick, all abilities that *would* resolve on that tick check again whether their resource needs are still met. If not, the ability is taken off the stack and gets canceled.

For all abilities that successfully resolve on that tick, they are placed onto the **combat stack**. The combat stack resolves all effects simultaneously, but in a defined priority order:

1. **Buffs** — beneficial status effects are applied.
2. **Debuffs** — harmful status effects are applied.
3. **Heals** — all healing effects resolve first.
4. **Damage** — all damage effects resolve second.
5. **Displacement** — knockbacks, pulls, etc. are applied last.

This ordering means that if a heal and lethal damage land on the same tick, the heal applies first — the target survives if heal + damage leaves them above 0 HP.
Similarly, a buff that increases healing landing in the same tick as a heal, works on that heal. But so does a debuff decreasing healing taken.

---

## 3. Ability Data Schema

Abilities are defined in JSON. Each ability file represents one ability.

### 3.1 Ability Definition

```json
{
  "id": "fireball",
  "name": "Fireball",
  "tags": ["magic", "fire"],
  "target_type": "other_enemy",
  "cast_time": 2.5,
  "range": 30.0,
  "gcd": true,
  "cooldown": 0.0,
  "cooldown_group": null,
  "resource_cost": {
    "mana": 40
  },
  "effects": [
    {
      "type": "damage",
      "base_value": 120,
      "aggro_modifier": 1.0
    }
  ]
}
```

### 3.2 Schema Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | Unique ability identifier. |
| `name` | `string` | yes | Display name. |
| `tags` | `string[]` | yes | Tags used for lockout/interrupt targeting (e.g. `["magic", "fire"]`). |
| `target_type` | `enum` | yes | One of: `self`, `other_enemy`, `other_friend`, `other_any`, `ground`. |
| `cast_time` | `float` | yes | Cast time in seconds. `0.0` = instant. |
| `range` | `float` | no | Max range in units. For `ground`: max distance from caster to target point. For entity targets: max distance from caster to target. Omit for `self` target abilities. |
| `gcd` | `bool` | yes | Whether this ability triggers the global cooldown. |
| `cooldown` | `float` | no | Ability-specific cooldown in seconds. `0.0` or omitted = no cooldown. |
| `cooldown_group` | `string` | no | If set, all abilities sharing this group string share the same cooldown timer. Using one puts all on cooldown. |
| `resource_cost` | `object` | no | Map of resource type → cost. e.g. `{"mana": 40, "stamina": 10}`. |
| `effects` | `Effect[]` | yes | Array of effects applied when the ability resolves. |
| `aoe` | `AOE` | no | AOE parameters. Only valid for `ground` target type. |

### 3.3 AOE Definition

```json
{
  "aoe": {
    "shape": "circle",
    "radius": 8.0,
    "persistent": false,
    "duration": 0.0,
    "tick_interval": 3.0
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `shape` | `enum` | yes | `circle` (extendable to `rectangle` later). |
| `radius` | `float` | yes | Radius in units (for circle). |
| `persistent` | `bool` | no | If `true`, the AOE persists on the ground after initial cast. |
| `duration` | `float` | cond | Duration in seconds for persistent AOEs. Required if `persistent` is `true`. |
| `tick_interval` | `float` | no | How often the persistent AOE re-applies its effects, in seconds. Default: `3.0`. |

### 3.4 Effect Types

Each effect in the `effects` array has a `type` field and type-specific parameters:

#### Damage

```json
{
  "type": "damage",
  "base_value": 120,
  "aggro_modifier": 1.0
}
```

| Field | Type | Description |
|---|---|---|
| `base_value` | `float` | Base damage before stat modifiers (stats TBD). |
| `aggro_modifier` | `float` | Multiplier on aggro generated. `1.0` = normal. `2.0` = double aggro. |

#### Heal

```json
{
  "type": "heal",
  "base_value": 80,
  "aggro_modifier": 0.5
}
```

Same schema as damage. Healing generates aggro on all mobs that have the healed target on their aggro list.

#### Status Effect (Buff/Debuff)

```json
{
  "type": "status_effect",
  "status_id": "burning",
  "is_debuff": true,
  "duration": 15.0,
  "max_stacks": 3,
  "tick_interval": 3.0,
  "dispel_category": "magic",
  "tick_effects": [
    {
      "type": "damage",
      "base_value": 20,
      "aggro_modifier": 1.0
    }
  ],
  "tags_locked": []
}
```

| Field | Type | Description |
|---|---|---|
| `status_id` | `string` | Unique ID for this status effect. Used to check stacking. |
| `is_debuff` | `bool` | Whether this is a debuff (harmful) or buff (beneficial). |
| `duration` | `float` | Duration in seconds. `0.0` or omitted = permanent (until dispelled/removed). |
| `max_stacks` | `int` | Maximum number of stacks. `1` = non-stacking. |
| `tick_interval` | `float` | How often tick effects are applied, in seconds. Default: `3.0`. |
| `dispel_category` | `string` | Category for dispel matching (e.g. `"magic"`, `"bleed"`, `"poison"`). `null` = cannot be dispelled. |
| `tick_effects` | `Effect[]` | Effects applied each tick (for DoTs/HoTs). |
| `tags_locked` | `string[]` | Ability tags that are locked while this debuff is active (for interrupts/silences). e.g. `["magic"]` prevents casting any ability with the `"magic"` tag. |

**Stacking rules:**
- When a stackable effect is reapplied, the stack count increases (up to `max_stacks`) and the duration is refreshed for all stacks.
- When `max_stacks` is `1`, reapplication refreshes the duration.

#### Displacement

```json
{
  "type": "displacement",
  "displacement_type": "knockback",
  "force": 15.0,
  "duration_ticks": 10
}
```

| Field | Type | Description |
|---|---|---|
| `displacement_type` | `enum` | `knockback` (away from caster), `pull` (toward caster), `dash` (caster moves forward), `teleport` (instant reposition). |
| `force` | `float` | Impulse force magnitude. Interpretation depends on displacement type. Not used for `teleport`. |
| `duration_ticks` | `int` | How many ticks the displacement impulse lasts. Uses existing `Impulse` / `ImpulseData` system with decay. Not used for `teleport`. |

**Note:** displacement effects cancel any active casts on the affected target (any movement cancels casts).

#### Dispel

```json
{
  "type": "dispel",
  "dispel_category": "magic",
  "max_effects": 1
}
```

| Field | Type | Description |
|---|---|---|
| `dispel_category` | `string` | Matches against `dispel_category` on status effects. Only removes effects with a matching category. |
| `max_effects` | `int` | Maximum number of matching effects to remove. |

#### Consume Stacks

```json
{
  "type": "consume_stacks",
  "status_id": "firebolt_charge",
  "per_stack_effects": [
    {
      "type": "damage",
      "base_value": 30,
      "aggro_modifier": 1.0
    }
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `status_id` | `string` | The status effect whose stacks are consumed. |
| `per_stack_effects` | `Effect[]` | Effects applied once per stack consumed. |

### 3.5 Example Abilities

#### Instant oGCD (Stun)

```json
{
  "id": "shield_bash",
  "name": "Shield Bash",
  "tags": ["physical", "melee"],
  "target_type": "other_enemy",
  "cast_time": 0.0,
  "range": 5.0,
  "gcd": false,
  "cooldown": 25.0,
  "resource_cost": {
    "stamina": 20
  },
  "effects": [
    {
      "type": "damage",
      "base_value": 30,
      "aggro_modifier": 2.0
    },
    {
      "type": "status_effect",
      "status_id": "stunned",
      "is_debuff": true,
      "duration": 3.0,
      "max_stacks": 1,
      "dispel_category": null,
      "tick_effects": [],
      "tags_locked": ["movement", "magic", "physical", "melee", "ranged"]
    }
  ]
}
```

#### Ground AOE (Persistent Fire Zone)

```json
{
  "id": "flame_zone",
  "name": "Flame Zone",
  "tags": ["magic", "fire"],
  "target_type": "ground",
  "cast_time": 2.0,
  "range": 25.0,
  "gcd": true,
  "cooldown": 30.0,
  "resource_cost": {
    "mana": 80
  },
  "effects": [
    {
      "type": "damage",
      "base_value": 50,
      "aggro_modifier": 1.0
    }
  ],
  "aoe": {
    "shape": "circle",
    "radius": 8.0,
    "persistent": true,
    "duration": 15.0,
    "tick_interval": 3.0
  }
}
```

#### Heal over Time

```json
{
  "id": "rejuvenate",
  "name": "Rejuvenate",
  "tags": ["magic", "nature"],
  "target_type": "other_friend",
  "cast_time": 0.0,
  "range": 30.0,
  "gcd": true,
  "cooldown": 0.0,
  "resource_cost": {
    "mana": 35
  },
  "effects": [
    {
      "type": "heal",
      "base_value": 20,
      "aggro_modifier": 0.5
    },
    {
      "type": "status_effect",
      "status_id": "rejuvenation",
      "is_debuff": false,
      "duration": 12.0,
      "max_stacks": 1,
      "dispel_category": "magic",
      "tick_interval": 3.0,
      "tick_effects": [
        {
          "type": "heal",
          "base_value": 15,
          "aggro_modifier": 0.5
        }
      ],
      "tags_locked": []
    }
  ]
}
```

#### Interrupt

```json
{
  "id": "kick",
  "name": "Kick",
  "tags": ["physical", "melee"],
  "target_type": "other_enemy",
  "cast_time": 0.0,
  "range": 5.0,
  "gcd": false,
  "cooldown": 15.0,
  "resource_cost": {},
  "effects": [
    {
      "type": "status_effect",
      "status_id": "magic_lockout",
      "is_debuff": true,
      "duration": 4.0,
      "max_stacks": 1,
      "dispel_category": null,
      "tick_effects": [],
      "tags_locked": ["magic"]
    }
  ]
}
```

---

## 4. Cooldown System

### 4.1 Global Cooldown (GCD)

- Duration: **2.5 seconds** (may be modified by stats in the future).
- Triggered when a `gcd: true` ability begins casting (not on completion).
- While the GCD is active, no other `gcd: true` ability can be activated.
- `gcd: false` abilities (oGCDs) are not affected by and do not trigger the GCD.
- If the cast that triggered the GCD is canceled, the GCD is also canceled.

### 4.2 Animation Lock / Internal Cooldown

- All abilities (GCD and oGCD) trigger a **0.7 second internal cooldown** (animation lock). If you move to cancel a cast, this internal cooldown is also canceled.
- This prevents any ability activation more often than every 0.7s.
- This is separate from the GCD — an oGCD used between two GCDs still triggers this 0.7s lock.

### 4.3 Ability Cooldowns

- Individual abilities can have their own cooldown (`cooldown` field).
- Cooldown begins when the ability starts casting.
- If the cast is canceled, the ability cooldown and the internal cooldown is also canceled (same as GCD).
- If `cooldown_group` is set, all abilities sharing that group string go on cooldown when any one of them is used.

### 4.4 Cooldown Tracking

- **Server:** authoritative cooldown tracking per entity. Rejects ability use if on cooldown.
- **Client:** predictive cooldown tracking for UI responsiveness. Corrected by server on rejection.
  - Important note: the server will ACK casts (as being accepted), but we don't *adjust* the client-side cast time
  to be the true server time on that ACK, even though we could. This means that even if you have 200ms lag, on the
  client you can feel like you're casting back-to-back spells; otherwise, when the server ACK'ed, you'd suddenly see
  your cast time *elongate* by 200ms. That isn't desirable. Instead, we accept that the server may consider an ability
  to resolve at a later tick than the client thinks.

---

## 5. Status Effect System

### 5.1 Status Effect State

Each active status effect on an entity tracks:

| Field | Type | Description |
|---|---|---|
| `status_id` | `string` | Which status effect this is. |
| `source_entity_id` | `uint32` | Who applied it. |
| `stacks` | `int` | Current stack count. |
| `remaining_duration` | `float` | Seconds remaining (0 = permanent). |
| `tick_timer` | `float` | Time until next tick effect application. |

### 5.2 Tick Effects

- Status effects with `tick_effects` apply those effects every `tick_interval` seconds (default 3s).
- Tick effects resolve through the normal combat stack on the tick they fire.
- Tick timing is tracked per-effect instance.

### 5.3 Tag Lockouts

- A status effect with `tags_locked: ["magic"]` prevents the affected entity from using any ability with the `"magic"` tag.
- Lockout is checked at cast start. If locked, the ability fails.
- Multiple lockouts can coexist (e.g., silenced + disarmed = both `"magic"` and `"physical"` locked).

### 5.4 Stun

- Stun is implemented as a status effect with `tags_locked` covering all relevant combat tags plus `"movement"`.
- The `"movement"` tag lock prevents all movement input processing and cancels active casts.
- Stun is not a special-case mechanic — it is a status effect that locks all action tags.

### 5.5 Diminishing Returns (DR)

- Successive applications of CC (crowd control) effects on the same target within a window have reduced duration.
- DR is tracked per DR category (separate from tags — e.g., all stuns share a DR group).
- DR progression: **100% → 50% → 25% → immune**.
- DR resets after a decay period (TBD, likely 15-20s after last application).
- DR is server-side only.

---

## 6. Aggro System

### 6.1 Aggro List

- Every NPC entity maintains an **aggro list**: a map of `entity_id → aggro_value`.
- The NPC targets the entity with the highest aggro value.
- Players do not have aggro lists.

### 6.2 Aggro Generation

Aggro is generated by:

1. **Using an ability on the NPC:** generates a small base amount of aggro.
2. **Effects that hit the NPC:** damage and debuffs generate aggro proportional to the effect value, multiplied by the effect's `aggro_modifier`.
3. **Healing an entity on the NPC's aggro list:** the healer gains aggro on that NPC proportional to the healing done, multiplied by the heal's `aggro_modifier`. This applies to all NPCs that have the healed target on their aggro list.
4. **Missed/dodged/blocked abilities:** still generate some aggro (reduced).

### 6.3 Aggro Formula (Placeholder)

```
aggro_generated = base_value * aggro_modifier * hit_type_modifier
```

Where `hit_type_modifier` is:
- Hit: `1.0`
- Critical: `1.0` (crits do more damage, so more aggro via base_value)
- Miss: `0.25`
- Dodge: `0.25`
- Block: `0.75`

The exact formula will be refined when the stat system is implemented.

---

## 7. Networking

### 7.1 Design Principles

- Ability activation is sent via the existing input pipeline (piggybacked on movement input frames).
- Cast cancellations flow server → client only (server is authoritative on cancels).
- Combat events flow server → client only.
  - These are events like 'actor X missed target Y', 'actor X begins casting spell Y', etc. They're sent as data
  but get translated into human-readable combat log messages.
  - Resolving the combat stack for a given tick results in N combat events. These are all sent together in the same message.
- Clients predict cast starts and self-displacement. Everything else waits for server confirmation.
- Target selection is a separate message from ability use.

### 7.2 Protobuf Messages

The following messages are added to `packets.proto`:

```protobuf
// ─── Ability Input (client → server) ───

message AbilityInput {
  string ability_id = 1;       // Which ability to use
  uint32 target_entity_id = 2; // Target entity (0 if self or ground)
  float ground_x = 3;          // Ground target X (only for ground target type)
  float ground_y = 4;          // Ground target Y
  float ground_z = 5;          // Ground target Z
}

// ─── Target Selection (client → server) ───

message TargetSelect {
  uint32 target_entity_id = 1; // 0 = clear target
}

// ─── Ability Events (server → client) ───

message AbilityUseAccepted {
  string ability_id = 1;
  uint32 requested_tick = 2; // The input frame that requested this ability use.
  uint32 start_tick = 3;
}

message AbilityUseRejected {
  uint32 ability_id = 1;
  uint32 requested_tick = 2; // The input frame that originally requested this ability use.
  uint32 cancel_reason = 3;     // 0=moved, 1=interrupted, 2=stunned, 3=target_died, 4=rejected
}

// ─── Combat Events (server → client) ───

enum HitType {
  HIT = 0;
  MISS = 1;
  DODGE = 2;
  CRIT = 3;
  BLOCK = 4;
  CRIT_BLOCK = 5;
}

message CombatEffect {
  uint32 effect_index = 1;      // Index of the effect in the ability definition
  string effect_type = 2;       // "damage", "heal", "status_effect", "displacement", "dispel"
  bool success = 3;             // Whether the effect was successfully applied
  float value = 4;              // Damage/heal number (0 if not applicable)
  HitType hit_type = 5;
  string status_id = 6;         // For status_effect: which status was applied/removed
  uint32 stacks = 7;            // For status_effect: new stack count
}

message CombatEvent {
  uint32 source_entity_id = 1;
  uint32 target_entity_id = 2;
  string ability_id = 3;
  repeated CombatEffect effects = 4;
  uint32 tick = 5;
}

// ─── Status Effect Sync (server → client) ───

message StatusEffectState {
  string status_id = 1;
  uint32 source_entity_id = 2;
  uint32 stacks = 3;
  float remaining_duration = 4; // 0 = permanent
}

message EntityStatusEffects {
  uint32 entity_id = 1;
  repeated StatusEffectState active_effects = 2;
}

// ─── Cooldown Sync (server → client) ───

message CooldownState {
  string ability_id = 1;        // Or cooldown_group key
  float remaining = 2;          // Seconds remaining
}

// ─── Aggregate Combat Tick (server → client, per tick) ───

message CombatSnapshot {
  uint32 tick = 1;
  repeated CombatEvent events = 2;
  repeated EntityStatusEffects entity_statuses = 3;
}
```

### 7.3 Modified Existing Messages

```protobuf
// PlayerInput gains an optional ability field
message PlayerInput {
  float input_x = 1;
  float input_z = 2;
  bool jump_pressed = 3;
  uint32 tick = 4;
  float rot_y = 5;
  AbilityInput ability_input = 6;  // NEW: set when player activates/queues an ability
}

// Packet gains new payload options
message Packet {
  oneof payload {
    PlayerInput player_input = 1;
    WorldDiff world_diff = 2;
    ClockPing clock_ping = 3;
    ClockPong clock_pong = 4;
    InputBatch input_batch = 5;
    TargetSelect target_select = 6;      // NEW
    CastStarted cast_started = 7;        // NEW
    CastCanceled cast_canceled = 8;      // NEW
    CombatSnapshot combat_snapshot = 9;  // NEW
  }
}
```

### 7.4 Message Flow

#### Ability Activation

```
Client                              Server
  |                                    |
  |── PlayerInput{ability_input} ────→ |  (unreliable, with movement input)
  |   [predict cast start locally]     |
  |                                    |── validate (range, resources, cooldowns, lockouts)
  |                                    |── if invalid: send CastCanceled
  |← ─── CastCanceled ───────────────|  (reliable)
  |   [cancel prediction, refund]      |
  |                                    |── if valid: begin cast on server
  |← ─── CastStarted ────────────────|  (reliable, broadcast to zone)
  |   [other clients see cast bar]     |
  |                                    |
  |   ... cast time elapses ...        |
  |                                    |
  |                                    |── cast completes → combat stack
  |                                    |── resolve effects
  |← ─── CombatSnapshot ─────────────|  (reliable, broadcast to zone)
  |   [display damage numbers,         |
  |    floating text, apply visual     |
  |    status effects]                 |
```

#### Ability Queue

```
Client                              Server
  |                                    |
  |── PlayerInput{ability_input=A} ──→ |  (starts casting A)
  |   ... in queue window ...          |
  |── PlayerInput{ability_input=B} ──→ |  (B is queued)
  |                                    |── A finishes casting
  |                                    |── validate B, begin casting B
  |← ─── CastStarted{B} ────────────|
```

The server distinguishes between "start casting" and "queue" based on whether an ability is already being cast. The client sends the same `AbilityInput` message in both cases.

#### Target Selection

```
Client                              Server
  |                                    |
  |── TargetSelect{entity_id} ───────→|  (reliable)
  |                                    |── store target for display to other clients
```

### 7.5 Channel Usage

| Channel | Transfer Mode | Messages |
|---|---|---|
| 0 | Unreliable Ordered | `PlayerInput` / `InputBatch`, `WorldDiff` (existing) |
| 1 | Reliable | `TargetSelect`, `CastStarted`, `CastCanceled`, `CombatSnapshot` |
| 0 | Reliable | `ClockPing`, `ClockPong` (existing) |

Combat messages use channel 1 (reliable) to ensure no dropped events. Movement remains on channel 0 (unreliable ordered) as before.

### 7.6 Client-Side Prediction Rules

| What | Predicted? | Notes |
|---|---|---|
| Cast start | Yes | Begin cast bar, animation immediately. Rolled back if server rejects. |
| Cast cancel (player moves) | Yes | Cancel immediately, don't wait for server. |
| GCD start/cancel | Yes | Mirrors cast prediction. |
| Resource subtraction | Yes | Subtract on cast start, refund on cancel. |
| Cooldown start | Yes | Start cooldown timer on cast start. |
| Self-displacement (dash) | Yes | Apply impulse immediately for responsiveness. Rubberband if server disagrees. |
| Target displacement | No | Wait for server (knockback on enemy). Rubberband if predicted incorrectly. |
| Damage/heal numbers | No | Wait for CombatSnapshot. Use animations to mask delay. |
| Buff/debuff application | No | Wait for CombatSnapshot. |
| Hit type (hit/miss/crit) | No | Server decides. |

---

## 8. Server-Side Architecture

### 8.1 Combat Manager

A new `CombatManager` component is added to `Zone.gd` (or as a sibling node). It is responsible for:

- Processing ability inputs from the input buffer each tick.
- Managing the combat stack per tick.
- Resolving effects in priority order.
- Tracking cooldowns, status effects, and aggro per entity.
- Emitting `CombatSnapshot` messages to all clients each tick (only ticks with events).

### 8.2 Per-Tick Processing

Within each server tick (`_tick()`):

```
1. Process input buffer (movement + ability inputs) for sim_tick
2. For each entity with a pending cast:
   a. Advance cast timer
   b. Check for cast-canceling conditions (movement, stun, target death)
   c. If cast completes → add to combat stack
3. Tick all active status effects:
   a. Decrement durations
   b. Fire tick effects (DoTs/HoTs) → add to combat stack
   c. Remove expired effects
4. Tick persistent ground AOEs:
   a. Check entities within area
   b. Apply effects → add to combat stack
5. Resolve combat stack in priority order:
   a. Heals
   b. Damage
   c. Buffs
   d. Debuffs
   e. Displacement
6. Generate CombatEvents from resolution
7. Update aggro lists
8. Handle death (HP ≤ 0 after resolution)
9. Process queued abilities (dequeue → begin casting if valid)
10. Broadcast CombatSnapshot if any events occurred
11. Broadcast WorldDiff (with updated positions from displacement)
```

### 8.3 Entity Combat State

Each entity (player or NPC) tracks:

```
- hp: float
- max_hp: float
- mana: float
- max_mana: float
- stamina: float
- max_stamina: float
- active_cast: { ability_id, target_entity_id, ground_pos, remaining_time, total_time }
- queued_ability: { ability_id, target_entity_id, ground_pos }
- cooldowns: { ability_id_or_group → remaining_time }
- gcd_remaining: float
- animation_lock_remaining: float
- active_status_effects: [ StatusEffectInstance, ... ]
- target_entity_id: uint32
- aggro_list: { entity_id → aggro_value }  (NPCs only)
```

### 8.4 Validation Checks

When the server receives an `AbilityInput`, it validates:

1. **Ability exists** in the ability database.
2. **Animation lock** is not active (0.7s internal cooldown).
3. **GCD check:** if the ability is a GCD ability, the GCD must not be active (unless queuing).
4. **Cooldown check:** the ability (and its cooldown group) must not be on cooldown.
5. **Resource check:** entity has sufficient mana/stamina.
6. **Target validation:**
   - `self` → no target needed.
   - `other_enemy` → target must exist, be alive, be hostile, and be within range.
   - `other_friend` → target must exist, be alive, be friendly, and be within range.
   - `other_any` → target must exist, be alive, and be within range.
   - `ground` → target point must be within range and have line-of-sight from caster.
7. **Tag lockout check:** entity must not have an active status effect that locks any of the ability's tags.
8. **Cast state:** if already casting, check if within queue window (last 50% of cast). If so, queue. If not, reject.

If any check fails, the server sends `CastCanceled` with the appropriate reason.

### 8.5 Range Checking

- Range is checked at cast **start** and at cast **completion** (for non-instant abilities).
- For `ground` target type: distance from caster origin to ground point.
- For entity target types: distance from caster to target entity.
- Line-of-sight check (raycast) is performed for ground-targeted abilities at cast start.

---

## 9. NPC Ability System

NPCs use the same ability system as players:

- NPCs have ability loadouts (a list of ability IDs they can use).
- NPC AI decides when to use abilities based on aggro, cooldowns, and target state.
- NPC ability usage goes through the same validation, casting, and combat stack pipeline.
- NPCs are subject to the same GCD, cooldowns, cast interruption, and status effect rules.

---

## 10. Persistent Ground AOEs

- When a persistent ground AOE ability resolves, the server creates a **ground effect entity**.
- This entity has a position, radius, duration timer, and tick timer.
- Every `tick_interval` seconds, the ground effect checks for entities within its area and applies its effects through the combat stack.
- Ground effects are broadcast to clients so they can render visual indicators.
- The ground effect is removed when its duration expires.

---

## 11. Key Constants

| Constant | Value | Description |
|---|---|---|
| `TICK_RATE` | `20` | Network/simulation ticks per second (existing). |
| `TICK_INTERVAL` | `0.05` | Seconds per tick (existing). |
| `INPUT_BUFFER_SIZE` | `5` | Input buffering window in ticks (existing). |
| `GCD_DURATION` | `2.5` | Global cooldown in seconds. |
| `ANIMATION_LOCK_DURATION` | `0.7` | Internal cooldown between any ability use, in seconds. |
| `ABILITY_QUEUE_WINDOW` | `0.5` | Queue opens at 50% remaining cast/GCD. |
| `STATUS_EFFECT_DEFAULT_TICK` | `3.0` | Default tick interval for DoTs/HoTs in seconds. |

---

## 12. File Structure (Proposed)

```
src/
├── common/
│   ├── combat/
│   │   ├── AbilityDatabase.gd        # Loads and indexes ability JSON definitions
│   │   ├── AbilityDef.gd             # Data class for a parsed ability definition
│   │   ├── EffectDef.gd              # Data class for a parsed effect definition
│   │   ├── StatusEffectInstance.gd    # Runtime state of an active status effect
│   │   ├── CombatConstants.gd        # GCD_DURATION, ANIMATION_LOCK, etc.
│   │   └── CombatUtils.gd            # Shared helpers (range checks, tag checks)
│   ├── proto/
│   │   └── packets.proto             # Updated with combat messages
│   └── data/
│       └── abilities/                 # JSON ability definitions
│           ├── fireball.json
│           ├── shield_bash.json
│           └── ...
├── game-server/
│   ├── combat/
│   │   ├── CombatManager.gd          # Per-tick combat processing, combat stack
│   │   ├── EntityCombatState.gd      # Per-entity combat runtime state
│   │   ├── AggroList.gd              # NPC aggro tracking
│   │   ├── CooldownTracker.gd        # Cooldown management
│   │   └── StatusEffectTracker.gd    # Status effect lifecycle
│   └── Zone.gd                       # Modified to integrate CombatManager
└── client/
    ├── combat/
    │   ├── AbilityController.gd       # Input → ability activation, queue, ground targeting
    │   ├── CastBarController.gd       # Cast bar UI state
    │   ├── CooldownDisplay.gd         # Cooldown UI state
    │   ├── CombatEventHandler.gd      # Processes CombatSnapshot, triggers VFX/text
    │   ├── StatusEffectDisplay.gd     # Buff/debuff icons
    │   └── GroundTargetController.gd  # Ground target mode (mouse → ground point)
    └── Player/
        └── Player.gd                  # Modified for combat prediction
```

---

## 13. Out of Scope (Future Work)

The following are explicitly deferred:

- Stat system and formulas (damage scaling, crit chance, haste, armor, etc.)
- Death, respawn, and resurrection mechanics.
- Block mechanics (active vs passive, mitigation amount).
- Hit/miss/dodge formula details.
- Aggro leashing and NPC reset behavior.
- Conditional ability effects ("execute" style abilities).
- Equipment and inventory.
- Classes, roles, and skill trees.
- PvP combat.
- Ability tooltips and UI polish.
- Animation and VFX integration.
- Spatial culling of combat events.
- DR decay timing (exact values).
