# Project Architecture
This is a modern server-authoritative MMORPG built using Godot. It will have the following architecture:

- Client (found in src/client) is initialized to run Game.tscn
- Game servers (found in src/game-server) is the 'Zone Server' which corresponds to a single game area, with some number of
players in it. The game servers are run as headless godot instances.
- Login server (not built yet) to authenticate user accounts.
- Orchestrators (not built yet) to start/stop game servers as needed, and direct clients to the appropriate Game server.

The server is authoritative, meaning clients send their input to the server, and the server responds with the updated game state.
Because it takes time to process input and send back the updated game state, clients employ CSP (Client-Side Prediction)
and server reconciliation to ensure gameplay feels smooth and stays up-to-date with the servers state.

# Important notes
- Godot-Mono 4.6.1 (although we currently don't use any C#).
- Use GDScript over C# whenever possible.
- Godobuf / Protobuf for client/server communication, using Godots existing reliable/unreliable peer messaging system (ENet)
- Globals needed across client/servers are set in the Globals.gd script which is set to Autoload.

# Important commands

- To generate Godobuf/protobuf: godot-mono --headless -s addons/protobuf/protobuf_cmdln.gd --input=src/common/proto/packets.proto --output=src/common/proto/packets.gd
