# Data Model: Power-ups, Game Modes & Main Menu

**Branch**: `DEATHN-11-power-ups-modes` | **Date**: 2026-05-17

## Entities

### 1. PowerUpType (new enum in `src/zombie_types.zig`)

```zig
pub const PowerUpType = enum {
    freeze,
    bomb,
    shield,
};
```

- Co-located with `ZombieType` in `zombie_types.zig` because both are referenced by `main.zig` and potential future sibling modules. Avoids circular imports per constitution dependency direction rule.

### 2. GameScreen (new enum in `src/main.zig`)

```zig
const GameScreen = enum {
    main_menu,
    wpm_select,
    playing,
    paused,
    game_over,
};
```

- Replaces `is_game_over: bool` for top-level screen routing.
- `is_transitioning` and `is_dying` remain as sub-states of `.playing` (they are brief animations, not user-facing screens).

### 3. GameMode (new enum in `src/zombie_types.zig`)

```zig
pub const GameMode = enum {
    survival,
    zen,
};
```

- Co-located with other shared enums.
- Used by highscore persistence to select storage key/file.
- Used by gameplay logic to gate power-ups, boss encounters, game-over behavior.

### 4. Zombie (modified struct in `src/main.zig`)

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    zombie_type: ZombieType = .standard,
    power_up: ?PowerUpType = null,  // NEW: carried power-up (null = no drop)
};
```

- `power_up` field is `?PowerUpType` (optional). Default `null` means no power-up carried.
- Set at spawn time based on a 10% probability roll (FR-002). Only in survival mode (FR-011).
- Checked on kill to offer pickup to player inventory.

### 5. Power-up state (new module-level globals in `src/main.zig`)

```zig
var held_power_up: ?PowerUpType = null;        // Player's single inventory slot (FR-004)
var freeze_timer: f32 = 0.0;                    // Remaining freeze seconds (FR-009)
var shield_active: bool = false;                 // Whether shield is armed (FR-010)
```

- `held_power_up`: Single-slot inventory. `null` = empty. Set on pickup, cleared on activation.
- `freeze_timer`: Counts down from 3.0s when Freeze is activated. When > 0, zombie/boss movement is suppressed.
- `shield_active`: Set when Shield is activated. Consumed when a zombie crosses the bottom.

### 6. Screen/mode state (new module-level globals in `src/main.zig`)

```zig
var current_screen: GameScreen = .main_menu;     // Starts on menu (FR-012)
var game_mode: GameMode = .survival;             // Selected mode
var menu_selection: u8 = 0;                      // Highlighted menu item index
var pause_selection: u8 = 0;                     // Highlighted pause menu item index
var zen_wpm_selection: u8 = 0;                   // Highlighted WPM tier (0=30, 1=50, 2=80)
```

- `current_screen` replaces `is_game_over` for top-level routing.
- `menu_selection` wraps circularly (FR-014).

### 7. Zen mode config constants

```zig
const ZEN_WPM_TIERS = [_]u32{ 30, 50, 80 };
```

- Compile-time array of preset WPM targets (FR-023).
- Selected tier feeds into `deriveWaveTiming()` to produce spawn_delay and fall_speed.

### 8. highscore.Record (unchanged struct, new dispatch)

The `Record` struct stays identical (17 bytes on disk):

```zig
pub const Record = struct {
    score: u64 = 0,
    wave: u32 = 0,
    wpm: u32 = 0,
    accuracy: u8 = 0,
};
```

For zen mode, `score = 0` and `wave = 0`; only `wpm` and `accuracy` are meaningful.

New persistence API:

```zig
pub fn load(mode: GameMode) Record       // was: pub fn load() Record
pub fn save(mode: GameMode, record: Record) void  // was: pub fn save(record: Record) void
```

- `survival` → file: `highscore.dat`, localStorage key: `death-note.highscore` (backward compatible)
- `zen` → file: `highscore-zen.dat`, localStorage key: `death-note.highscore.zen`

### 9. Best score tracking (modified globals in `src/main.zig`)

```zig
var best_score_survival: highscore.Record = .{};
var best_score_zen: highscore.Record = .{};
var is_new_high_score: bool = false;
```

- Replaces single `best_score` with per-mode records.
- Both loaded at startup.

## State Transitions

### Screen transitions

```
main_menu
  ├── [Enter on "Survival"] → playing (game_mode = .survival)
  ├── [Enter on "Zen"]      → wpm_select
  └── [Enter on "Quit"]     → window close

wpm_select
  ├── [Enter on tier]  → playing (game_mode = .zen)
  └── [Escape]         → main_menu

playing
  ├── [Escape]                → paused
  ├── [zombie reaches bottom, survival] → playing (is_dying sub-state → game_over)
  ├── [zombie reaches bottom, zen]      → playing (zombie silently removed)
  └── [wave completes]        → playing (is_transitioning sub-state)

paused
  ├── [Enter on "Resume"]       → playing
  └── [Enter on "Quit to Menu"] → main_menu

game_over
  ├── [Enter]  → playing (restart survival)
  └── [Escape] → main_menu (FR-021)
```

### Power-up lifecycle

```
spawn:     roll 10% → set zombie.power_up = random PowerUpType
display:   carrier zombie shows pulsing glyph above name
kill:      if held_power_up == null → held_power_up = zombie.power_up
           if held_power_up != null → drop is lost (FR-004 spec scenario 5)
activate:  Space pressed → consume held_power_up, trigger effect
           Freeze: freeze_timer = 3.0, all movement stops
           Bomb: destroy all standard zombies, boss unaffected (FR-008)
           Shield: shield_active = true, passive until zombie crosses bottom
consume:   Freeze: timer expires → normal movement resumes
           Bomb: instant (one frame)
           Shield: zombie crosses bottom → absorb, destroy zombie, clear shield
```

### Freeze timer interaction with pause

When `current_screen == .paused`, `freeze_timer` does NOT decrement (all timers stop). On resume, the remaining freeze time continues counting down.

## Validation Rules

1. `held_power_up` can only be set from `null` → `some` (never overwritten while occupied)
2. `freeze_timer` is only set to 3.0 when activating Freeze; decrements by `GetFrameTime()` per frame; clamped to 0.0
3. `shield_active` can only be true when `held_power_up` was `.shield` at activation time
4. `menu_selection` wraps: `(menu_selection + 1) % MENU_ITEM_COUNT` and `(menu_selection + MENU_ITEM_COUNT - 1) % MENU_ITEM_COUNT`
5. `zen_wpm_selection` wraps within `ZEN_WPM_TIERS.len`
6. Zen mode: no power-up fields are set on spawned zombies; `held_power_up` stays null; HUD inventory slot is not drawn
