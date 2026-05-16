# Data Model: Wave Loop with Per-Wave Difficulty Table

**Branch**: `DEATHN-19-wave-loop-with` | **Date**: 2026-05-16

## Entities

### WaveConfig (new compile-time struct)

Represents the difficulty parameters for a single wave. Stored as a compile-time constant array for waves 1–15.

```zig
const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
};
```

| Field | Type | Constraints | Source |
|-------|------|-------------|--------|
| `target_wpm` | `u32` | 15–110 for explicit waves; 110 for 16+ | Difficulty table (spec FR-001, FR-015) |
| `spawn_delay` | `f32` | 0.66–4.80 seconds | Difficulty table (spec FR-003, FR-016) |
| `fall_speed` | `f32` | 0.5–2.0 pixels/frame | Difficulty table (spec FR-004) |
| `pool_size` | `u32` | 5–33 for explicit waves; 33+2*(wave-15) for 16+ | Difficulty table (spec FR-002, FR-015) |

**Lookup**: `fn getWaveConfig(wave: u32) WaveConfig` — returns `WAVE_TABLE[wave - 1]` for waves 1–15, computes scaling formula for wave 16+.

### Zombie (existing, unchanged)

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,          // Now set from WaveConfig.fall_speed instead of ZOMBIE_FALL_SPEED constant
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
};
```

No structural change. The `speed` field already exists; it was always initialized from a constant. Now initialized from `getWaveConfig(current_wave).fall_speed`.

## State Variables (new module-level globals)

| Variable | Type | Initial Value | Reset on Restart | Purpose |
|----------|------|---------------|------------------|---------|
| `current_wave` | `u32` | `1` | Yes → `1` | Current wave number |
| `wave_kills` | `u32` | `0` | Yes → `0` | Zombies killed in current wave |
| `wave_spawned` | `u32` | `0` | Yes → `0` | Zombies spawned in current wave |
| `is_transitioning` | `bool` | `false` | Yes → `false` | Whether wave transition countdown is active |
| `transition_timer` | `f32` | `0.0` | Yes → `0.0` | Seconds remaining in transition countdown |

## Constants (modified and new)

| Constant | Status | Value |
|----------|--------|-------|
| `ZOMBIE_FALL_SPEED` | **Removed** | Replaced by per-wave `fall_speed` |
| `spawn_delay` | **Removed** | Replaced by per-wave `spawn_delay` via `getWaveConfig()` |
| `WAVE_TRANSITION_DURATION` | **New** | `3.0` (seconds) |
| `WAVE_TABLE` | **New** | `[15]WaveConfig{ ... }` compile-time array |

## Difficulty Table (compile-time constant)

```zig
const WAVE_TABLE = [_]WaveConfig{
    .{ .target_wpm = 15,  .spawn_delay = 4.80, .fall_speed = 0.5, .pool_size = 5 },
    .{ .target_wpm = 18,  .spawn_delay = 4.00, .fall_speed = 0.6, .pool_size = 7 },
    .{ .target_wpm = 22,  .spawn_delay = 3.27, .fall_speed = 0.7, .pool_size = 9 },
    .{ .target_wpm = 26,  .spawn_delay = 2.77, .fall_speed = 0.8, .pool_size = 11 },
    .{ .target_wpm = 30,  .spawn_delay = 2.40, .fall_speed = 0.9, .pool_size = 13 },
    .{ .target_wpm = 35,  .spawn_delay = 2.06, .fall_speed = 1.0, .pool_size = 15 },
    .{ .target_wpm = 40,  .spawn_delay = 1.80, .fall_speed = 1.1, .pool_size = 17 },
    .{ .target_wpm = 45,  .spawn_delay = 1.60, .fall_speed = 1.2, .pool_size = 19 },
    .{ .target_wpm = 50,  .spawn_delay = 1.44, .fall_speed = 1.3, .pool_size = 21 },
    .{ .target_wpm = 55,  .spawn_delay = 1.31, .fall_speed = 1.4, .pool_size = 23 },
    .{ .target_wpm = 60,  .spawn_delay = 1.20, .fall_speed = 1.5, .pool_size = 25 },
    .{ .target_wpm = 70,  .spawn_delay = 1.03, .fall_speed = 1.6, .pool_size = 27 },
    .{ .target_wpm = 80,  .spawn_delay = 0.90, .fall_speed = 1.7, .pool_size = 29 },
    .{ .target_wpm = 90,  .spawn_delay = 0.80, .fall_speed = 1.8, .pool_size = 31 },
    .{ .target_wpm = 100, .spawn_delay = 0.72, .fall_speed = 1.9, .pool_size = 33 },
};
```

## State Transitions

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ┌──────────┐   wave complete    ┌──────────────┐      │
│   │ PLAYING  │ ─────────────────→ │ TRANSITIONING│      │
│   │          │                    │ (3s countdown)│      │
│   └────┬─────┘                    └──────┬───────┘      │
│        │                                 │              │
│        │ zombie reaches bottom    timer expires          │
│        │                                 │              │
│        ▼                                 │              │
│   ┌──────────┐                           │              │
│   │GAME OVER │                           │              │
│   │          │       advance wave        │              │
│   └────┬─────┘  ┌───────────────────────┘              │
│        │        │                                       │
│        │ ENTER  ▼                                       │
│        │   ┌──────────┐                                 │
│        └──→│ PLAYING  │ (wave 1 on restart,             │
│            │          │  next wave on transition end)    │
│            └──────────┘                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Wave Completion Condition

A wave is complete when:
- `wave_spawned >= pool_size` (all zombies for this wave have been spawned)
- `wave_kills >= pool_size` (all spawned zombies have been killed)

### Transition → Next Wave

When transition timer expires:
1. `current_wave += 1`
2. `wave_kills = 0`
3. `wave_spawned = 0`
4. `spawn_timer = 0.0`
5. `is_transitioning = false`

### Game Over → Restart

When ENTER pressed on game-over screen:
1. `is_game_over = false`
2. `current_wave = 1`
3. `wave_kills = 0`
4. `wave_spawned = 0`
5. `is_transitioning = false`
6. `transition_timer = 0.0`
7. `letter_count = 0`, null-terminate input
8. `spawn_timer = 0.0`
9. `resetZombies(allocator)`
