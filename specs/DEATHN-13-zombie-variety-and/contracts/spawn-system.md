# Contract: Spawn System Changes

## Overview

Modifications to `spawnZombie` in `src/main.zig` to support zombie type selection, type-based speed, anti-doublon enforcement, and trap cluster triggering.

## Modified Function Signature

```zig
fn spawnZombie(allocator: *std.mem.Allocator, rng: *std.Random) !bool
```

**Change**: Added `rng` parameter. Currently `spawnZombie` uses `raylib.GetRandomValue` which is not testable. The PRNG is threaded through for deterministic testing. `raylib.GetRandomValue` remains used for X-position (visual, not logic-critical).

## Spawn Flow (updated)

```
1. Find null slot in zombies[0..MAX_ZOMBIES]
2. Determine ZombieType via wave-weighted random (SPAWN_WEIGHT_TABLE)
3. Select name via name_lists.selectName(wave, type, active_names, forced_trap_group, rng)
   - Returns null → return false (spawn deferred)
4. If selection.category == .trap:
   - Set trap_cluster_group = selection.trap_group_index
   - Set trap_cluster_remaining = random(1, 2)
5. If trap_cluster_remaining > 0:
   - Decrement trap_cluster_remaining
   - If trap_cluster_remaining reaches 0: clear trap_cluster_group
6. Compute speed = getWaveConfig(current_wave).fall_speed * getSpeedMultiplier(zombie_type)
7. Create Zombie with zombie_type field set
8. Assign to slot, return true
```

## New Helper Functions

```zig
fn getSpeedMultiplier(zombie_type: ZombieType) f32
```
Returns 1.0 for standard, RUNNER_SPEED_MULTIPLIER (1.8) for runner, TANK_SPEED_MULTIPLIER (0.5) for tank.

```zig
fn getSpawnWeights(wave: u32) SpawnWeights
```
Returns weights from SPAWN_WEIGHT_TABLE based on wave bracket.

```zig
fn selectZombieType(weights: SpawnWeights, rng: *std.Random) ZombieType
```
Generates random 0–99, selects type by cumulative weight.

```zig
fn getNameWeights(wave: u32) NameWeights
```
Returns weights from NAME_WEIGHT_TABLE based on wave bracket.

## Draw Changes

In `drawZombies` (src/main.zig), the tint block becomes:

```zig
const tint: raylib.Color = blk: {
    if (is_dying) {
        if (dying_zombie_index) |idx| {
            if (idx == i) break :blk raylib.RED;
        }
    }
    break :blk getZombieTint(zomb.zombie_type);
};
```

```zig
fn getZombieTint(zombie_type: ZombieType) raylib.Color {
    return switch (zombie_type) {
        .standard => raylib.WHITE,
        .runner => raylib.GREEN,
        .tank => raylib.BLUE,
    };
}
```

## PRNG Change

Currently `main()` does not use `std.Random` — it only uses `raylib.GetRandomValue`. For testable spawn logic, introduce a module-level PRNG:

```zig
var prng: std.Random.DefaultPrng = undefined;
```

Initialized in `main()` with `std.time.milliTimestamp()` seed (matching existing pattern comment at CLAUDE.md line "seeds a DefaultPrng from milliTimestamp"). This PRNG is used for type selection and name selection. `raylib.GetRandomValue` continues to be used for X-position.

## Reset Changes

`resetZombies` additionally clears trap cluster state:
```zig
trap_cluster_group = null;
trap_cluster_remaining = 0;
```

## Input Buffer Change

```zig
const MAX_INPUT_CHARS = 20;  // was 9
```

`getCurrentMaxInput` returns 20 (no boss) or 35 (boss active). No other changes needed — the `name` buffer is already 36 bytes.

The text box width in `frame()` may need adjustment for 20-char display at font size 40. Current 225px fits ~9 chars; 20 chars at ~25px per char ≈ 500px. Adjust to ~500px and recenter.
