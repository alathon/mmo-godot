# Abilities Lifecycle

This document describes the current client/server lifecycle for a single ability use,
with special focus on the local player prediction path.

## Core Rules

- `AbilityManager` is shared simulation code.
- `AbilityManager` does not know about `src/client` or `src/game-server` types.
- `AbilityEventController` is the single client-side emitter of normalized ability lifecycle signals.
- The local player predicts normal ability progression locally.
- For locally-owned requests, authoritative server `started` / `finished` / `impact` world events are ignored.
- For now, the local player does not adjust `finish` or `impact` timing from the server ACK.
- Cancels / rejects from the server are still applied.

## Messages

### Client -> Server

- `AbilityInput`
  - `ability_id`
  - target data (`target_entity_id` or ground position)
  - `request_id`

### Server -> Casting Player Only

- `AbilityUseAccepted`
  - `ability_id`
  - `request_id`
  - `start_tick`
  - `resolve_tick`
  - `finish_tick`
  - `impact_tick`

- `AbilityUseRejected`
  - `request_id`
  - `cancel_reason`

- `AbilityUseResolved`
  - `ability_id`
  - `request_id`
  - `start_tick`
  - `resolve_tick`
  - `finish_tick`
  - `impact_tick`
  - `effects[]`

### Server -> Everyone In Zone

World-state `EntityEvent`s:

- `ability_use_started`
- `ability_use_finished`
- `ability_use_impact`
- `ability_use_canceled`

These lifecycle events now carry `request_id`.

## Local Player Flow

### 1. Input gathered

- `LocalInput` captures the button press.
- `Player._on_network_tick(...)` gathers input for the current tick.

### 2. Local prediction starts

- `Player._process_ability_input(...)` calls:
  - `ability_manager.get_next_request_id()`
  - `ability_manager.use_ability(current_tick, request_id, ability_id, target_spec, ability_context)`

- If accepted:
  - `Player` stores `request_id -> ability_id`
  - `Player` calls `AbilityEventController.add_local_request(request_id, entity_id, ability_id, started_tick)`
  - `Player` feeds the immediate returned events into `AbilityEventController`

### 3. Local predicted lifecycle events

- `AbilityManager.use_ability(...)` may immediately return:
  - `EntityEvents.ability_started(...)`

- On later ticks, `Player` calls:
  - `ability_manager.tick(ability_context)`

- `AbilityManager.tick(...)` may later return:
  - `EntityEvents.ability_finished(...)`

- After local `finished`, `Player` schedules and later creates:
  - `EntityEvents.ability_impact(...)`

### 4. Single client-side emitter

All local predicted lifecycle events are fed into the local player's `AbilityEventController`.

`AbilityEventController` is the single emitter of:

- `ability_started(event, event_tick)`
- `ability_finished(event, event_tick)`
- `ability_impact(event, event_tick)`
- `ability_canceled(event, event_tick)`
- `ability_resolved(resolved)`

Anything that wants ability lifecycle notifications should subscribe to the entity's
`AbilityEventController`, not to `Player`/`RemoteEntity` directly.

### 5. Input sent to server

In the same client tick, `Player` queues the input through `InputBatcher`, including:

- movement input
- `ability_id`
- target data
- `request_id`

## Server Flow

### 1. Input received

- `AbilitySystem.handle_ability_input(...)` receives the `AbilityInput`.
- It calls the server entity's:
  - `ability_manager.use_ability(sim_tick, request_id, ability_id, target_spec, context)`

### 2. Direct response to casting player

- If accepted, server sends `AbilityUseAccepted`.
- If rejected, server sends `AbilityUseRejected`.

### 3. Authoritative world-state lifecycle events

The server also sends lifecycle events in world state:

- `ability_use_started`
- `ability_use_finished`
- `ability_use_impact`
- `ability_use_canceled`

### 4. Authoritative resolved payload

When the server has the resolved results, it sends `AbilityUseResolved` to the casting player.

This packet contains the authoritative effect payloads:

- damage
- healing
- statuses
- hit type
- phase

## Client Receive Path

### AbilityUseAccepted

- `GameManager` receives `AbilityUseAccepted`.
- It forwards to `Player.on_ability_accepted(...)`.
- Current rule: this does not adjust local `finish` or `impact` timing.

### AbilityUseRejected

- `GameManager` receives `AbilityUseRejected`.
- It forwards to `Player.on_ability_rejected(...)`.
- `Player` calls `ability_manager.reject_request(...)`.
- Any cancel events produced are fed into `AbilityEventController`.

### World-state lifecycle events

- `GameManager` receives the world-state event.
- `GameManager` forwards it to the source entity:
  - `Player` for the local player
  - `RemoteEntity` for remote entities

- The entity forwards it into its `AbilityEventController`.

`AbilityEventController` then decides whether to emit:

- Remote entities:
  - process normally

- Local player:
  - ignore `started` / `finished` / `impact` if they match a tracked local request
  - do not ignore `canceled`

### AbilityUseResolved

- `GameManager` receives `AbilityUseResolved`.
- It forwards to `Player.on_ability_resolved(...)`.
- `Player` forwards it into `AbilityEventController`.
- `AbilityEventController` emits `ability_resolved(resolved)`.

## Important Current Limitation

The initial ACK does **not** carry damage/healing/status numbers.

- `AbilityUseAccepted` carries timing only.
- `AbilityUseResolved` carries the actual effect payloads.

Current client behavior:

- `AbilityUseResolved` is received and emitted by `AbilityEventController`.
- The resolved payload is currently logged / exposed to subscribers.
- It is **not** currently stored in a client-side queue for deferred application exactly at local impact time.

So if the intended model is:

- local player predicts `impact` timing locally
- authoritative effect numbers are buffered when `AbilityUseResolved` arrives
- those numbers are then consumed when local `impact` occurs

that buffering/apply step still needs to be implemented.
