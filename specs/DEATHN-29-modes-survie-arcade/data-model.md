# Data Model: Modes Survie, Arcade et Simulation avec système de vies

**Branch**: `DEATHN-29-modes-survie-arcade` | **Date**: 2026-05-19

## Entity Changes

### 1. GameMode (modified — `src/zombie_types.zig`)

**Current**:
```zig
pub const GameMode = enum {
    survival,
    zen,
};
```

**New**:
```zig
pub const GameMode = enum {
    survival,  // Survie: hardcore, no powers, 1 life
    arcade,    // Arcade: 3 hearts, powers enabled
    simulation,// Simulation: auto-play (renamed Bot), no score save
    zen,       // Zen: relaxed, no game over
};
```

**Impact**: Every `switch (mode)` on `GameMode` in `main.zig` and `highscore.zig` will fail to compile until the new arms are handled. This is the primary safety mechanism for completeness.

### 2. Hearts State (new — `src/main.zig` module-level vars)

```zig
const MAX_HEARTS: u8 = 3;
const HEART_LOSS_FLASH_DURATION: f32 = 0.2;
const HEART_RESTORE_FLASH_DURATION: f32 = 0.3;

var hearts: u8 = 0;           // Current heart count (0 in non-Arcade modes)
var heart_flash_timer: f32 = 0.0; // Visual feedback timer for heart gain/loss
var heart_flash_is_loss: bool = false; // true = loss flash (red), false = gain flash (green/accent)
```

**Validation Rules**:
- `hearts` is only non-zero in Arcade mode.
- `hearts` is clamped to `[0, MAX_HEARTS]` — never incremented above 3, never decremented below 0.
- Heart loss occurs per-zombie (each zombie reaching bottom costs exactly 1 heart).
- Heart gain occurs only on boss defeat (exactly 1 heart, capped at MAX_HEARTS).

**State Transitions**:
```
[Arcade Start] → hearts = MAX_HEARTS (3)
[Zombie reaches bottom] → hearts -= 1 → if (hearts == 0) → is_dying = true
[Boss defeated] → hearts = min(hearts + 1, MAX_HEARTS)
[Game restart / mode change] → hearts = 0 (or MAX_HEARTS if Arcade)
```

### 3. High Score Records (extended — `src/main.zig`)

**Current**:
```zig
var best_score_survival: highscore.Record = .{};
var best_score_zen: highscore.Record = .{};
```

**New**:
```zig
var best_score_survival: highscore.Record = .{};
var best_score_arcade: highscore.Record = .{};
var best_score_zen: highscore.Record = .{};
```

Simulation mode has no stored record (score save is prevented by both `bot_tainted` and explicit mode guard).

### 4. High Score File Mapping (extended — `src/highscore.zig`)

| GameMode | Native File | Web localStorage Key |
|----------|-------------|---------------------|
| `.survival` | `highscore.dat` | `death-note.highscore` |
| `.arcade` | `highscore-arcade.dat` | `death-note.highscore.arcade` |
| `.simulation` | — (never saved) | — (never saved) |
| `.zen` | `highscore-zen.dat` | `death-note.highscore.zen` |

**Note**: Existing `highscore.dat` (survival) and `highscore-zen.dat` (zen) filenames are preserved, maintaining backward compatibility for existing players per ARD-5.

### 5. Menu Configuration (modified — `src/main.zig`)

**Current**:
```zig
const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "BOT", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 5;
```

**New**:
```zig
const MENU_ITEMS = [_][]const u8{ "SURVIE", "ARCADE", "SIMULATION", "ZEN", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 6;
```

**Menu index mapping**:
| Index | Label | Action |
|-------|-------|--------|
| 0 | SURVIE | `startGame(.survival, allocator)` |
| 1 | ARCADE | `startGame(.arcade, allocator)` |
| 2 | SIMULATION | `startGame(.simulation, allocator)` + bot overlay |
| 3 | ZEN | transition to `.wpm_select` screen |
| 4 | SOUND | sound settings |
| 5 | QUIT | quit |

### 6. Zombie Struct (unchanged)

The `Zombie` struct is not modified. The `power_up: ?PowerUpType` field continues to work — it is populated only in Arcade mode (was Survival mode) based on the mode-conditional drop check.

### 7. WaveConfig (unchanged)

Wave configuration is shared between Survie and Arcade per FR-006. No structural changes needed — the existing `getWaveConfig(wave)` formula applies identically to both modes.

## Behavioral Matrix

| Behavior | Survie | Arcade | Simulation | Zen |
|----------|--------|--------|------------|-----|
| Wave progression | Yes | Yes (same config) | Yes (same config) | No (continuous) |
| Starter pack | Yes | Yes | Yes | No |
| Power-up drops | **No** | **Yes** | Yes (current bot) | No |
| Hearts display | No | **Yes (3)** | No | No |
| Zombie reaches bottom | Game over | **Heart loss** | Game over (bot) | Despawn |
| Boss heart restore | N/A | **Yes (+1 heart)** | N/A (bot) | N/A |
| Shield absorption | Yes | Yes | Yes | No |
| High score saved | Yes | **Yes (separate)** | **No** | Yes |
| Bot auto-typing | No | No | **Yes** | No |
| F2 toggle | Available | Available | Available | Available |
