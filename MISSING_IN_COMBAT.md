# Missing Combat Work

This is the remaining work to turn the current ability/combat scaffold into real gameplay combat.

## Ability Use

- [x] Implement ability queueing in `AbilityManager._try_dequeue_ability(...)`.
- [x] Decide final resource timing:
  - check on cast start,
  - spend on completion,
  - do not refund on cancel/interruption because nothing was spent yet.
- [x] Decide final cooldown timing:
  - start on cast start,
  - refund on cancel/interruption.
- [ ] Tighten `AbilityManager.can_use_ability(...)`:
  - cooldown/GCD queue edge cases,
  - animation lock,
  - stun/interrupt state,
  - target died handling.
- [ ] Implement instant abilities as a fully covered test case:
  - started and completed in the same tick,
  - same `CompletedAbilityUse` path as casted abilities.
- [ ] Add deterministic smoke tests for:
  - accepted cast,
  - rejected cast,
  - movement cancel,
  - insufficient resources,
  - cooldown rejection.

## Targeting

- [x] Replace temporary hostility logic in `CombatManager.is_hostile_to(...)`.
- [x] Replace temporary friendliness logic in `CombatManager.is_friendly_to(...)`.
- [x] Define initial hostility target rules:
  - entities are friendly by default,
  - `DetermineHostility.attacked_by(...)` marks a specific attacker as hostile,
  - `DetermineHostility` owns a temporary aggro list,
  - `DetermineHostility.clear_combat()` clears temporary hostility and aggro.
- [ ] Define real faction/team/group/reputation target rules.
- [ ] Implement combat target validation in `CombatTargeting` using those rules.
- [ ] Implement selected-target resolution through entity target state, not combat state.
- [ ] Implement ground-target materialization.
- [ ] Implement area target materialization:
  - circle,
  - cone,
  - future shapes if needed.
- [ ] Implement target selectors:
  - nearest targets,
  - lowest HP targets,
  - random targets,
  - chain targets.

## Combat Resolution

- [ ] Implement real hit resolution:
  - hit,
  - miss,
  - dodge,
  - crit,
  - block,
  - crit block.
- [ ] Decide whether combat RNG must be deterministic by tick/source/ability.
- [ ] Feed real source stats into `ValueFormula.evaluate(...)`.
- [ ] Implement damage formulas beyond flat base values.
- [ ] Implement healing formulas beyond flat base values.
- [ ] Apply ability modifiers:
  - damage multipliers,
  - healing multipliers,
  - added effects,
  - removed effects.
- [ ] Apply conditional effects through `ConditionalEffect`.
- [ ] Implement proc handling with deterministic/random policy.
- [ ] Implement damage/healing falloff for chained or area effects if needed.
- [ ] Implement combat death checks as a central combat-system responsibility.

## Status Effects

- [ ] Add persistent status storage on the appropriate entity/combat component.
- [ ] Implement status application.
- [ ] Implement status duration ticking.
- [ ] Implement status stack behavior.
- [ ] Implement periodic tick effects:
  - damage over time,
  - healing over time,
  - other future tick effects.
- [ ] Implement dispel behavior.
- [ ] Implement consume-stacks behavior.
- [ ] Implement status expiration events.
- [ ] Decide which status effects are buffs vs debuffs from data.

## Combat State

- [ ] Implement combat engagement rules.
- [ ] Implement combat end timing.
- [ ] Implement threat/aggro model.
- [ ] Track last combat event tick consistently.
- [ ] Decide how healing threat is distributed.
- [ ] Decide how deaths clear combat state.

## Events And Network

- [ ] Verify `AbilityUseAccepted` client handling.
- [ ] Verify `AbilityUseRejected` client handling.
- [ ] Verify `CombatTickEvents` client handling.
- [ ] Verify client handling for:
  - ability started,
  - ability canceled,
  - ability completed,
  - damage taken,
  - healing received,
  - buff applied,
  - debuff applied,
  - status removed,
  - combatant died.
- [ ] Decide whether generic ability lifecycle events should stay in `WorldState.combat_events` or move to a separate ability-events stream.
- [ ] Implement any missing proto fields before client behavior depends on them.
- [ ] Confirm event buffers clear only after successful serialization/broadcast.

## Validation

- [ ] Add a deterministic combat smoke test for `fireball.tres`.
- [ ] Add a smoke test for instant abilities.
- [ ] Add a smoke test for cast completion after elapsed ticks.
- [ ] Add a smoke test for death event generation.
- [ ] Add a smoke test for target rejection.
- [ ] Add a smoke test for resource consumption.
- [ ] Add a smoke test for cooldown rejection.
- [ ] Keep using project/headless validation because MCP script validation reports false positives for `class_name` temp scripts.

## Documentation

- [ ] Update `COMBAT_REDESIGN.md` after each completed combat subsystem pass.
- [ ] Document the final handoff:
  - `AbilityManager` snapshots `CompletedAbilityUse`,
  - `AbilitySystem` appends completed uses to tick context,
  - `CombatSystem` resolves the combat stack for the tick.
- [ ] Document final target ownership:
  - selected target state,
  - target materialization,
  - combat legality.
- [ ] Document final resource/cooldown/cancel semantics.
