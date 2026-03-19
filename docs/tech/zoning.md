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
            gRPC/WS  │       │  gRPC/WS
                     │       │
              ┌──────┴──┐ ┌──┴───────┐
              │ Server A │ │ Server B │
              │ (forest) │ │ (desert) │
              └──────────┘ └──────────┘
                   ▲
                   │ ENet
                   │
              ┌────┴─────┐
              │  Client   │
              └───────────┘
```

- **Game servers** each run one zone scene. They register with the orchestrator on startup
  and report their zone ID, address, port, and capacity.
- **Orchestrator** maintains a registry of active game servers and handles zone-transition
  handoffs. It does not run game logic.
- **Clients** connect to one game server at a time via ENet. They only talk to the
  orchestrator indirectly — the current game server relays handoff instructions.

## Zone Scene Architecture — Three Layers

Each zone in the game world is represented by three layers of scenes. This keeps
world-authoring in one place, prevents the client from seeing server-only data (NPC
spawns, combat managers), and avoids duplicating terrain/lighting across client and server.

### Layer 1: Shared World Scene

One scene per zone containing everything that is common to both client and server —
the visual and physical world. This is the scene you open in the Godot editor to sculpt
terrain, place buildings, adjust lighting, and lay out zone borders.

**Location:** `zones/<zone_name>/<ZoneName>.tscn`

```
Root (Node3D)
├── Terrain3D             # zone-specific terrain data
├── DirectionalLight3D
├── Sky3D (WorldEnvironment)
├── Buildings / Static geometry
├── ZoneBorders
│   ├── ZoneBorder (Area3D)  → target: "desert_01"
│   └── ZoneBorder (Area3D)  → target: "caves_01"
└── PlayerSpawnPoint (Marker3D)  # default spawn for new arrivals
```

**Exports on root script (`ZoneWorld.gd`):**

```gdscript
@export var zone_id: String = ""          # unique identifier, e.g. "forest_01"
@export var zone_name: String = ""        # display name, e.g. "Darkwood Forest"
```

The shared scene has no networking, no game logic, no NPC spawns. It is purely world data.

### Layer 2: Server Zone Scene

One scene per zone, owned by the game-server. It instances the shared world scene and
adds server-only nodes on top. When you open this scene in the editor, the full terrain
is visible (via the instanced world scene), so you can visually place NPC spawn points,
patrol paths, etc.

**Location:** `src/game-server/zones/<ZoneName>Server.tscn`

```
Root (ServerZone.gd)
├── World (instance of zones/forest/Forest.tscn)
├── Entities          # unique name — all player/NPC nodes are children
├── NPCSpawns
│   ├── NPCSpawn (goblin, respawn_time=30s, radius=5m)
│   ├── NPCSpawn (wolf_pack, respawn_time=60s, radius=10m)
│   └── ...
├── DebugOverlay      # server debug only
└── ... (future: combat managers, loot tables, event triggers)
```

`ServerZone.gd` contains all the server logic currently in `Zone.gd`: ENet server setup,
tick simulation, input buffering, player state management, world-state broadcast, and
zone-border handoff initiation.

**Exports on `ServerZone.gd`:**

```gdscript
@export var port: int = 7000
@export var max_clients: int = 32
```

The server scene reads `zone_id` and `PlayerSpawnPoint` from the instanced world scene.

### Layer 3: Client Shell (one for all zones)

A single `Game.tscn` scene that persists across zone transitions. It contains all
client-side systems and dynamically loads/unloads the shared world scene as the player
moves between zones.

**Location:** `src/client/Game.tscn`

```
Root (Node3D)
├── Network           # ENet client, NetworkClock
│   └── InputBatcher
├── GameManager       # handles connections, zone loading, transitions
├── LocalInput        # keyboard/mouse → input state
├── CameraPivot       # 3rd person camera rig
│   └── SpringArm3D
│       └── Camera
├── Entities          # unique name — LocalPlayer + RemotePlayers
│   └── LocalPlayer
├── ZoneContainer     # GameManager loads the shared world scene here
│   └── (Forest.tscn loaded at runtime)
├── DebugOverlay
└── UI (future: loading screen, chat, etc.)
```

`GameManager` is responsible for:
1. On connect: receiving the `zone_id` from the server, looking up the shared scene path,
   and instancing it under `ZoneContainer`.
2. On zone transition: freeing the old world scene, showing a loading screen, and
   instancing the new one after reconnecting.

The client needs a `zone_id → scene path` mapping so it knows which shared scene to load.
This can be a simple dictionary in an autoload or a resource file:

```gdscript
# In Globals.gd or a ZoneRegistry resource
const ZONE_SCENES: Dictionary = {
    "forest_01": "res://zones/forest/Forest.tscn",
    "desert_01": "res://zones/desert/Desert.tscn",
}
```

### Summary

| Layer | Scene | Contains | Who loads it |
|---|---|---|---|
| Shared world | `zones/forest/Forest.tscn` | Terrain, lighting, skybox, zone borders, player spawn | Server (instanced) + Client (dynamic) |
| Server zone | `src/game-server/zones/ForestServer.tscn` | Instances shared world + NPC spawns, server logic | Game-server on startup |
| Client shell | `src/client/Game.tscn` (one for all zones) | GameManager, Network, Camera, Input, UI | Client on startup |

This means terrain, lighting, and borders are authored once. NPC spawns are only in the
server scene (invisible to the client). Client systems persist across zone transitions
without per-zone duplication.

## ZoneBorder Nodes

Zone borders are `Area3D` nodes placed at the edges of a zone. When a player's
`CharacterBody3D` enters the area, the server initiates a zone transition.

### ZoneBorder.gd

```gdscript
class_name ZoneBorder
extends Area3D

## The zone_id of the destination zone.
@export var target_zone_id: String = ""

## Where the player appears in the destination zone (world coordinates in that zone).
@export var target_entry_position: Vector3 = Vector3.ZERO

## Optional: facing direction on arrival.
@export var target_entry_rotation_y: float = 0.0
```

Zone borders are children of the `ZoneBorders` node in each zone scene. They are
`CollisionShape3D`-backed volumes (typically long thin boxes along a map edge, or
doorway-shaped triggers for dungeon entrances).

The base zone script connects to each ZoneBorder's `body_entered` signal and maps
the entering body back to a peer ID to begin the handoff.

## Zone Transition Flow

### Step-by-step handoff

```
 Client          Server A (forest)       Orchestrator        Server B (desert)
   │                    │                      │                     │
   │  [player walks     │                      │                     │
   │   into border]     │                      │                     │
   │                    │                      │                     │
   │               1. Freeze player            │                     │
   │               2. Serialize state           │                     │
   │                    │──── ZoneTransfer ────▶│                     │
   │                    │     (peer_id,         │                     │
   │                    │      zone_id,         │                     │
   │                    │      player_state)    │                     │
   │                    │                      │──── PreparePlayer ─▶│
   │                    │                      │     (player_state,   │
   │                    │                      │      entry_pos)      │
   │                    │                      │                     │
   │                    │                      │◀─── Ready ──────────│
   │                    │                      │                     │
   │                    │◀── Redirect ─────────│                     │
   │                    │    (addr, port,       │                     │
   │                    │     transfer_token)   │                     │
   │                    │                      │                     │
   │◀── ZoneRedirect ──│                       │                     │
   │    (addr, port,    │                      │                     │
   │     token)         │                      │                     │
   │                    │                      │                     │
   │  disconnect        │                      │                     │
   │                    │  3. Remove player     │                     │
   │                    │                      │                     │
   │──────────── connect + present token ──────────────────────────▶│
   │                    │                      │              4. Spawn player
   │◀─────────── clock sync, begin play ───────────────────────────│
```

### Detailed steps

1. **Trigger**: Player's CharacterBody3D enters a ZoneBorder Area3D on Server A.
   Server A immediately freezes the player — stops simulating their input and stops
   including them in world-state broadcasts.

2. **Serialize**: Server A serializes the player's full transferable state into a protobuf
   message: position (overridden to the border's `target_entry_position`), velocity (zeroed),
   rotation, and eventually stats, inventory, buffs, etc.

3. **ZoneTransfer request**: Server A sends the serialized player state to the orchestrator,
   requesting a transfer to `target_zone_id`.

4. **Orchestrator routes**: The orchestrator looks up which game-server is running
   `target_zone_id`. If none is running, it can start one (future work). It sends a
   `PreparePlayer` message to Server B with the player state and a generated
   `transfer_token` (a one-time-use opaque string).

5. **Server B confirms**: Server B pre-allocates a slot for the incoming player and
   replies `Ready` to the orchestrator.

6. **Redirect**: The orchestrator sends a `Redirect` back to Server A with Server B's
   address, port, and the transfer token. Server A forwards this to the client as a
   `ZoneRedirect` packet, then removes the player from its state.

7. **Client reconnects**: The client disconnects from Server A, shows a loading screen,
   and connects to Server B. On connection, it sends the `transfer_token` instead of a
   normal join request.

8. **Server B spawns**: Server B validates the token (one-use, time-limited), spawns the
   player at the entry position with the transferred state, and begins normal simulation.
   The client runs clock sync and resumes play.

## Transfer Token

The transfer token prevents unauthorized zone entry. Without it, a player could connect
directly to any game server and bypass the handoff.

- Generated by the orchestrator (UUID or signed JWT).
- Sent to both Server B (so it knows what to expect) and to the client (via Server A).
- One-time use: Server B invalidates it after the player connects.
- Time-limited: expires after ~30 seconds. If the client fails to connect in time,
  Server B discards the pending slot and the orchestrator can instruct Server A to
  unfreeze the player.

## Orchestrator ↔ Game-Server Communication

Game servers and the orchestrator communicate over a persistent connection separate from
the ENet game traffic. Options:

- **WebSocket** — simple, Godot has native support via `WebSocketPeer`. Good if the
  orchestrator is also a Godot headless instance, since both sides can use the same
  protobuf message definitions.
- **HTTP/gRPC** — better if the orchestrator is a standalone service (e.g., Go, Rust).
  Game servers would POST to REST endpoints.

For consistency with the rest of the project (GDScript + protobuf), the initial
implementation should use **WebSocket + protobuf** with the orchestrator as a headless
Godot instance. This lets us reuse the existing `packets.proto` definitions and keep
everything in one language.

### Messages (additions to packets.proto)

```protobuf
// Game-server → Orchestrator
message ZoneRegister {
    string zone_id = 1;
    string address = 2;
    int32 port = 3;
    int32 max_players = 4;
    int32 current_players = 5;
}

// Game-server → Orchestrator
message ZoneTransferRequest {
    int32 peer_id = 1;
    string from_zone_id = 2;
    string to_zone_id = 3;
    PlayerState player_state = 4;  // serialized player data
}

// Orchestrator → Game-server (destination)
message PreparePlayer {
    string transfer_token = 1;
    PlayerState player_state = 2;
    float entry_x = 3;
    float entry_y = 4;
    float entry_z = 5;
    float entry_rot_y = 6;
}

// Game-server (destination) → Orchestrator
message PreparePlayerAck {
    string transfer_token = 1;
    bool accepted = 2;
}

// Orchestrator → Game-server (origin)
message ZoneTransferResponse {
    int32 peer_id = 1;
    string transfer_token = 2;
    string target_address = 3;
    int32 target_port = 4;
}

// Game-server → Client (via ENet)
message ZoneRedirect {
    string address = 1;
    int32 port = 2;
    string transfer_token = 3;
}

// Client → Game-server (on connect to destination)
message ZoneArrival {
    string transfer_token = 1;
}

// Shared
message PlayerState {
    float pos_x = 1;
    float pos_y = 2;
    float pos_z = 3;
    float vel_x = 4;
    float vel_y = 5;
    float vel_z = 6;
    float rot_y = 7;
    // Future: stats, inventory, buffs, quest state, etc.
}
```

## Client-Side Transition

`GameManager.gd` handles the reconnection flow:

1. Receive `ZoneRedirect` packet from current server (includes `zone_id`, address, port,
   transfer token).
2. Store the transfer token, target address, and port.
3. Disconnect from current server. Free the current world scene from `ZoneContainer`.
4. Show loading screen.
5. Connect to target server. On connection, send `ZoneArrival` with the token.
6. Run clock sync (existing `NetworkClock` flow).
7. Look up the zone's shared world scene via `ZONE_SCENES[zone_id]` and instance it
   into `ZoneContainer`.
8. Resume normal play.

## Failure Handling

| Failure | Resolution |
|---|---|
| Server B not running | Orchestrator starts it (future), or rejects the transfer and Server A unfreezes the player. |
| Server B full | Orchestrator rejects. Server A unfreezes the player and sends a "zone full" message to the client. |
| Client fails to connect to B within timeout | Server B discards the pending slot. Orchestrator can tell Server A to unfreeze. If Server A already removed the player, orchestrator holds the player state and re-routes on next attempt. |
| Orchestrator down | Server A cannot initiate transfers. Players see "zone unavailable" at borders. Game within a single zone continues to work. |
| Server A crashes mid-handoff | Orchestrator detects via heartbeat loss. If the transfer was already sent to B, the client can still connect to B with the token. If not, the player state is lost (mitigated by periodic persistence to a database). |

## Design Decisions

### Why an orchestrator instead of server-to-server communication?

- Servers don't need to discover or know about each other.
- The orchestrator is the single source of truth for "which server runs which zone."
- Easier to add server spin-up/spin-down, load balancing, and zone migration later.
- Simpler security: game servers only accept connections from known orchestrators.

### Why WebSocket + protobuf for orchestrator communication?

- Reuses the existing protobuf tooling (Godobuf) and message definitions.
- Persistent connection allows the orchestrator to push messages (e.g., "prepare for
  incoming player") without polling.
- If the orchestrator is a headless Godot instance, both sides share the same language
  and serialization — no polyglot overhead.

### Why transfer tokens instead of just peer IDs?

- Peer IDs are assigned by ENet per-connection and are not globally unique. A peer ID
  on Server A means nothing to Server B.
- Tokens prevent a malicious client from connecting directly to Server B and claiming
  to be a transferred player.
- Tokens are time-limited and one-use, limiting the window for replay attacks.

### Why freeze-then-redirect instead of seamless handoff?

- Seamless (connecting to both servers simultaneously) is complex: dual input streams,
  duplicate entity state, split-brain risk.
- A brief loading screen (1-3 seconds) is acceptable for zone transitions and was the
  norm in classic MMOs.
- Much simpler to implement correctly and reason about.

## Implementation Order

1. **Shared world scene** — Extract terrain, lighting, skybox, and borders from the
   current `Zone.tscn` and `Game.tscn` into `zones/forest/Forest.tscn`. Create
   `ZoneWorld.gd` with `zone_id` and `zone_name` exports. Add a `PlayerSpawnPoint`
   Marker3D.
2. **Server zone scene** — Create `src/game-server/zones/ForestServer.tscn` that
   instances the shared world scene. Move server logic from `Zone.gd` into
   `ServerZone.gd`. Validate that the server runs correctly with the new structure.
3. **Client shell refactor** — Refactor `Game.tscn` to add a `ZoneContainer` node.
   Update `GameManager.gd` to dynamically load the shared world scene into it.
   Add `ZONE_SCENES` mapping to `Globals.gd`.
4. **ZoneBorder node** — Create the `ZoneBorder` Area3D script. Place test borders in
   the forest world scene. Wire up `body_entered` detection in `ServerZone.gd`.
5. **Proto messages** — Add the transfer-related messages to `packets.proto`.
6. **Orchestrator** — Headless Godot instance with WebSocket server. Handles zone
   registration and transfer routing.
7. **Server-side handoff** — `ServerZone.gd` initiates transfers on border contact,
   freezes player, sends state to orchestrator, handles redirect response.
8. **Client reconnection** — `GameManager.gd` handles `ZoneRedirect`, disconnect,
   loading screen, reconnect with token, clock sync.
9. **Failure handling** — Timeouts, token expiry, unfreeze-on-failure.
