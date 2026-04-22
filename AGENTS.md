# Project Architecture
You are a highly-experienced games engine engineer who specializes in Godot and networked multiplayer games.

## Architecture
This is a modern server-authoritative MMORPG.

- The client is in src/client, and the main in-game scene is Game.tscn
- Each game-server (src/game-server) hosts one zone. Game servers run as headless godot instances.
- Login server (not built yet) to authenticate user accounts.
- Orchestrator (src/orchestrator) is a headless godot instance that lets game-servers register themselves
with it, and orchestrates player transfer between game-servers.

In general the game is built to provide a smooth experience for the client, even with lag of up to ~300-400ms,
meaning we do client-side prediction where we can, and generally favor the client looking good, without letting the
client cheat (too much).

# Important development notes

- To generate Godobuf/protobuf: godot --headless -s addons/protobuf/protobuf_cmdln.gd --input=src/common/proto/packets.proto --output=src/common/proto/packets.gd
- You can use the godot-mcp-win MCP to instrument the Godot editor, to e.g., create scene nodes, run the game, modify the
scene and so on. You should prefer this over manually editing scene (.tscn) files where possible.
- We use GDScript. The project used to support Mono/C# but we don't do that anymore.
- Godobuf / Protobuf for client/server communication, using Godots existing reliable/unreliable peer messaging system (ENet)
- Globals needed across client/servers are set in the Globals.gd script which is set to Autoload.

# Simulated entities vs. not.

On the client, the local player is 'fully simulated' by the physics engine and other systems, while NPCs and other players
are instances of RemoteEntity, and they are instrumented primarily by the events coming in from the server -- like puppets on strings.

Because of this, the main way to get something to 'happen' in the game is to generate an event that goes through the event gateway. Systems
in the client should always be listening to events, or looking at the current state of an entity/thing, as a way to respond to things happening.

On the server, all players and NPCs are 'fully simulated'. The server generally replays player inputs, and in cases where it disagrees,
will send enough data to the client to let the client reconcile itself. The server may also disagree with things like what happens first,
causing it to explicitly cancel ability uses or similar; in those cases, messages are sent to the client and it is up to the client to rewind
accordingly.

The client and server are kept in-sync in terms of tick #, and all client input is marked for a particular tick. By measuring RTT, the client
tries to aim to send data 'just in time' for the server to consume it (NetworkTimeNew and NetworkClockNew).

The server sends two primary repeated broadcasts to clients: one for position updates (UDP), and one for 'state updates' (TCP).
