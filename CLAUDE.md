# Project Architecture
This is a modern server-authoritative MMORPG built using Godot. It will have the following architecture:

- Client (found in src/client) is initialized to run Game.tscn
- Game servers (found in src/game-server) is the 'Zone Server' which corresponds to a single game area, with some number of
players in it. The game servers are run as headless godot instances.
- Login server (not built yet) to authenticate user accounts.
- Orchestrators (not built yet) to start/stop game servers as needed, and direct clients to the appropriate Game server.

# Important notes
- Godot-Mono 4.6.1 (although we currently don't use any C#).
- Use GDScript over C# whenever possible.
- Godobuf / Protobuf for client/server communication, using Godots existing reliable/unreliable peer messaging system (ENet)
