# Networked Movement Issues

Review of `NetworkClock.gd`, `Network.gd`, `NetworkTime.gd`, and the client/server movement pipeline.

## Priority Summary

| # | Severity | Status | Issue |
|---|----------|--------|-------|
| 1 | **High** | Fixed | `last_input` re-executes jump forever on packet loss |
| 2 | **Low** | Won't fix | Rotation not stored/restored during reconciliation replay |
| 3 | **Medium** | By design | Full movement re-execution on missing input causes large divergence |
| 4 | **Medium** | Fixed | Panic re-sync doesn't pause tick loop; stale offset persists |
| 5 | **Low** | Known limitation | `server_time` field set but never read; tick quantization error |
| 6 | **Low** | Fixed | `_process_time` / `_tick_time` divergence affects `tick_factor` |
| 7 | **Low** | Open | Overwritten pending server state on burst packets |
| 8 | **Low** | By design | `move_toward` not delta-scaled (works by accident) |
| 9 | **Low** | By design | `rot_y` sent but never consumed by server |
| 10 | **Info** | Partially fixed | Tick alignment works but is fragile to drift |

---

## Issue 1: `last_input` re-executes jump forever on packet loss

**Severity:** High — **Status: Fixed**

`ServerPlayer.gd` now duplicates the input and clears `jump_pressed` before storing as `last_input`:
```gdscript
last_input = input.duplicate()
last_input["jump_pressed"] = false
```

Server also logs when replaying stale input: `[SERVER] REPLAY input for peer X at sim_tick=Y`.

---

## Issue 2: Rotation not stored/restored during reconciliation replay

**Severity:** Low — **Status: Won't fix**

Rotation (`rotation.y`) is purely visual — it doesn't affect position or velocity. Movement velocity is set directly from `input_x`/`input_z`, not from facing direction. The lerp_angle path-dependency during replay can cause a minor visual rotation snap after reconciliation, but it converges quickly since it targets the same input-derived angle.

Not worth the complexity of per-tick rotation history.

---

## Issue 3: Full movement re-execution on missing input causes large divergence

**Severity:** Medium — **Status: By design**

Re-executing last known input (minus jump) on packet loss is the standard approach. Alternatives (zeroing input, deceleration) feel worse on mildly lossy connections. The correction on direction change + packet loss is acceptable.

Server now logs replay events for visibility.

---

## Issue 4: Panic re-sync doesn't pause tick loop; stale offset persists

**Severity:** Medium — **Status: Fixed**

`NetworkClock` now snaps offset immediately on panic and calls `NetworkTime.reset_tick()`, which hard-resets the tick counter, accumulators, and emits `on_tick_reset`. Player clears input history on tick reset to avoid stale reconciliation data.

---

## Issue 5: `server_time` field set but never read; tick quantization error

**Severity:** Low — **Status: Known limitation**

The server sends `server_time` (unix timestamp) in clock pongs, but the clock system operates in "tick-time" domain (seconds since tick 0). Using unix time directly breaks the offset calculation because `_local_time` starts at 0, not at epoch. Properly bridging the two time domains would require significant refactoring.

The ±1 tick (±50ms) quantization from using integer `server_tick` is mitigated by lowest-RTT sample selection and clock stretching. Acceptable precision for gameplay.

---

## Issue 6: `_process_time` / `_tick_time` divergence affects `tick_factor`

**Severity:** Low — **Status: Fixed**

`_process_time` is now re-anchored to `_tick_time` after each tick loop, preventing accumulator drift. Between ticks, `_process` still advances `_process_time` smoothly for render interpolation.

---

## Issue 7: Overwritten pending server state on burst packets

**Severity:** Low — **Status: Open**

If two WorldDiffs arrive in the same frame, the second overwrites the first before reconciliation runs. In practice the latest state subsumes earlier state, so this is harmless for position. Could matter if reconciliation ever needs to validate every tick.

---

## Issue 8: `move_toward` not delta-scaled (works by accident)

**Severity:** Low — **Status: By design**

`move_toward(velocity.x, 0, Speed)` with Speed=10 and max speed=10 effectively snaps to zero in one tick. This is instant-stop behavior, which is clean and deterministic. If deceleration is ever desired, replace with a proper friction model.

---

## Issue 9: `rot_y` sent but never consumed by server

**Severity:** Low — **Status: By design**

Client sends `rotation.y` in input packets. Server currently computes rotation independently from movement direction. The field is intentionally kept for future use by the ability system (aiming, cone attacks, etc.).

---

## Issue 10: Tick alignment works but is fragile to drift

**Severity:** Info — **Status: Partially fixed**

Drift panic (±10 ticks) added via `NetworkTime.reset_tick()` prevents runaway drift. Clock stretching handles normal drift smoothly. Still no server→client feedback about input latency — the server silently drops stale input. Consider adding an input latency metric to WorldDiff in the future.
