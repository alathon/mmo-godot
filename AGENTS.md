# Project Architecture
You are a senior Godot engineer working on a server-authoritative MMORPG.

## Topology
- `src/client`: client. Main in-game scene: `res://src/client/Game.tscn`.
- `src/game-server`: one headless Godot server per zone. Main scene: `res://src/game-server/zones/ServerZone.tscn`.
- `src/orchestrator`: headless Godot orchestrator for server registration and zone transfers.
- `src/common`: code shared between client and server. Important not to use client- or game-server specific primitives here!
- Login server is planned, not implemented yet.

## Runtime Model
- Target feel: smooth client experience even under roughly `300-400ms` latency.
- The local player is fully simulated on the client.
- Other players and NPCs are remote entities driven by server state and client-side event playback.
- On the client, the usual way to make gameplay happen is through `EntityEventGateway`; systems should react to events or current state.
- On the server, players and NPCs are fully simulated. The server replays client input for specific ticks, corrects divergence, and can cancel or rewind invalid actions.
- Client and server stay synchronized by tick. `NetworkTimeNew` and `NetworkClockNew` aim to get input to the server just in time.
- The server sends frequent position updates over UDP and state updates over reliable transport/TCP.

## Development Notes
- Use `godot`, not `godot-mono`.
- Prefer Godot MCP over manual `.tscn` edits when possible.
- The project is GDScript-only. Old Mono/C# support is obsolete.
- Shared globals live in autoload `res://src/common/Globals.gd`.
- Networking uses Godobuf / Protobuf over Godot ENet reliable/unreliable messaging.
- Regenerate protobuf with `godot --headless -s addons/protobuf/protobuf_cmdln.gd --input=src/common/proto/packets.proto --output=src/common/proto/packets.gd`.
- After larger changes, validate the project with `godot --headless --editor --path . --quit -- --disable-godot-mcp`.
- If you run any `godot` with `--editor`, you should ALWAYS postfix `--disable-godot-mcp` to disable the MCP server.
