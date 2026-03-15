# Server-Authoritative Input Processing & Ability System

## Core Principle

The server is the sole authority over game state. Clients send input, the server simulates
it using Godot's physics (move_and_slide, CharacterBody3D), and broadcasts the resulting
state. Clients use CSP (Client-Side Prediction) for responsiveness and reconcile with
server state when it arrives.

## Input Buffer & Tick Alignment

Clients and server share a synchronized tick clock (via NetworkTime + NetworkClock NTP sync).
The server deliberately processes input from N ticks in the past, giving clients a window
to deliver their input on time.

### Flow

1. Client sends input frame tagged for **simulation tick T**
2. Server receives it (possibly several ticks later due to network latency)
3. Server buffers the input until it reaches tick T+N, then processes tick T's input
4. N is the **input buffer size** (e.g., 5 ticks = 250ms at 20 tick/s)

### Example (N=5)

- Client A sends input for simulation tick 250
- Server receives it at server tick 252
- Server processes tick 250's input when server reaches tick 255 (250+5)
- Input arrived 3 ticks early — plenty of margin

### Buffer Size Tradeoffs

- **Too small**: clients with higher ping miss the window, input arrives late
- **Too large**: more latency before actions take effect
- N=5 at 20 tick/s = 250ms buffer, covers most reasonable connections

### Late Input

When input arrives after the server has already processed that tick (client ping > buffer
window), options include:
- Drop the input (simplest, client must re-send)
- Process it late (causes desync with other clients' timelines)
- Design decision to be made based on gameplay requirements

## Remote Entity Rendering

Remote players (other players on your screen) are rendered via **snapshot interpolation**:
- Server sends position snapshots every tick via WorldDiff
- Client buffers snapshots in a HistoryBuffer (ring buffer, capacity 64)
- RemoteInterpolator advances a render_tick in _process at TICK_RATE, lagging
  RENDER_DELAY ticks behind latest received snapshot
- Interpolates between from_tick and to_tick using alpha for sub-tick smoothness

### Key Detail: CharacterBody3D + set_physics_process(false)

Remote players use CharacterBody3D but with `set_physics_process(false)`. This prevents
the engine's internal physics sync from interfering with interpolated positions. The
interpolator directly sets `global_position` each render frame.

`move_and_slide()` can still be called explicitly (e.g., for displacement effects) since
it works regardless of whether `_physics_process` is enabled — it just queries the physics
server on demand.

## Abilities (e.g., Shield Bash with Knockback)

### Server-Authoritative Flow

1. **Client A** sends input frame with ability action: `{ability: SHIELD_BASH, target: B}`
2. **Server** validates at the correct simulation tick (range, cooldown, line of sight, etc.)
3. **Server** applies knockback impulse to B's server-side CharacterBody3D
4. **Server** continues ticking — B's position naturally reflects the knockback in
   subsequent WorldDiff broadcasts
5. **All clients** see B get knocked back via normal snapshot interpolation — no special
   client-side code required for basic functionality

### Client B (Target) — CSP Reconciliation

- Client B keeps sending movement input normally during knockback
- Server combines B's input + knockback velocity in its simulation
- Server sends B a **knockback event**: `{type: KNOCKBACK, impulse: Vector3, tick: int}`
- Client B retroactively inserts the knockback at the specified tick in their CSP history
- Client B re-simulates forward from that tick to present
- Result: B's local prediction converges with server state without a visible snap

### Client A (Caster) — Optional Prediction

For instant visual feedback (hiding RTT), Client A can:
- Predict the knockback on B's remote entity immediately
- Pause B's RemoteInterpolator during the predicted displacement
- Use `move_and_slide()` on B's CharacterBody3D for collision-correct displacement
- When server snapshots arrive reflecting the knockback, resume interpolation
- If prediction matches server, transition is seamless
- If prediction diverges, there will be a small correction when interpolation resumes

### Displacement Implementation (Current Prototype)

Player.gd has a displacement system for testing:
- `apply_displacement(impulse)` — applies a velocity impulse, pauses interpolation
- `_on_displacement_tick()` — runs each network tick via on_tick signal, calls
  move_and_slide() with decaying velocity (×0.85 per tick)
- When velocity decays to zero, resumes interpolation (render_tick jumps to latest)
- This runs inside NetworkTime's _physics_process, so Engine.is_in_physics_frame()
  is true and move_and_slide() uses the correct physics delta

## physics_factor

`move_and_slide()` internally uses `1/physics_fps` as its delta. Since network ticks run
at a lower rate (20/s) than physics (60/s), velocity must be scaled:

```
velocity *= NetworkTime.physics_factor   # = TICK_INTERVAL * physics_ticks_per_second = 3.0
move_and_slide()
velocity /= NetworkTime.physics_factor
```

This ensures displacement per tick matches the intended TICK_INTERVAL regardless of
the physics tick rate.

**Important**: `move_and_slide()` uses different deltas depending on context:
- Called from `_physics_process`: uses `get_physics_process_delta_time()` (fixed, correct)
- Called from `_process`: uses `get_process_delta_time()` (variable, FPS-dependent — wrong)

Always call `move_and_slide()` from within a physics frame (either `_physics_process`
directly or from a signal handler that fires during one, like NetworkTime.on_tick).
