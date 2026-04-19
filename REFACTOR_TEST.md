Goal**

Keep field names as `ability_id` / `status_id`, but change them from string identifiers to numeric IDs on the wire and in gameplay state where appropriate. Add `ability_name: String` to ability data for display/debug only.

**Scope**

This plan covers:

1. slimming the combat packets you already approved
2. changing ability/status IDs from `string` to `uint32`
3. introducing `ability_name` in the ability database/resources
4. keeping a string lookup key only where needed during migration

## Target schema changes

### 1. `packets.proto`
In [packets.proto](/C:/Workspace/experiments/mmo-godot/src/common/proto/packets.proto):

- Change all combat-facing `ability_id` fields from `string` to `uint32`
- Change all combat-facing `status_id` fields from `string` to `uint32`
- Remove:
  - `AbilityUseRejected.ability_id`
  - `AbilityUseRejected.requested_tick`
  - `AbilityUseResolved.requested_tick`
  - `AbilityUseResolved.source_entity_id`
  - `ResolvedAbilityEffect.source_entity_id`
  - `ResolvedAbilityEffect.ability_id`

### Desired message shapes

```proto
message AbilityInput {
  uint32 ability_id = 1;
  uint32 target_entity_id = 2;
  float ground_x = 3;
  float ground_y = 4;
  float ground_z = 5;
  uint32 request_id = 6;
}

message AbilityUseAccepted {
  uint32 ability_id = 1;
  uint32 start_tick = 2;
  uint32 request_id = 3;
  uint32 resolve_tick = 4;
  uint32 finish_tick = 5;
  uint32 impact_tick = 6;
}

message AbilityUseRejected {
  uint32 cancel_reason = 1;
  uint32 request_id = 2;
}

message ResolvedAbilityEffect {
  ResolvedAbilityEffectKind kind = 1;
  ResolvedAbilityEffectPhase phase = 2;
  uint32 target_entity_id = 3;
  HitType hit_type = 4;
  uint32 amount = 5;
  uint32 status_id = 6;
  float duration = 7;
  bool is_debuff = 8;
}

message AbilityUseResolved {
  uint32 ability_id = 1;
  uint32 start_tick = 2;
  uint32 request_id = 3;
  uint32 resolve_tick = 4;
  uint32 finish_tick = 5;
  uint32 impact_tick = 6;
  repeated ResolvedAbilityEffect effects = 7;
}

message EntityEvent_AbilityUseStarted {
  uint32 source_entity_id = 1;
  uint32 ability_id = 2;
  uint32 target_entity_id = 3;
  float ground_x = 4;
  float ground_y = 5;
  float ground_z = 6;
  float cast_time = 7;
}

message EntityEvent_AbilityUseCanceled {
  uint32 source_entity_id = 1;
  uint32 ability_id = 2;
  uint32 cancel_reason = 3;
}

message EntityEvent_AbilityUseCompleted {
  uint32 source_entity_id = 1;
  uint32 ability_id = 2;
  HitType hit_type = 3;
}

message EntityEvent_DamageTaken {
  uint32 source_entity_id = 1;
  uint32 target_entity_id = 2;
  uint32 ability_id = 3;
  float amount = 4;
}

message EntityEvent_HealingReceived {
  uint32 source_entity_id = 1;
  uint32 target_entity_id = 2;
  uint32 ability_id = 3;
  float amount = 4;
}

message EntityEvent_BuffApplied {
  uint32 source_entity_id = 1;
  uint32 target_entity_id = 2;
  uint32 ability_id = 3;
  uint32 status_id = 4;
  uint32 stacks = 5;
  float remaining_duration = 6;
}

message EntityEvent_DebuffApplied {
  uint32 source_entity_id = 1;
  uint32 target_entity_id = 2;
  uint32 ability_id = 3;
  uint32 status_id = 4;
  uint32 stacks = 5;
  float remaining_duration = 6;
}

message EntityEvent_StatusEffectRemoved {
  uint32 entity_id = 1;
  uint32 status_id = 2;
  uint32 remove_reason = 3;
}
```

## Data model changes

### 2. Ability resources and DB
In your ability definitions layer, add explicit numeric IDs and display names.

Likely files:
- [AbilityResource or AbilityDef](/C:/Workspace/experiments/mmo-godot/src/common/combat/AbilityDef.gd)
- [AbilityDatabase.gd](/C:/Workspace/experiments/mmo-godot/src/common/combat/AbilityDatabase.gd)
- ability JSON files under [/src/common/data/abilities](/C:/Workspace/experiments/mmo-godot/src/common/data/abilities)

Add fields:

- `ability_id: int`
- `ability_name: String`

Keep the existing string key temporarily as the DB lookup key. Call it `ability_key` in code if you need to disambiguate.

### Concrete JSON changes
For each ability JSON:
- add `"ability_id": <stable integer>`
- add `"ability_name": "<display string>"`

Example:

```json
{
  "ability_id": 1,
  "ability_name": "Fireball",
  "cast_time": 1.5,
  ...
}
```

Do the same for statuses if they are data-driven:
- `status_id: int`
- optional later `status_name: String`

## Runtime naming policy

Apply this consistently:

- `ability_id`: numeric stable ID
- `status_id`: numeric stable ID
- `ability_name`: display string from data
- `ability_key`: internal string lookup key, only where still needed
- `status_key`: same idea if needed

This is important because right now many places use `ability_id` as a string semantic key. That ambiguity needs to be removed deliberately.

## Server-side implementation changes

### 3. Input pipeline
Files:
- [InputSystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/InputSystem.gd)
- [AbilitySystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/AbilitySystem.gd)

Changes:
- read `AbilityInput.ability_id` as `int`, not `String`
- propagate numeric `ability_id` through buffered input dictionaries
- stop converting proto `ability_id` into `StringName`

Current pattern to replace:
- anything like `StringName(input.get("ability_id", ""))`

Target:
- `var ability_id := int(input.get("ability_id", 0))`

### 4. Ability lookup
Files:
- [AbilityDatabase.gd](/C:/Workspace/experiments/mmo-godot/src/common/combat/AbilityDatabase.gd)
- [AbilityManager.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/AbilityManager.gd)

Changes:
- add lookup by numeric `ability_id`
- if DB currently indexes by filename/string key, maintain a second map:
  - `_abilities_by_id: Dictionary[int, AbilityResource]`
  - optional `_abilities_by_key: Dictionary[StringName, AbilityResource]` during migration
- update all ability fetches in combat execution to use numeric `ability_id`

### 5. Ability state and request/result classes
Files:
- [AbilityUseRequest.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/AbilityUseRequest.gd)
- [AbilityUseResult.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/AbilityUseResult.gd)
- [ScheduledAbilityUse.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/ScheduledAbilityUse.gd)
- [ResolvedAbilityUseSnapshot.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/ResolvedAbilityUseSnapshot.gd)
- [ResolvedAbilityEffectSnapshot.gd](/C:/Workspace/experiments/mmo-godot/src/common/entities/abilities/ResolvedAbilityEffectSnapshot.gd)
- [EntityEvents.gd](/C:/Workspace/experiments/mmo-godot/src/common/EntityEvents.gd)

Changes:
- change `ability_id` fields from `StringName` to `int`
- change `status_effect_id` style fields to `status_id: int`
- rename `status_effect_id` to `status_id` where practical for consistency
- update constructors/factory methods accordingly

This is the core type migration. Do this before touching all call sites.

### 6. Packet writing
Files:
- [AbilitySystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/AbilitySystem.gd)
- [CombatSystem.gd](/C:/Workspace/experiments/mmo-godot/src/game-server/systems/CombatSystem.gd)
- [EntityEventCodec.gd](/C:/Workspace/experiments/mmo-godot/src/common/EntityEventCodec.gd)

Changes:
- write numeric `ability_id` / `status_id` directly
- remove writes for deleted fields:
  - `AbilityUseRejected.ability_id`
  - `AbilityUseRejected.requested_tick`
  - `AbilityUseResolved.requested_tick`
  - `AbilityUseResolved.source_entity_id`
  - `ResolvedAbilityEffect.source_entity_id`
  - `ResolvedAbilityEffect.ability_id`

## Client-side implementation changes

### 7. ACK/reject/resolved handling
Files:
- [AbilityPresentation.gd](/C:/Workspace/experiments/mmo-godot/src/client/AbilityPresentation.gd)
- [Player.gd](/C:/Workspace/experiments/mmo-godot/src/client/Player/Player.gd)
- [GameManager.gd](/C:/Workspace/experiments/mmo-godot/src/client/GameManager.gd)

Changes:
- store predicted `ability_id` as `int`, not `StringName`
- update local prediction matching to use numeric IDs
- remove references to deleted rejection/resolution fields:
  - rejection no longer has `ability_id` or `requested_tick`
  - resolved no longer has `requested_tick` or `source_entity_id`

Specific cleanup in `AbilityPresentation.gd`:
- `_predicted_ability_id: int = 0`
- `_matches_active_prediction` compares ints
- reject log should no longer print ability id from rejection packet
- resolved log should stop printing removed fields

### 8. World event consumers
Files:
- [GameManager.gd](/C:/Workspace/experiments/mmo-godot/src/client/GameManager.gd)
- [RemoteEntity.gd](/C:/Workspace/experiments/mmo-godot/src/client/RemoteEntity.gd)

Changes:
- update log and dispatch code to treat `ability_id` / `status_id` as numeric
- if any UI wants text, resolve through DB using `ability_name`

## DB/API layer changes

### 9. Add display lookup helpers
Files:
- [AbilityDatabase.gd](/C:/Workspace/experiments/mmo-godot/src/common/combat/AbilityDatabase.gd)

Add helpers:
- `get_ability_by_id(ability_id: int) -> AbilityResource`
- `get_ability_name(ability_id: int) -> String`
- optional temporary `get_ability_by_key(key: StringName) -> AbilityResource`

This lets logs/UI remain readable after the numeric migration.

### 10. Ability resource shape
In ability resource class:
- add `@export var ability_id: int = 0`
- add `@export var ability_name: String = ""`

Validation in DB load:
- fail if `ability_id <= 0`
- fail on duplicate `ability_id`
- fail if `ability_name` is empty

## Migration strategy

### Phase 1: Data and DB first
1. Add `ability_id` and `ability_name` to ability data/resources
2. Update `AbilityDatabase` to load and validate them
3. Keep old string-key lookup working temporarily

### Phase 2: Internal combat types
1. Convert internal model classes to numeric `ability_id` / `status_id`
2. Update DB lookups and combat logic to use numeric IDs
3. Keep temporary bridges where string keys still exist

### Phase 3: Protocol
1. Update `packets.proto`
2. regenerate [packets.gd](/C:/Workspace/experiments/mmo-godot/src/common/proto/packets.gd)
3. update all packet read/write sites

### Phase 4: Client presentation
1. convert prediction/presentation code to numeric IDs
2. swap human-readable logging to resolve `ability_name` through DB where needed

### Phase 5: Cleanup
1. remove leftover string `ability_id` assumptions
2. rename temporary `status_effect_id` fields to `status_id`
3. remove obsolete key-based plumbing where no longer needed

## Exact refactor tasks

1. Update ability JSON files with `ability_id` and `ability_name`
2. Update ability resource class to expose those fields
3. Update `AbilityDatabase` to index by numeric `ability_id`
4. Convert internal combat model classes from string IDs to ints
5. Convert status references from string IDs to ints in snapshots/events
6. Update `packets.proto` field types and remove approved fields
7. Regenerate `packets.gd`
8. Update server packet decoding in `InputSystem.gd`
9. Update server ACK writing in `AbilitySystem.gd`
10. Update resolved payload writing in `CombatSystem.gd`
11. Update event encoding in `EntityEventCodec.gd`
12. Update client packet consumers in `GameManager.gd`
13. Update prediction/presentation in `AbilityPresentation.gd`
14. Replace readable string logging with DB name lookup where useful
15. Run protocol and gameplay validation

## Validation checklist

- local cast still predicts and reconciles correctly
- reject path still clears the right predicted cast
- resolved path still schedules local outcome presentation
- world events still dispatch correctly for local and remote entities
- all combat abilities load with unique numeric `ability_id`
- no packet writer/reader still assumes `string ability_id`
- logs show readable names via `ability_name`, not raw numeric IDs where readability matters

## Recommended implementation order

1. Ability data/resource/DB
2. Internal model types
3. Protocol schema
4. Packet readers/writers
5. Client presentation/logging
6. Cleanup
