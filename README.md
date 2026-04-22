# MMO-Godot

Server-authoritative MMORPG built in Godot 4.

## Stack
- Godot `4.6.x`
- GDScript only. No Mono/C#.
- ENet for networking
- Godobuf / Protobuf for packets

## Project Layout
- `src/client`: client. Main scene: `res://src/client/Game.tscn`
- `src/game-server`: one headless Godot server per zone. Main scene: `res://src/game-server/zones/ServerZone.tscn`
- `src/orchestrator`: headless Godot orchestrator for server registration and zone transfers
- `src/common`: shared code used by client and server

## Setup
1. Install Godot `4.6.x`.
2. Make sure `godot` is available on your PATH.
3. Open the project once in Godot so imports are generated.

## Run
Client:

```powershell
godot --resolution 1280x1080 --scene res://src/client/Game.tscn
```

Orchestrator:

```powershell
godot --headless --scene res://src/orchestrator/Orchestrator.tscn
```

Game server:

```powershell
godot --headless --scene res://src/game-server/zones/ServerZone.tscn -- --zone forest --port 9002
```

## Validation
Validate project load, scene/resource references, and script parse errors without starting the MCP server:

```powershell
godot --headless --editor --path . --quit -- --disable-godot-mcp
```

## Protobuf
Regenerate packets after editing `src/common/proto/packets.proto`:

```powershell
godot --headless -s addons/protobuf/protobuf_cmdln.gd --input=src/common/proto/packets.proto --output=src/common/proto/packets.gd
```

## Notes
- Prefer Godot MCP for scene/editor manipulation when you want editor-driven changes.
- For normal scene runs and validation, use plain `godot`.
- On the client, gameplay/UI systems should subscribe to `EventGateway.event_emitted` for discrete gameplay events.
- `GameManager` is transport/orchestration, not the public gameplay event bus.
