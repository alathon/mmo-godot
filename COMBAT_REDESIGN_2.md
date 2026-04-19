# Combat Redesign 2

## Implementation Checklist

- [x] Add `request_id` through client input, proto, server input buffering, ACKs, and presentation matching.
- [x] Change `AbilityManager` cast timing from float remaining time to tick deadlines.
- [x] Add `finish_tick` and `impact_tick` to ACK, but keep effects applying as today.
- [x] Replace `CompletedAbilityUse` with scheduled impact application at `impact_tick`.
- [x] Add `ScheduledAbilityUse` with `resolve_tick`, add `ResolvedAbilityUse` / `ResolvedAbilityEffect` snapshots, and send `AbilityUseResolved` when effects are known.
- [ ] Add `ApplicationPhase.EARLY` and `cast_locked` behavior.
- [ ] Split `cooldown` into instant internal cooldown semantics vs cast-time behavior.

Here is how I’d reshape the current system to match that model.

The current pipeline is close in broad phases, but too coarse:

- Client predicts only by `ability_id + requested_tick`, no stable request ID.
- Server ACK only returns `accepted/rejected + start_tick`.
- `AbilityManager` starts and completes instant casts in the same tick.
- `ScheduledAbilityUse` carries start/resolve/finish/impact ticks so resolution can happen before finish.
- Effects are snapshotted at `resolve_tick`, then applied unchanged at `impact_tick`.
- Movement cancel is binary: if `manager.is_casting()`, movement cancels. There is no locked-cast phase.

Relevant current spots:

- [AbilityManager.gd](src/common/entities/abilities/AbilityManager.gd) owns GCD, animation lock, cast state, queueing, cooldowns, and emits scheduled impact/use objects.
- [ScheduledAbilityUse.gd](src/common/entities/abilities/ScheduledAbilityUse.gd) carries source, ability, target, requested/start/resolve/finish/impact ticks.
- [ResolvedAbilityUseSnapshot.gd](src/common/entities/abilities/ResolvedAbilityUseSnapshot.gd) and [ResolvedAbilityEffectSnapshot.gd](src/common/entities/abilities/ResolvedAbilityEffectSnapshot.gd) hold server-side snapshots; the packet messages keep the external `AbilityUseResolved` / `ResolvedAbilityEffect` names.
- [AbilitySystem.gd](src/game-server/systems/AbilitySystem.gd) consumes client input, calls `manager.use_ability`, sends ACKs, and passes scheduled ability objects toward combat resolution.
- [CombatSystem.gd](src/game-server/systems/CombatSystem.gd) owns the delayed impact queue and should own scheduled-use resolution/application.
- [packets.proto](src/common/proto/packets.proto) has ability input, ACK/reject messages, `resolve_tick`, `AbilityUseResolved`, and resolved-result payloads.

## Core Model

I’d split ability use into four server-side phases:

1. `STARTED`
   The request was accepted. GCD/resources/cooldown rules are locked in. Server emits `ability_started`.

2. `LOCKED`
   The cast can no longer be canceled by movement. Early effects are applied here.

3. `FINISHED`
   The cast bar is done. Entity is no longer casting. Server emits `ability_completed`, but does not apply normal damage/healing yet.

4. `RESOLVED`
   The server materializes targets from the original target anchor and snapshots the effects that will later land. This can happen at start for instant casts, or shortly before finish for long casts/AOE/smart-target abilities.

5. `IMPACT/APPLIED`
   Normal effects land after the impact delay, default 600 ms.

For instant casts, `STARTED`, `RESOLVED`, and `FINISHED` happen at the same server tick, but `IMPACT/APPLIED` still happens at `start_tick + impact_delay_ticks`.

That means the common shape becomes:

```text
request accepted
start local/server cast state
optional lock tick
resolve tick
snapshot targets/effects
finish tick
impact tick
apply resolved effects
```

Instant casts just have `resolve_tick == finish_tick == start_tick`.

## Protocol Changes

`AbilityInput` needs a request ID:

```proto
message AbilityInput {
  string ability_id = 1;
  uint32 target_entity_id = 2;
  float ground_x = 3;
  float ground_y = 4;
  float ground_z = 5;
  uint32 request_id = 6;
}
```

`AbilityUseAccepted` should become the authoritative schedule for the client:

```proto
message AbilityUseAccepted {
  string ability_id = 1;
  uint32 requested_tick = 2;
  uint32 start_tick = 3;
  uint32 request_id = 4;
  uint32 resolve_tick = 5;
  uint32 finish_tick = 6;
  uint32 impact_tick = 7;
}
```

`AbilityUseRejected` should also carry `request_id`:

```proto
message AbilityUseRejected {
  string ability_id = 1;
  uint32 requested_tick = 2;
  uint32 cancel_reason = 3;
  uint32 request_id = 4;
}
```

Resolved results should not be part of `AbilityUseAccepted`. Many abilities cannot honestly know their final target set at cast start. Instead, the caster receives a separate `AbilityUseResolved` packet at `resolve_tick`:

```proto
message AbilityUseResolved {
  string ability_id = 1;
  uint32 requested_tick = 2;
  uint32 start_tick = 3;
  uint32 request_id = 4;
  uint32 resolve_tick = 5;
  uint32 finish_tick = 6;
  uint32 impact_tick = 7;
  uint32 source_entity_id = 8;
  repeated ResolvedAbilityEffect effects = 9;
}
```

`ResolvedAbilityEffect` should describe the local-only future result that the caster can schedule for combat log/floating text:

```proto
message ResolvedAbilityEffect {
  ResolvedAbilityEffectKind kind = 1;
  ResolvedAbilityEffectPhase phase = 2;
  uint32 source_entity_id = 3;
  uint32 target_entity_id = 4;
  string ability_id = 5;
  HitType hit_type = 6;
  uint32 amount = 7;
  string status_id = 8;
  float duration = 9;
  bool is_debuff = 10;
}
```

Then client presentation can convert resolved effects into local-only combat log/floating text events at the correct visual time, while the server still sends authoritative world-state events later.

For instant casts, `AbilityUseAccepted` and `AbilityUseResolved` may be sent in the same server tick, but they should remain distinct lifecycle packets:

```text
AbilityUseAccepted: schedule and casting state
AbilityUseResolved: known future result
WorldState events: authoritative state mutation after impact
```

I’d also add `request_id` to ability-related entity events:

```proto
message EntityEvent_AbilityUseStarted {
  uint32 source_entity_id = 1;
  string ability_id = 2;
  uint32 target_entity_id = 3;
  float ground_x = 4;
  float ground_y = 5;
  float ground_z = 6;
  float cast_time = 7;
  uint32 request_id = 8;
}
```

Same for canceled/completed/damage/healing/buff/debuff if you want exact correlation. At minimum, add it to started/canceled/completed.

## Client API Changes

In [Player.gd](src/client/Player/Player.gd), local ability use currently predicts by `ability_id` and `current_tick`. Instead, add a monotonically increasing client request ID:

```gdscript
var _next_ability_request_id: int = 1
```

When an ability is triggered:

```gdscript
var request_id := _next_ability_request_id
_next_ability_request_id += 1

_ability_presentation.predict_ability_started(
        request_id,
        ability_id,
        target_entity_id,
        current_tick)
```

Then pass `request_id` through [InputBatcher.gd](src/client/Network/InputBatcher.gd), into `AbilityInput`.

`AbilityPresentation` should track active predictions by request ID, not just one `_predicted_ability_id`:

```gdscript
var _predicted_uses: Dictionary[int, AbilityPresentationUse] = {}
```

A small client-side presentation object would carry:

```gdscript
class_name AbilityPresentationUse
extends RefCounted

var request_id: int
var ability_id: StringName
var requested_tick: int
var start_tick: int
var lock_tick: int
var finish_tick: int
var resolve_tick: int
var impact_tick: int
var accepted: bool = false
var resolved_effects: Array = []
```

New presentation methods:

```gdscript
func predict_ability_started(request_id: int, ability_id: StringName, target_entity_id: int, requested_tick: int) -> void
func confirm_ability_use(ack: Proto.AbilityUseAccepted) -> void
func on_ability_resolved(resolved: Proto.AbilityUseResolved) -> void
func reject_ability_use(rejection: Proto.AbilityUseRejected) -> void
func tick(current_tick: int) -> void
func _finish_predicted_use(use: AbilityPresentationUse) -> void
func _apply_predicted_impact(use: AbilityPresentationUse) -> void
```

The client should start animation/GCD immediately on prediction, but correct the schedule when ACK arrives.

## Server AbilityManager Changes

`AbilityUseRequest` should carry `request_id`:

```gdscript
var request_id: int = 0
```

`AbilityState` needs explicit phase/deadline fields:

```gdscript
enum CastPhase {
	NONE,
	CASTING,
	LOCKED,
	FINISHED,
}

var cast_request_id: int = 0
var cast_lock_tick: int = 0
var cast_resolve_tick: int = 0
var cast_finish_tick: int = 0
var cast_impact_tick: int = 0
var cast_locked: bool = false
```

I would stop driving cast completion from `cast_remaining -= delta` and use tick deadlines instead. The rest of the simulation is tick-based, and your desired ACK needs exact authoritative ticks.

Replace this pattern:

```gdscript
state.cast_remaining = maxf(0.0, state.cast_remaining - delta)
if state.cast_remaining <= 0.0:
	events.append_array(_complete_cast(sim_tick, context))
```

With:

```gdscript
if state.is_casting():
	if not state.cast_locked and state.cast_lock_tick > 0 and sim_tick >= state.cast_lock_tick:
		events.append_array(_lock_cast(sim_tick, context))

	if sim_tick >= state.cast_finish_tick:
		events.append_array(_finish_cast(sim_tick, context))
```

`use_ability` should produce an accepted result with schedule:

```gdscript
func use_ability(request: AbilityUseRequest, context: AbilityExecutionContext) -> AbilityUseResult
```

Instead of passing loose `ability_id`, `target`, `requested_tick`, use a real request object everywhere.

On acceptance, server computes:

```gdscript
var start_tick := context.sim_tick
var cast_ticks := _seconds_to_ticks(ability.cast_time)
var finish_tick := start_tick + cast_ticks
var resolve_tick := _compute_resolve_tick(ability, start_tick, finish_tick)
var impact_tick := finish_tick + _seconds_to_ticks(ability.impact_delay)
var lock_tick := _compute_lock_tick(ability, start_tick, finish_tick)
```

For instant cast:

```gdscript
finish_tick = start_tick
resolve_tick = start_tick
lock_tick = 0
impact_tick = start_tick + _seconds_to_ticks(ability.impact_delay)
```

`resolve_tick` should be computed from a tick-based lead value:

```gdscript
@export var resolve_lead_ticks: int = 8

func _compute_resolve_tick(ability: AbilityResource, start_tick: int, finish_tick: int) -> int:
	return maxi(start_tick, finish_tick - ability.resolve_lead_ticks)
```

At 20 ticks/sec, the default `resolve_lead_ticks = 8` means targets/effects are snapshotted 400 ms before cast finish. Instant casts naturally resolve at start because `start_tick == finish_tick`.

## Cooldown/GCD Semantics

Right now `_start_cast()` does all of this immediately:

```gdscript
_apply_gcd(ability)
state.anim_lock_remaining = AbilityConstants.ANIMATION_LOCK_DURATION
_apply_cooldown(ability)
```

For the desired behavior, split these concepts:

```gdscript
func _apply_gcd(ability: AbilityResource) -> void
func _apply_animation_lock(ability: AbilityResource) -> void
func _apply_internal_cooldown_if_needed(ability: AbilityResource) -> void
```

Then:

```gdscript
func _apply_internal_cooldown_if_needed(ability: AbilityResource) -> void:
	if ability == null:
		return
	if ability.cast_time > 0.0:
		return
	cooldowns.start(ability.get_ability_id(), ability.internal_cooldown, StringName(ability.cooldown_group))
```

This probably means `AbilityResource.cooldown` should be renamed or complemented:

```gdscript
@export var internal_cooldown: float = 0.0
@export var impact_delay: float = 0.6
@export var cast_lock_time: float = -1.0
```

I’d avoid overloading the existing `cooldown` field because “cooldown” can mean recharge, internal cooldown, charge recharge, or shared lockout. The desired model specifically says cast-time spells should not start an internal cooldown.

## Effect Timing

Add an effect phase to [AbilityEffect.gd](src/common/ability_definitions/effects/AbilityEffect.gd):

```gdscript
enum ApplicationPhase {
	IMPACT,
	EARLY,
}

@export var application_phase: ApplicationPhase = ApplicationPhase.IMPACT
```

Then split effect application:

```gdscript
func apply_resolved_effects(
		source_entity: Node,
		resolved_effects: Array[ResolvedAbilityEffect],
		phase: int,
		context: AbilityExecutionContext) -> Array[EntityEvents]
```

Early effects are applied in `_lock_cast()`. Impact effects are applied in `CombatSystem` at `impact_tick`.

## Target And Effect Resolution

The big architectural change is that `CombatManager` should stop rolling/proc/evaluating values at final application time, but it should not necessarily do that at cast start.

There are three separate concepts:

```text
Cast snapshot:
  The server accepts the use and records the schedule/anchor.

Target materialization:
  The server turns the target anchor into affected entity IDs.

Effect snapshot:
  The server rolls/procs/resolves damage/healing/status values for those affected entity IDs.
```

The homogeneous rule should be:

```text
Every accepted ability creates a ScheduledAbilityUse at start.
Every ScheduledAbilityUse resolves targets/effects at resolve_tick.
Every resolved use applies effects at impact_tick.
```

This avoids unintuitive long-cast behavior where a 5 second ground AOE would hit players who left the area during the cast. Ground AOEs, smart-target abilities, and chain abilities all materialize their affected entities at `resolve_tick`, not `start_tick`.

For single-target abilities, the target anchor can still be fixed at start:

```text
start_tick:
  Store target entity ID as the target anchor.

resolve_tick:
  Check whether that entity still exists, is alive, and is still valid/in range according to the ability rules.
  If valid, create resolved effects for it.
  If invalid, create no effects or later add a fizzle/miss resolved result.
```

Currently [CombatManager.gd](src/common/entities/CombatManager.gd) does:

```gdscript
var amount := int(round(resolve_effect_value(effect.formula)))
if not _passes_proc(effect):
	return []
```

That should move into a resolver that runs at `resolve_tick`:

```gdscript
class_name ResolvedAbilityUse
extends RefCounted

var request_id: int
var source_entity_id: int
var ability_id: StringName
var target: AbilityTargetSpec
var start_tick: int
var lock_tick: int
var resolve_tick: int
var finish_tick: int
var impact_tick: int
var effects: Array[ResolvedAbilityEffect] = []
```

And:

```gdscript
class_name ResolvedAbilityEffect
extends RefCounted

enum Phase { EARLY, IMPACT }
enum Kind { DAMAGE, HEAL, STATUS }

var phase: Phase
var kind: Kind
var source_entity_id: int
var target_entity_id: int
var ability_id: StringName
var hit_type: int
var amount: int
var status_effect_id: StringName
var duration: float
var is_debuff: bool
```

Then server flow becomes:

```gdscript
var resolved_use := source_combat_manager.resolve_ability_use_snapshot(
		source_entity,
		ability,
		target,
		scheduled_use,
		context)
```

That resolved snapshot is:

- stored in `ScheduledAbilityUse`,
- serialized in `AbilityUseResolved`,
- used later by the server to apply real state mutation.

This gives the client “hit/miss, damage/healing/buff/proc values are known before impact but not applied yet,” without pretending those values always exist at ACK time.

## ScheduledAbilityUse Chain

The scheduled-use object now carries both resolution and impact timing:


```gdscript
class_name ScheduledAbilityUse
extends RefCounted

var request_id: int
var source_entity_id: int
var ability_id: StringName
var target: AbilityTargetSpec
var start_tick: int
var lock_tick: int
var resolve_tick: int
var finish_tick: int
var impact_tick: int

var resolved: bool = false
var resolved_use: ResolvedAbilityUseSnapshot = null
```

The scheduled use must be registered at cast start, not finish. Otherwise a long cast whose `resolve_tick` occurs before `finish_tick` cannot be resolved on time.

Recommended server chain:

```text
AbilityManager accepts ability
  -> creates ScheduledAbilityUse immediately
  -> AbilityUseAccepted ACK carries schedule only
  -> AbilitySystem registers ScheduledAbilityUse with CombatSystem

CombatSystem at resolve_tick
  -> asks CombatManager to materialize targets and snapshot effects
  -> stores ResolvedAbilityUse on ScheduledAbilityUse
  -> emits/sends AbilityUseResolved to caster

AbilityManager at finish_tick
  -> completes cast state
  -> emits ability_completed

CombatSystem at impact_tick
  -> applies the stored ResolvedAbilityUse
  -> emits authoritative damage/heal/status world events
```

Cancellation path:

```text
AbilityManager.cancel_casting()
  -> emits ability_canceled
  -> includes request_id
  -> AbilitySystem tells CombatSystem to cancel the ScheduledAbilityUse
```

This is the main reason ability-related entity events should gain `request_id`: cancellation needs to remove the matching scheduled use.

## Movement Cancel Change

Current movement cancel:

```gdscript
if manager != null and manager.is_casting():
	manager.cancel_casting(...)
```

Change to:

```gdscript
if manager != null and manager.can_movement_cancel_current_cast():
	manager.cancel_casting(...)
```

`AbilityManager`:

```gdscript
func can_movement_cancel_current_cast() -> bool:
	return state.is_casting() and not state.cast_locked
```

Instant casts are never movement-cancelable after server acceptance because `finish_tick == start_tick`.

## ACK Shape in GDScript

`AbilityUseResult` should expand from this:

```gdscript
var accepted: bool
var ability_id: StringName
var requested_tick: int
var start_tick: int
var reject_reason: int
var events: Array[EntityEvents]
```

To this:

```gdscript
var accepted: bool
var request_id: int
var ability_id: StringName
var requested_tick: int
var start_tick: int
var lock_tick: int
var finish_tick: int
var resolve_tick: int
var impact_tick: int
var reject_reason: int
var events: Array[EntityEvents]
```

The server ACK serializes only the accepted schedule. Resolved effects are sent later in `AbilityUseResolved`.

The next high-value step is to replace impact-only scheduling with full scheduled uses:

```text
Accepted schedule now:
  request_id, start_tick, finish_tick, impact_tick

Needed schedule:
  request_id, start_tick, resolve_tick, finish_tick, impact_tick

Needed result path:
  AbilityUseResolved at resolve_tick
  authoritative state mutation at impact_tick
```

This gives the client a reliable timeline for cast UI, finish animation, combat log, and floating combat text without locking long-cast AOE/smart-target results too early.
