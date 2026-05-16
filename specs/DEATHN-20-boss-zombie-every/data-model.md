# Data Model: Boss Zombie Every Five Waves

**Branch**: `DEATHN-20-boss-zombie-every` | **Date**: 2026-05-16

## Entities

### Zombie (existing — no changes)

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
};
```

The boss reuses this struct as-is. The `name` field stores the boss phrase (also `[*:0]const u8`). The `speed` field is set to `wave_fall_speed * 0.5` at spawn time. No struct modifications are needed because boss-specific behavior (scale, tint, health bar) is driven by checking `boss == zomb` at draw time, not by struct fields.

### WaveConfig (existing — no changes)

```zig
const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
};
```

No changes. Boss spawn threshold is derived from `pool_size` at runtime.

### BossPhrases (new — `src/boss_phrases.zig`)

```zig
pub const BossPhrases = [10][*:0]const u8{
    "the dead walk again",
    "bones remember every step",
    "silence feeds the horde",
    "no grave holds them long",
    "they rise when sun falls",
    "cold hands reach for you",
    "the earth spits them out",
    "shadows crawl at midnight",
    "a whisper wakes the dead",
    "run before they find you",
};
```

- All lowercase, spaces only (FR-015)
- Longest phrase: "bones remember every step" = 25 chars, well within 35-char limit
- 10 phrases exactly (FR-015)
- Zero-terminated C strings, same format as `ZombieNames`

## New Module-Level State (in `src/main.zig`)

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `boss` | `?*Zombie` | `null` | Pointer to the active boss zombie, or null if no boss is active |
| `boss_spawned_this_wave` | `bool` | `false` | Whether the boss has already been spawned this wave (prevents double-spawn) |
| `boss_phrase_len` | `usize` | `0` | Precomputed length of the current boss phrase (for health bar ratio) |

## Modified Constants

| Constant | Old Value | New Value | Reason |
|----------|-----------|-----------|--------|
| `MAX_INPUT_CHARS` | `9` | `9` | Unchanged — still the normal zombie limit |
| `MAX_BOSS_INPUT_CHARS` | N/A (new) | `35` | Extended input buffer for boss phrases (FR-009) |
| `BOSS_SCALE` | N/A (new) | `0.4` | Double normal 0.2 scale (FR-005) |
| `BOSS_SPEED_MULTIPLIER` | N/A (new) | `0.5` | Half the wave's fall speed (FR-004) |
| `BOSS_HEALTH_BAR_WIDTH` | N/A (new) | `200` | Health bar width in pixels (FR-007) |
| `BOSS_HEALTH_BAR_HEIGHT` | N/A (new) | `8` | Health bar height in pixels (FR-007) |

The `name` buffer declaration changes from:
```zig
var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1);     // 10 bytes
```
to:
```zig
var name = [_]u8{0} ** (MAX_BOSS_INPUT_CHARS + 1); // 36 bytes
```

## State Transitions

### Boss Lifecycle

```
[No Boss] ---(wave % 5 == 0 AND wave_kills >= ceil(pool_size/2) AND !boss_spawned_this_wave)---> [Boss Active]
[Boss Active] ---(player types full phrase)---> [Boss Dead] ---> [No Boss]
[Boss Active] ---(boss.y >= screen_height)---> [Game Over]
[Boss Active] ---(game restart via Enter)---> [No Boss] (full state reset)
[Boss Active] ---(wave reset)---> [No Boss] (boss freed in resetBoss)
```

### Input Buffer Limit Transitions

```
[Normal: limit = 9] ---(boss spawns)---> [Extended: limit = 35]
[Extended: limit = 35] ---(boss killed OR boss dies OR restart)---> [Normal: limit = 9]
```

### Wave Completion (boss waves only)

```
[Wave In Progress] ---(wave_kills >= pool_size AND wave_spawned >= pool_size AND boss == null)---> [Wave Transition]
```

On non-boss waves (`wave % 5 != 0`), the existing condition applies unchanged (boss is always null).

## Validation Rules

1. **Input character range**: unchanged — `key >= 32 and key <= 125` (covers lowercase letters and spaces needed for boss phrases)
2. **Input length gate**: `letter_count < getCurrentMaxInput()` where the function returns `MAX_BOSS_INPUT_CHARS` if `boss != null`, else `MAX_INPUT_CHARS`
3. **Boss spawn guard**: exactly one boss per boss wave, enforced by `boss_spawned_this_wave` flag
4. **Boss phrase selection**: random index into `BossPhrases[0..10]` using `raylib.GetRandomValue`
5. **Memory safety**: boss pointer freed via `allocator.destroy(boss)` on kill, reset, and restart; nulled immediately after (FR-017)
