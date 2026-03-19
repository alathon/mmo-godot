# Zoning: Zone Transitions & Orchestration

## Overview

The game world is divided into zones, each running as a separate headless Godot game-server
instance. Players transition between zones at zone borders — similar to EverQuest's zone
lines. An orchestrator service mediates handoffs between game-servers so they don't need
direct knowledge of each other.

## Architecture

```
                  ┌──────────────┐
                  │ Orchestrator │
                  └──┬───────┬───┘
                     │       │
              WS/PB  │       │  WS/PB
                     │       │
              ┌──────┴──┐ ┌──┴───────┐
              │ Server A │ │ Server B │
              │ (forest) │ │ (other)  │
              └──────────┘ └──────────┘
                   ▲
                   │ ENet
                   │
              ┌────┴─────┐
              │  Client   │
              └───────────┘
```

- **Game servers** each run one zone. They register with the orchestrator on startup
  and report their zone ID, address, port, and capacity.
- **Orchestrator** maintains a registry of active game servers and handles zone-transition
  handoffs. It does not run game logic.
- **Clients** connect to one game server at a time via ENet. They only talk to the
  orchestrator indirectly — the current game server relays handoff instructions.

## Zone Scene Architecture

Each zone has one canonical scene (e.g., `Forest.tscn`) containing everything: terrain,
lighting, skybox, zone borders, and spawn points. Both the server and client load this
same scene at runtime into a shell that owns their respective systems.

### Canonical Zone Scene

One scene per zone. This is the scene you open in the Godot editor to author the world.

**Location:** `src/common/zones/<ZoneName>.tscn`

```
Root (Node3D)
├── Terrain3D
├── DirectionalLight3D
├── Sky3D (WorldEnvironment)
├── ZoneBorders
│   ├── ToOtherZone (ZoneBorder / Area3D)
│   │   └── CollisionShape3D
│   └── FromOtherZone (Node3D)      # spawn point marker
└── ... (static geometry, future NPC spawners, etc.)
```

Zone scenes are registered in `Globals.gd`:

```gdscript
const ZONE_SCENES: Dictionary = {
    "forest": "res://src/common/zones/Forest.tscn",
    "other": "res://src/common/zones/Other.tscn",
}
```

Future server-only nodes (NPC spawners, combat managers) are added to the canonical
scene and tagged with the `server_only` group. The client strips these on load.

### Server Shell

A single `ServerZone.tscn` is the server's entry point for all zones. It loads the
zone scene at runtime based on the `--zone` CLI argument.

**Location:** `src/game-server/zones/ServerZone.tscn`

```
ServerZone (Node)           ← ServerZone.gd: ENet server, tick sim, orchestrator WS
├── Network
├── Entities                ← server player nodes live here
├── DebugOverlay
├── ZoneContainer (Node3D)  ← zone scene loaded here at runtime
│   └── (Forest.tscn loaded at runtime)
└── Camera3D                ← required by Terrain3D even on headless
```

`ServerZone.gd` parses CLI args (`--zone`, `--port`) and loads the zone:

```sh
godot --headless --scene "res://src/game-server/zones/ServerZone.tscn" \
      -- --zone forest --port 7000
```

### Client Shell

A single `Game.tscn` persists across zone transitions. It loads/unloads zone scenes
as the player moves between zones.

**Location:** `src/client/Game.tscn`

```
Root (Node3D)
├── Network
│   └── InputBatcher
├── GameManager             ← handles zone loading, transitions, reconnection
├── LocalInput
├── CameraPivot
│   └── SpringArm3D
│       └── Camera
├── Entities                ← LocalPlayer + RemotePlayers
│   └── LocalPlayer
├── ZoneContainer (Node3D)  ← zone scene loaded here at runtime
│   └── (Forest.tscn loaded at runtime)
└── DebugOverlay
```

On zone load, `GameManager` strips any nodes in the `server_only` group:

```gdscript
func load_zone(zone_id: String) -> void:
    # ... instantiate scene ...
    _zone_container.add_child(_current_zone)
    for node in _current_zone.get_children():
        if node.is_in_group("server_only"):
            node.queue_free()
```

### Summary

| Component | Scene | Contains | Who loads it |
|---|---|---|---|
| Canonical zone | `src/common/zones/Forest.tscn` | Terrain, lighting, skybox, zone borders, spawn points | Both (at runtime) |
| Server shell | `src/game-server/zones/ServerZone.tscn` (one for all zones) | ENet server, tick sim, orchestrator, Entities | Game-server on startup |
| Client shell | `src/client/Game.tscn` (one for all zones) | GameManager, Network, Camera, Input, Entities | Client on startup |

Terrain, lighting, and borders are authored once. Server-only nodes use the `server_only`
group and are stripped by the client on load. Both shells persist across zone transitions —
only the scene in `ZoneContainer` is swapped.

## Zone Borders and Spawn Points

Zone borders are `Area3D` nodes placed in the canonical zone scene. They trigger zone
transitions when a player enters them. Spawn points are `Node3D` markers in the
destination zone that define where arriving players appear.

### ZoneBorder.gd

```gdscript
class_name ZoneBorder
extends Area3D

@export var target_zone_id: String = ""
@export var target_spawn_path: String = ""

func _ready() -> void:
    add_to_group("zone_borders")
```

- `target_zone_id` — which zone to transfer the player to (e.g., `"other"`).
- `target_spawn_path` — path to a `Node3D` spawn marker in the *destination* zone,
  relative to that zone's root node (e.g., `"ZoneBorders/FromForestZone"`).

### Scene layout example

In `Forest.tscn`:
```
ZoneBorders
├── ToOtherZone (ZoneBorder / Area3D)    → target_zone_id = "other"
│   │                                      target_spawn_path = "ZoneBorders/FromForestZone"
│   └── CollisionShape3D                 # tall thin box along the zone edge
└── FromOtherZone (Node3D)               # spawn marker for players arriving FROM other
```

In `Other.tscn`:
```
ZoneBorders
├── ToForestZone (ZoneBorder / Area3D)   → target_zone_id = "forest"
│   │                                      target_spawn_path = "ZoneBorders/FromOtherZone"
│   └── CollisionShape3D
└── FromForestZone (Node3D)              # spawn marker for players arriving FROM forest
```

The naming convention is: `To<Zone>` for the border trigger, `From<Zone>` for the
spawn point. The spawn path is resolved on the destination server via
`_current_zone.get_node_or_null(spawn_path)`.

### Detection

Both server and client detect zone border collisions using the `zone_borders` group:

**Server** (`ServerZone.gd`): freezes the player, zeros velocity, clears input buffer,
and initiates the orchestrator transfer flow.

**Client** (`GameManager.gd`): immediately freezes the local player (stops input and
CSP prediction) so the player doesn't continue moving into the void while the transfer
is in progress.

### Border immunity

After arriving in a new zone via transfer, the player is immune to zone border triggers
for 2 seconds (`BORDER_IMMUNITY_TICKS = 40`). This prevents immediate bounce-back if
the spawn point is near a zone border.

## Zone Transition Flow

### Step-by-step handoff

```
 Client          Server A (forest)       Orchestrator        Server B (other)
   │                    │                      │                     │
   │  [player walks     │                      │                     │
   │   into border]     │                      │                     │
   │                    │                      │                     │
   │  freeze locally    │                      │                     │
   │                1. Freeze player            │                     │
   │                   Zero velocity            │                     │
   │                   Clear input buf          │                     │
   │                2. Send transfer req        │                     │
   │                    │── ZoneTransfer ──────▶│                     │
   │                    │   (peer_id,           │                     │
   │                    │    from/to zone,      │                     │
   │                    │    player_state,      │                     │
   │                    │    entry_spawn_path)  │                     │
   │                    │                      │── PreparePlayer ───▶│
   │                    │                      │   (token,            │
   │                    │                      │    player_state,     │
   │                    │                      │    entry_spawn_path) │
   │                    │                      │                     │
   │                    │                      │◀─ PreparePlayerAck ─│
   │                    │                      │   (token, accepted)  │
   │                    │                      │                     │
   │                    │◀─ ZoneTransferResp ──│                     │
   │                    │   (peer_id, token,   │                     │
   │                    │    addr, port)        │                     │
   │                    │                      │                     │
   │◀── ZoneRedirect ──│                       │                     │
   │    (zone_id, addr, │                      │                     │
   │     port, token)   │                      │                     │
   │                    │                      │                     │
   │  unfreeze          │                      │                     │
   │  disconnect        │                      │                     │
   │  load new zone     │  3. Remove player     │                     │
   │                    │                      │                     │
   │──────────── connect + ZoneArrival(token) ──────────────────────▶│
   │                    │                      │              4. Resolve spawn
   │                    │                      │                 path → position
   │                    │                      │                 Spawn player
   │                    │                      │                 Set border immunity
   │◀─────────── clock sync, begin play ───────────────────────────│
```

### Detailed steps

1. **Trigger**: Player's `CharacterBody3D` enters a ZoneBorder `Area3D`. Both the client
   (instant local freeze) and the server detect this. The server freezes the player —
   zeros velocity, clears input buffer, stops simulation and continues including them in
   world diffs so the client reconciles to a stopped state.

2. **Transfer request**: Server A sends `ZoneTransferRequest` to the orchestrator with the
   player's state and the `target_spawn_path` from the ZoneBorder.

3. **Orchestrator routes**: The orchestrator looks up which game-server is running the
   target zone. It generates a `transfer_token` and sends `PreparePlayer` to Server B.

4. **Server B confirms**: Server B stores the pending arrival (position, velocity,
   spawn path) keyed by token and replies `PreparePlayerAck(accepted=true)`.

5. **Redirect**: The orchestrator sends `ZoneTransferResponse` to Server A. Server A
   forwards a `ZoneRedirect` to the client, then removes the player.

6. **Client reconnects**: The client unfreezes, disconnects from Server A, loads the new
   zone scene, and connects to Server B. On connection, it sends `ZoneArrival` with the
   transfer token.

7. **Server B spawns**: Server B validates the token, resolves the spawn path to a
   `Node3D` position in the zone scene, places the player there, grants border immunity,
   and resets the input state so simulation waits for the client's input buffer to fill.

## Transfer Token

The transfer token prevents unauthorized zone entry.

- Generated by the orchestrator (16 random bytes, hex-encoded).
- Sent to both Server B (via `PreparePlayer`) and the client (via `ZoneRedirect`).
- One-time use: Server B removes it from `_pending_arrivals` after the player connects.
- Time-limited: expires after 30 seconds (`TOKEN_TIMEOUT`). The orchestrator periodically
  prunes expired tokens.

## Orchestrator ↔ Game-Server Communication

Game servers and the orchestrator communicate over persistent WebSocket connections using
protobuf-encoded `OrchestratorPacket` messages. The orchestrator runs as a headless Godot
instance with a raw `TCPServer` + `WebSocketPeer` (not `WebSocketMultiplayerPeer`, which
would conflict with ENet's multiplayer protocol).

### Heartbeat

The orchestrator sends `Heartbeat` pings every 5 seconds. Game servers respond with
`HeartbeatAck`. If no ack is received within 15 seconds, the orchestrator disconnects
the peer and unregisters the zone.

### Messages (OrchestratorPacket oneof)

```protobuf
message OrchestratorPacket {
  oneof payload {
    ZoneRegister zone_register = 1;
    ZoneTransferRequest zone_transfer_request = 2;
    PreparePlayer prepare_player = 3;
    PreparePlayerAck prepare_player_ack = 4;
    ZoneTransferResponse zone_transfer_response = 5;
    Heartbeat heartbeat = 6;
    HeartbeatAck heartbeat_ack = 7;
  }
}
```

See `src/common/proto/packets.proto` for full message definitions.

## Client-Side Transition

`GameManager.gd` handles the reconnection flow:

1. Receive `ZoneRedirect` from current server (zone_id, address, port, transfer token).
2. Store the transfer token.
3. Unfreeze the local player, clear input history and pending server state.
4. Clear all remote players.
5. Load the new zone scene into `ZoneContainer` (stripping `server_only` nodes).
6. Reconnect to the target server.
7. On connection, send `ZoneArrival` with the transfer token.
8. Run clock sync, wait for input buffer to fill, resume play.

## Failure Handling

| Failure | Resolution |
|---|---|
| Destination zone not registered | Orchestrator rejects the transfer. TODO: notify origin to unfreeze the player. |
| Destination rejects (`accepted=false`) | Orchestrator drops the pending transfer. TODO: notify origin to unfreeze. |
| Client fails to connect within timeout | Destination discards the pending arrival after 30s. |
| Orchestrator down | Servers cannot initiate transfers. Game within a single zone continues. |
| Origin crashes mid-handoff | If PreparePlayer already sent, client can still connect to destination with the token. |

## Design Decisions

### Why an orchestrator instead of server-to-server communication?

- Servers don't need to discover or know about each other.
- The orchestrator is the single source of truth for "which server runs which zone."
- Easier to add server spin-up/spin-down, load balancing, and zone migration later.
- Simpler security: game servers only accept connections from known orchestrators.

### Why WebSocket + protobuf for orchestrator communication?

- Reuses the existing protobuf tooling (Godobuf) and message definitions.
- Persistent connection allows the orchestrator to push messages without polling.
- Both sides share the same language and serialization.

### Why raw WebSocketPeer instead of WebSocketMultiplayerPeer?

- `WebSocketMultiplayerPeer` wraps messages in its own framing protocol, which is
  incompatible with ENet's `MultiplayerPeer`. Since game servers already use ENet for
  client connections, using `WebSocketMultiplayerPeer` for the orchestrator would cause
  protocol conflicts.

### Why transfer tokens instead of just peer IDs?

- Peer IDs are assigned by ENet per-connection and are not globally unique.
- Tokens prevent a malicious client from connecting directly and claiming to be transferred.
- Tokens are time-limited and one-use, limiting the window for replay attacks.

### Why freeze-then-redirect instead of seamless handoff?

- Seamless (connecting to both servers simultaneously) is complex: dual input streams,
  duplicate entity state, split-brain risk.
- A brief freeze (1-3 seconds) is acceptable and was the norm in classic MMOs.
- Much simpler to implement correctly and reason about.

### Why spawn paths instead of coordinates?

- Coordinates require knowing the exact world position in another zone at design time.
- Spawn paths reference a `Node3D` in the destination zone's scene tree. You place a
  marker node visually in the editor and reference it by path.
- If terrain changes, the marker moves with it — no coordinate updates needed.
