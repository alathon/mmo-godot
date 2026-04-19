Current State**
The client is not running the shared combat state machine. In `src/client/Player/Player.gd:47-89`, the local tick path reads input, immediately calls `AbilityPresentation.predict_ability_started(...)`, and always queues the input to the server if `ability_id > 0`. It never calls the shared `AbilityManager`.

The server does the opposite. In `src/game-server/systems/AbilitySystem.gd:22-29` and `:33-50`, every ability input goes through `AbilityManager.use_ability(...)`, and every tick goes through `AbilityManager.tick(...)`. That shared manager already does the real gating and progression:
- legality checks: GCD, anim lock, already casting, cooldown, resources, target validity in `src/common/entities/abilities/AbilityManager.gd:106-127`
- timer progression: GCD, anim lock, cooldown ticking, cast lock, cast completion, dequeue in `:18-35`
- state application: start cast/GCD/internal cooldown in `:229-280`, spend resources/final cooldown on complete in `:283-326`

So right now the local client prediction is cosmetic, not simulation-backed. `src/client/AbilityPresentation.gd:24-44` just stores a few predicted fields and logs. It does not own GCD, cooldowns, queued ability state, resources, or cast cancellation.

There are also two structural blockers to “just reuse the shared code on client”:
- Shared targeting/combat helpers still hardcode server entities. `src/game-server/systems/AbilityTargeting.gd:67-79, 148-160` and `src/common/combat/CombatTargeting.gd:56-59` assume `ServerPlayer` or server-owned zone lookups. `src/common/entities/CombatManager.gd:433-436` also hardcodes `ServerPlayer`.
- Client resource state is incomplete for legality checks. `src/common/entities/Stats.gd:28-36` updates HP, mana, and stamina from world state, but not `energy` / `max_energy`.

**What Needs To Change**
The core change is: the local client needs to run the same shared `AbilityManager` loop as the server, not a separate presentation-only shortcut.

1. In the local player tick, call the shared manager first.
- Build a local `AbilityExecutionContext`.
- Mirror server order as closely as possible: movement-cancel check, local `use_ability`, then `tick`.
- Only send the input to the server if local `use_ability(...)` accepted it.

2. Drive prediction from `AbilityManager`, not from raw input.
- Replace `predict_ability_started(...)` as the source of truth.
- For a local button press, call `_ability_manager.use_ability(...)`.
- If rejected locally, do not send the packet.
- If accepted locally, then assign/request_id and send it.
- Presentation should read the resulting local cast/queue state and local events, instead of inventing a predicted cast start immediately.

3. Support local queueing, not just local start.
- The shared manager allows queueing during cast/GCD windows in `AbilityManager.gd:83-85` and `:389-407`.
- That means a legal local input may be accepted but not actually start casting yet.
- The current `AbilityPresentation` cannot represent that; it only has one “active predicted ability” and starts it immediately. That will be wrong once the client mirrors server queue rules.

4. Make the “shared” target validation actually portable.
- Refactor the shared targeting/combat helpers so they do not depend on `ServerPlayer`.
- The common code should resolve these via generic methods/components available on both server and client entities:
  - entity lookup by id
  - current target id
  - world position
  - facing direction/angle
  - combat manager access
- Without that, client-side `can_use_ability(...)` cannot safely reuse the same target legality path as the server.

5. Fix authoritative resource sync for prediction.
- `Stats.apply_world_state(...)` needs to populate `energy` and `max_energy`.
- Otherwise local resource legality will be wrong for any energy-based abilities even after the rest is fixed.

**Practical Shape Of The Fix**
The minimal sane architecture is:
- keep `AbilityManager`, `AbilityState`, `AbilityCooldowns`, `CombatManager`, `Stats` in `src/common`
- add a thin client-side “ability system adapter” that supplies `get_entity`, `resolve_targets`, and `is_in_range`
- refactor common targeting/combat helpers to work against generic entity interfaces instead of `ServerPlayer`
- update `Player.gd` so local ability input goes through `_ability_manager.use_ability(...)` before packet enqueue
- reduce `AbilityPresentation.gd` to presentation/reconciliation, fed by local-manager state plus authoritative ack/cancel/complete

One important boundary: the client does not need to run full damage/heal/status application. It only needs the same preflight, cast, queue, GCD, cooldown, resource, and cancel progression as the server. It also doesn't need lock/resolve specifics; the most important thing is 1) the initial check(s) that even trying the cast is valid, and 2) advancing GCD/cooldowns/internal CD appropriately, so we can properly do 1 and drive UI to show this information.
